"""Tests for the explorer's processes, scripts/explorer_proc.py: timeouts,
the output cap, containment, the gate and the resource limits.
Run: python -m unittest discover -s scripts -p 'test_explorer*.py'"""

import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

import explorer_proc as proc
import explorer_reap as reap
import explorer_run as run
from conformance import load_patterns
from test_explorer import script

PATTERNS = load_patterns()
NONE: dict[str, int] = {}


def reaped(pid: int, within: float = 3.0) -> bool:
    """Whether `pid` is gone, its zombie reaped too."""
    end = time.monotonic() + within
    while time.monotonic() < end:
        if not Path(f"/proc/{pid}").exists():
            return True
        time.sleep(0.05)
    return False


class Processes(unittest.TestCase):
    def test_timeout_kills_the_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            start = time.monotonic()
            argv = ["sh", "-c", "sleep 30 & sleep 30"]
            p = proc.run_capped(argv, Path(tmp), 0.5, 1000, NONE)
            self.assertTrue(p.timed_out)
            self.assertIsNone(p.code)
            self.assertLess(time.monotonic() - start, 10)

    def test_output_cap(self):
        with tempfile.TemporaryDirectory() as tmp:
            argv = [sys.executable, "-c", "while True: print('x' * 100)"]
            p = proc.run_capped(argv, Path(tmp), 20, 5000, NONE)
            self.assertTrue(p.overflowed)
            self.assertLessEqual(len(p.stdout), 5000)

    def test_runs_in_its_directory_and_ends_with_its_children(self):
        with tempfile.TemporaryDirectory() as tmp:
            start = time.monotonic()
            argv = ["sh", "-c", "sleep 30 & pwd"]
            p = proc.run_capped(argv, Path(tmp), 20, 1000, NONE)
            self.assertEqual(p.code, 0)
            self.assertEqual(Path(p.stdout.strip()).resolve(), Path(tmp).resolve())
            self.assertLess(time.monotonic() - start, 10)

    def test_a_timed_out_build_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            slow = script(Path(tmp), "slow", "#!/bin/sh\nsleep 30\n")
            limits = run.Limits(build=0.5, run=1, model=1, output=100)
            report = run.run_on_compiler("x", str(slow), PATTERNS, (), limits)
            self.assertEqual(report["_result"].outcome, "error")
            self.assertIn("timed out", report["_result"].detail)

    def test_a_missing_command_cannot_run(self):
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(OSError):
            proc.run_capped([str(Path(tmp) / "nope")], Path(tmp), 5, 100, NONE)

    def test_a_program_cannot_pass_for_the_launcher(self):
        fake = (
            "import sys; sys.stderr.write('explorer: cannot run: x\\n'); sys.exit(127)"
        )
        with tempfile.TemporaryDirectory() as tmp:
            p = proc.run_capped([sys.executable, "-c", fake], Path(tmp), 10, 100, NONE)
        self.assertEqual(p.code, 127)
        self.assertIn("cannot run", p.stderr)


# A double fork out of the run's session; the grandchild then hides from
# the marker by HOW: "keep" keeps its environment, "clear" execs with an
# empty one, "undumpable" makes its /proc files root's.
ESCAPE = """\
import ctypes, os, sys, time
pid_file, how, parent_sleep = sys.argv[1], sys.argv[2], float(sys.argv[3])
hold = "import os, sys, time; open(sys.argv[1], 'w').write(str(os.getpid())); time.sleep(300)"
if os.fork() == 0:
    os.setsid()
    if os.fork() == 0:
        if how == "clear":
            os.execve(sys.executable, [sys.executable, "-c", hold, pid_file], {})
        if how == "undumpable":
            ctypes.CDLL(None).prctl(4, 0, 0, 0, 0)
        open(pid_file, "w").write(str(os.getpid()))
        time.sleep(300)
    os._exit(0)
time.sleep(parent_sleep)
"""


def setUpModule():
    if Path("/proc").is_dir() and not reap.become_subreaper():
        raise unittest.SkipTest("this system has no child subreaper")


@unittest.skipUnless(Path("/proc").is_dir(), "containment reads /proc")
class Containment(unittest.TestCase):
    """A descendant that leaves the run's session with a double fork is
    killed and reaped, however it hides, and no reader is left behind."""

    def escape(self, how: str, parent_sleep: float, timeout: float):
        with tempfile.TemporaryDirectory() as tmp:
            pid_file = Path(tmp) / "pid"
            argv = [sys.executable, "-c", ESCAPE, str(pid_file), how, str(parent_sleep)]
            threads = threading.active_count()
            start = time.monotonic()
            p = proc.run_capped(argv, Path(tmp), timeout, 1000, NONE)
            elapsed = time.monotonic() - start
            for _ in range(150):
                if pid_file.exists() and pid_file.read_text():
                    break
                time.sleep(0.02)
            pid = int(pid_file.read_text())
            self.assertTrue(reaped(pid), f"the escaped process {pid} survived ({how})")
            self.assertEqual(threading.active_count(), threads)
            self.assertLess(elapsed, 5)
            return p

    def test_after_a_timeout(self):
        for how in ("keep", "clear", "undumpable"):
            with self.subTest(how=how):
                self.assertTrue(
                    self.escape(how, parent_sleep=30, timeout=1.5).timed_out
                )

    def test_after_the_run_exits(self):
        for how in ("keep", "clear", "undumpable"):
            with self.subTest(how=how):
                self.assertEqual(self.escape(how, parent_sleep=0.8, timeout=20).code, 0)

    def test_an_orphan_is_reaped_without_a_run(self):
        hold = "import time; time.sleep(300)"
        code = (
            "import os, subprocess, sys\n"
            f"p = subprocess.Popen([sys.executable, '-c', {hold!r}], env={{}},\n"
            "    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,\n"
            "    stderr=subprocess.DEVNULL, start_new_session=True)\n"
            "print(p.pid)\n"
        )
        out = subprocess.run(
            [sys.executable, "-c", code],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        pid = int(out.stdout)
        for _ in range(100):
            if reap._parent_of(pid) == os.getpid():
                break
            time.sleep(0.02)
        self.assertEqual(reap._parent_of(pid), os.getpid(), "not reparented here")
        self.assertGreaterEqual(reap.reap_orphans(), 1)
        self.assertTrue(reaped(pid))

    def test_the_marker_finds_only_its_run(self):
        self.assertEqual(reap.marked("no-such-marker"), [])


class ContainmentWithoutPidfd(Containment):
    """The same, on a Python built without os.pidfd_open, as some standalone
    builds are: the kills fall back to the PID, checked again."""

    def setUp(self):
        self.had = reap.HAS_PIDFD
        reap.HAS_PIDFD = False

    def tearDown(self):
        reap.HAS_PIDFD = self.had


class TheGate(unittest.TestCase):
    def tearDown(self):
        proc.configure(4, 8)

    def test_at_most_size_run_at_once(self):
        proc.configure(2, 8)
        with tempfile.TemporaryDirectory() as tmp:
            argv = ["sleep", "0.6"]
            start = time.monotonic()
            workers = [
                threading.Thread(
                    target=proc.run_capped, args=(argv, Path(tmp), 10, 100, NONE)
                )
                for _ in range(4)
            ]
            for w in workers:
                w.start()
            for w in workers:
                w.join()
            self.assertGreaterEqual(time.monotonic() - start, 1.1)

    def test_beyond_the_queue_is_busy(self):
        proc.configure(1, 0)
        with proc.GATE, self.assertRaises(proc.Busy):
            proc.run_capped(["true"], Path("."), 5, 100, NONE)


@unittest.skipUnless(Path("/proc").is_dir(), "the task count reads /proc")
class ResourceLimits(unittest.TestCase):
    def test_the_child_runs_under_them(self):
        limits = proc.rlimits(10, 1 << 30, 1 << 20, 64)
        show = (
            "import json, resource; print(json.dumps({n: resource.getrlimit("
            "getattr(resource, n))[0] for n in ['RLIMIT_CPU', 'RLIMIT_AS', "
            "'RLIMIT_FSIZE', 'RLIMIT_CORE', 'RLIMIT_NPROC']}))"
        )
        with tempfile.TemporaryDirectory() as tmp:
            p = proc.run_capped(
                [sys.executable, "-c", show], Path(tmp), 10, 1000, limits
            )
        seen = json.loads(p.stdout)
        self.assertEqual(seen["RLIMIT_CPU"], 90)
        self.assertEqual(seen["RLIMIT_AS"], 1 << 30)
        self.assertEqual(seen["RLIMIT_FSIZE"], 1 << 20)
        self.assertEqual(seen["RLIMIT_CORE"], 0)
        self.assertLess(seen["RLIMIT_NPROC"], proc.user_tasks() + 200)

    def test_a_file_past_the_limit_cannot_be_written(self):
        limits = proc.rlimits(10, 1 << 30, 1000, 64)
        write = (
            "f = open('big', 'wb', buffering=0)\nwhile True:\n    f.write(b'x' * 500)\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            p = proc.run_capped(
                [sys.executable, "-c", write], Path(tmp), 10, 1000, limits
            )
            self.assertNotEqual(p.code, 0)
            self.assertIn("File too large", p.stderr)
            self.assertLessEqual(os.path.getsize(Path(tmp) / "big"), 1000)


if __name__ == "__main__":
    unittest.main()
