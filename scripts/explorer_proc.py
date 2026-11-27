"""How the explorer, scripts/explorer.py, starts the processes of a run
(docs/decisions/conformance.md#the-explorer).

Every process runs with no shell and no input, in a session of its own,
under resource limits, and holds a slot of one bounded gate while it runs,
so that the explorer never has more than a few running at once. Its output is
read with no thread, up to a cap. When it ends, times out or prints too much,
explorer_reap.py kills whatever of it is left. The rlimits are set by a
short Python launcher that then executes the command, not by `preexec_fn`,
which is unsafe in a threaded server; the launcher reports its own failure
on a pipe of its own, closed when the command starts, so that no output of
the command can pass for it.
"""

from __future__ import annotations

import json
import os
import secrets
import selectors
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path

from explorer_reap import LOCK, MARKER, TRACKED, contain, reap_orphans

PROC = Path("/proc")

# Sets each limit, never above its hard limit, then runs the command. The
# pipe `sys.argv[1]` closes when the command starts; a command that cannot
# start is reported on it instead.
TRAMPOLINE = """\
import json, os, resource, sys
report = int(sys.argv[1])
os.set_inheritable(report, False)
for name, value in json.loads(sys.argv[2]).items():
    which = getattr(resource, name)
    hard = resource.getrlimit(which)[1]
    if hard != resource.RLIM_INFINITY:
        value = min(value, hard)
    resource.setrlimit(which, (value, value))
try:
    os.execvp(sys.argv[3], sys.argv[3:])
except OSError as e:
    os.write(report, ("%s: %s" % (sys.argv[3], e)).encode())
    os._exit(127)
"""


@dataclass
class Proc:
    """How a process that the explorer started ended."""

    code: int | None
    stdout: str
    stderr: str
    seconds: float
    timed_out: bool = False
    overflowed: bool = False


class Gate:
    """The bounded gate that every child process passes through: at most
    `size` run at once, and at most `queue` more wait for a slot."""

    def __init__(self, size: int, queue: int) -> None:
        self.slots = threading.BoundedSemaphore(max(1, size))
        self.places = threading.BoundedSemaphore(max(1, size) + max(0, queue))

    def __enter__(self):
        if not self.places.acquire(blocking=False):
            raise Busy("the explorer is busy; try again when a run ends")
        self.slots.acquire()
        return self

    def __exit__(self, *exc):
        self.slots.release()
        self.places.release()


class Busy(Exception):
    pass


GATE = Gate(4, 8)


def configure(size: int, queue: int) -> None:
    global GATE
    GATE = Gate(size, queue)


def user_tasks() -> int:
    """How many tasks the user runs, which RLIMIT_NPROC counts."""
    total, uid = 0, os.getuid()
    if not PROC.is_dir():
        return 0
    for entry in PROC.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            fields = dict(
                line.split(":", 1)
                for line in (entry / "status").read_text().splitlines()
            )
            if int(fields["Uid"].split()[0]) == uid:
                total += int(fields["Threads"])
        except (OSError, KeyError, ValueError):
            continue
    return total


def rlimits(timeout: float, memory: int, fsize: int, tasks: int) -> dict[str, int]:
    """The limits of a child: CPU time for its timeout on several cores,
    address space, file size, no core file, and at most `tasks` more tasks
    than the user runs now."""
    limits = {
        "RLIMIT_CPU": int(timeout * 8) + 10,
        "RLIMIT_AS": memory,
        "RLIMIT_FSIZE": fsize,
        "RLIMIT_CORE": 0,
    }
    if (count := user_tasks()) > 0:
        limits["RLIMIT_NPROC"] = count + tasks
    return limits


def _exited(pid: int) -> bool:
    """Whether the child has exited, leaving it unreaped, so that its PID,
    which is also its process group's id, cannot be reused yet."""
    info = os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
    return info is not None


def _pump(sel, buffers, cap: int, wait: float) -> bool:
    """Reads what is ready; whether a stream went past the cap."""
    over = False
    for key, _ in sel.select(wait):
        data = os.read(key.fd, 65536)
        sink = buffers[key.fd]
        if not data:
            sel.unregister(key.fileobj)
            continue
        room = cap - len(sink)
        sink.extend(data[: max(room, 0)])
        over = over or len(data) > room
    return over


def _text(data: bytearray) -> str:
    return bytes(data).decode("utf-8", "replace").replace("\r\n", "\n")


def run_capped(
    argv: list[str], cwd: Path, timeout: float, cap: int, limits: dict[str, int]
) -> Proc:
    """Runs `argv` in `cwd` under `limits`, for at most `timeout` seconds and
    `cap` bytes on each stream, then contains it. OSError when it cannot
    start; Busy when the gate's queue is full."""
    marker = secrets.token_hex(12)
    env = {**os.environ, MARKER: marker}
    with GATE:
        report, report_w = os.pipe()
        command = [sys.executable, "-I", "-c", TRAMPOLINE, str(report_w)]
        command += [json.dumps(limits), *argv]
        start = time.monotonic()
        try:
            with LOCK:
                proc = subprocess.Popen(
                    command,
                    cwd=cwd,
                    env=env,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    start_new_session=True,
                    pass_fds=(report_w,),
                )
                TRACKED.add(proc.pid)
        except BaseException:
            os.close(report)
            raise
        finally:
            os.close(report_w)
        out, err = bytearray(), bytearray()
        sel = selectors.DefaultSelector()
        sel.register(proc.stdout, selectors.EVENT_READ)
        sel.register(proc.stderr, selectors.EVENT_READ)
        buffers = {proc.stdout.fileno(): out, proc.stderr.fileno(): err}
        timed_out = over = False
        try:
            while not _exited(proc.pid):
                if time.monotonic() - start > timeout:
                    timed_out = True
                    break
                if _pump(sel, buffers, cap, 0.02):
                    over = True
                    break
        finally:
            contain(proc.pid, marker)
            proc.wait()
            with LOCK:
                TRACKED.discard(proc.pid)
            end = time.monotonic() + 1
            while not over and sel.get_map() and time.monotonic() < end:
                over = _pump(sel, buffers, cap, 0.02)
            sel.close()
            proc.stdout.close()
            proc.stderr.close()
            failure = _read_all(report)
            reap_orphans()
        seconds = time.monotonic() - start
    if failure:
        raise OSError(failure.decode("utf-8", "replace"))
    code = None if timed_out or over else proc.returncode
    return Proc(code, _text(out), _text(err), seconds, timed_out, over)


def _read_all(fd: int) -> bytes:
    """What the launcher wrote on its pipe, whose writers are all gone."""
    data = b""
    try:
        while chunk := os.read(fd, 4096):
            data += chunk
    finally:
        os.close(fd)
    return data
