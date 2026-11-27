"""How the explorer, scripts/explorer.py, starts and stops the processes of a
run (docs/decisions/conformance.md#the-explorer).

Every process runs with no shell and no input, in a session of its own,
under resource limits, and holds a slot of one bounded gate while it runs,
so that the explorer never has more than a few running at once. Its output is
read with no thread, up to a cap. When it ends, times out or prints too much,
the explorer kills its process group, every descendant it can still find
through the process tree, and every process that carries the run's marker in
its environment, which a descendant inherits even when it leaves the group
with setsid. A descendant that leaves the process tree and clears its
environment escapes; its resource limits, the CPU time included, still hold.
The rlimits are set by a short Python trampoline that then executes the
command, not by `preexec_fn`, which is unsafe in a threaded server.
"""

from __future__ import annotations

import json
import os
import secrets
import selectors
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path

MARKER = "MOJO_EXPLORER_RUN"
CANNOT_RUN = "explorer: cannot run: "
PROC = Path("/proc")

# Sets each limit, never above its hard limit, then runs the command; a
# command that cannot start is reported on standard error with exit 127.
TRAMPOLINE = """\
import json, os, resource, sys
for name, value in json.loads(sys.argv[1]).items():
    which = getattr(resource, name)
    hard = resource.getrlimit(which)[1]
    if hard != resource.RLIM_INFINITY:
        value = min(value, hard)
    resource.setrlimit(which, (value, value))
try:
    os.execvp(sys.argv[2], sys.argv[2:])
except OSError as e:
    sys.stderr.write("explorer: cannot run: %s: %s\\n" % (sys.argv[2], e))
    sys.exit(127)
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


def _parents() -> dict[int, int]:
    found = {}
    if not PROC.is_dir():
        return found
    for entry in PROC.iterdir():
        if entry.name.isdigit():
            try:
                stat = (entry / "stat").read_text()
                found[int(entry.name)] = int(stat.rsplit(")", 1)[1].split()[1])
            except (OSError, ValueError, IndexError):
                continue
    return found


def descendants(pid: int) -> set[int]:
    """The processes whose parents lead to `pid`."""
    children: dict[int, list[int]] = {}
    for child, parent in _parents().items():
        children.setdefault(parent, []).append(child)
    found, todo = set(), [pid]
    while todo:
        for child in children.get(todo.pop(), []):
            if child not in found:
                found.add(child)
                todo.append(child)
    return found


def marked(marker: str) -> set[int]:
    """The user's processes whose environment carries the run's marker."""
    needle = f"{MARKER}={marker}".encode()
    found, uid = set(), os.getuid()
    if not PROC.is_dir():
        return found
    for entry in PROC.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if (
                entry.stat().st_uid == uid
                and needle in (entry / "environ").read_bytes()
            ):
                found.add(int(entry.name))
        except OSError:
            continue
    return found


def _kill(pids) -> None:
    for pid in pids:
        try:
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass


def contain(pid: int, marker: str) -> None:
    """Kills the child's process group, its descendants, and every process
    that carries its marker, until none is left. The child itself stays
    unreaped until the caller waits for it."""
    tree = descendants(pid)
    try:
        os.killpg(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
    _kill(tree)
    for _ in range(20):
        left = marked(marker) - {pid}
        if not left:
            return
        _kill(left)
        time.sleep(0.01)


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
    command = [sys.executable, "-I", "-c", TRAMPOLINE, json.dumps(limits), *argv]
    with GATE:
        start = time.monotonic()
        proc = subprocess.Popen(
            command,
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
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
            end = time.monotonic() + 1
            while not over and sel.get_map() and time.monotonic() < end:
                over = _pump(sel, buffers, cap, 0.02)
            sel.close()
            proc.stdout.close()
            proc.stderr.close()
        seconds = time.monotonic() - start
    stderr = _text(err)
    if proc.returncode == 127 and stderr.startswith(CANNOT_RUN):
        raise OSError(stderr[len(CANNOT_RUN) :].strip())
    code = None if timed_out or over else proc.returncode
    return Proc(code, _text(out), stderr, seconds, timed_out, over)
