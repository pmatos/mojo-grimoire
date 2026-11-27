"""How the explorer, scripts/explorer.py, makes sure that no process of a run
outlives it (docs/decisions/conformance.md#the-explorer).

The server is a child subreaper (`PR_SET_CHILD_SUBREAPER`): a process of a
run whose parent exits is reparented to the server, not to init, whatever it
does to its environment, its session or its dumpable flag. After each run,
and every few seconds, the server kills and reaps each of its children that
is not a live run it started. When a run ends, its process group, its
descendants and every process that carries its marker are killed as well.
Every kill but the group's goes through a pidfd taken while the process was
checked, so a PID that was recycled in between is never hit; the group's
id is the run's own PID, which stays unreaped until the run is waited for.
"""

from __future__ import annotations

import ctypes
import os
import signal
import threading
import time
from pathlib import Path

PROC = Path("/proc")
PR_SET_CHILD_SUBREAPER = 36
MARKER = "MOJO_EXPLORER_RUN"

# The PIDs of the runs that are alive, which the reaper leaves alone. A run
# is added under the lock while it is started, so the reaper never sees it
# unlisted.
TRACKED: set[int] = set()
LOCK = threading.Lock()


def become_subreaper() -> bool:
    """Makes this process the subreaper of its descendants; False where the
    system has no such call."""
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        return libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) == 0
    except (OSError, AttributeError):
        return False


def _parent_of(pid: int) -> int | None:
    try:
        stat = (PROC / str(pid) / "stat").read_text()
        return int(stat.rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        return None


def _pids() -> list[int]:
    if not PROC.is_dir():
        return []
    return [int(e.name) for e in PROC.iterdir() if e.name.isdigit()]


def _open(pid: int, still) -> int | None:
    """A pidfd for `pid`, once `still(pid)` holds with the pidfd open, which
    keeps the PID from being reused; None otherwise."""
    try:
        fd = os.pidfd_open(pid)
    except OSError:
        return None
    if still(pid):
        return fd
    os.close(fd)
    return None


def _kill_fds(fds) -> None:
    for fd in fds:
        try:
            signal.pidfd_send_signal(fd, signal.SIGKILL)
        except OSError:
            pass
        finally:
            os.close(fd)


def descendants(pid: int) -> list[int]:
    """pidfds of the processes whose parents lead to `pid`, each checked to
    still have the parent it was found with."""
    parents = {p: _parent_of(p) for p in _pids()}
    children: dict[int, list[int]] = {}
    for child, parent in parents.items():
        if parent is not None:
            children.setdefault(parent, []).append(child)
    fds, todo, seen = [], [pid], set()
    while todo:
        parent = todo.pop()
        for child in children.get(parent, []):
            if child in seen:
                continue
            seen.add(child)
            todo.append(child)
            fd = _open(child, lambda p, parent=parent: _parent_of(p) == parent)
            if fd is not None:
                fds.append(fd)
    return fds


def _carries(pid: int, needle: bytes) -> bool:
    try:
        entry = PROC / str(pid)
        return (
            entry.stat().st_uid == os.getuid()
            and needle in (entry / "environ").read_bytes()
        )
    except OSError:
        return False


def marked(marker: str, but: int | None = None) -> list[int]:
    """pidfds of the user's processes whose environment carries the run's
    marker, `but` aside."""
    needle = f"{MARKER}={marker}".encode()
    fds = []
    for pid in _pids():
        if pid != but and _carries(pid, needle):
            fd = _open(pid, lambda p: _carries(p, needle))
            if fd is not None:
                fds.append(fd)
    return fds


def contain(pid: int, marker: str) -> None:
    """Kills the run's process group, its descendants, and every process
    that carries its marker, until none is left. The run itself stays
    unreaped until the caller waits for it."""
    tree = descendants(pid)
    try:
        os.killpg(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
    _kill_fds(tree)
    for _ in range(20):
        left = marked(marker, but=pid)
        if not left:
            return
        _kill_fds(left)
        time.sleep(0.01)


def reap_orphans() -> int:
    """Kills and reaps every child of this process that is not a tracked
    run: the processes of runs that were reparented here. How many."""
    me, count = os.getpid(), 0
    with LOCK:
        for pid in _pids():
            if pid in TRACKED or _parent_of(pid) != me:
                continue
            fd = _open(pid, lambda p: _parent_of(p) == me and p not in TRACKED)
            if fd is None:
                continue
            try:
                try:
                    signal.pidfd_send_signal(fd, signal.SIGKILL)
                except OSError:
                    pass
                try:
                    os.waitid(os.P_PIDFD, fd, os.WEXITED)
                    count += 1
                except ChildProcessError:
                    pass
            finally:
                os.close(fd)
    return count


def start_reaper(every: float = 5.0) -> threading.Thread:
    """A thread that reaps orphans every `every` seconds."""

    def loop() -> None:
        while True:
            time.sleep(every)
            reap_orphans()

    thread = threading.Thread(target=loop, name="explorer-reaper", daemon=True)
    thread.start()
    return thread
