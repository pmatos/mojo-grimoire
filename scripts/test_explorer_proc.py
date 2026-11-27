"""Tests for the explorer's processes, scripts/explorer_proc.py: timeouts,
the output cap, containment, the gate and the resource limits.
Run: python -m unittest discover -s scripts -p 'test_explorer*.py'"""

import json
import os
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

import explorer_proc as proc
import explorer_run as run
from conformance import load_patterns
from test_explorer import script

PATTERNS = load_patterns()
NONE: dict[str, int] = {}


def alive(pid: int) -> bool:
    """Whether `pid` runs, a zombie not counted."""
    try:
        state = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0]
    except OSError:
        return False
    return state != "Z"


def gone(pid: int, within: float = 3.0) -> bool:
    end = time.monotonic() + within
    while time.monotonic() < end:
        if not alive(pid):
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


ESCAPE = """\
import os, sys, time
if os.fork() == 0:
    os.setsid()
    if os.fork() == 0:
        open(sys.argv[1], "w").write(str(os.getpid()))
        sys.stdout.write("escaped\\n")
        sys.stdout.flush()
        time.sleep(300)
    os._exit(0)
time.sleep(float(sys.argv[2]))
"""


@unittest.skipUnless(Path("/proc").is_dir(), "containment reads /proc")
class Containment(unittest.TestCase):
    """A descendant that leaves the process group with setsid, and whose
    parent exits, is still killed, and no reader is left behind."""

    def escape(self, parent_sleep: float, timeout: float):
        with tempfile.TemporaryDirectory() as tmp:
            pid_file = Path(tmp) / "pid"
            argv = [sys.executable, "-c", ESCAPE, str(pid_file), str(parent_sleep)]
            threads = threading.active_count()
            start = time.monotonic()
            p = proc.run_capped(argv, Path(tmp), timeout, 1000, NONE)
            elapsed = time.monotonic() - start
            for _ in range(100):
                if pid_file.exists() and pid_file.read_text():
                    break
                time.sleep(0.02)
            pid = int(pid_file.read_text())
            self.assertTrue(gone(pid), f"the escaped process {pid} still runs")
            self.assertEqual(threading.active_count(), threads)
            self.assertLess(elapsed, 5)
            return p

    def test_after_a_timeout(self):
        self.assertTrue(self.escape(parent_sleep=30, timeout=1).timed_out)

    def test_after_the_child_exits(self):
        p = self.escape(parent_sleep=0.5, timeout=20)
        self.assertEqual(p.code, 0)

    def test_the_marker_finds_only_its_run(self):
        self.assertEqual(proc.marked("no-such-marker"), set())


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
