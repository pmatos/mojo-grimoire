"""Tests for scripts/sweep.py. Run: python scripts/test_sweep.py"""

import io
import os
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock

import sweep
from conformance_compiler import Result
from sweep import kind, main, parse_args, run

RUN_1 = Result("finished", ("1",))
RUN_2 = Result("finished", ("2",))
TYPE = Result("rejected", (), "typeMismatch")
FLOW = Result("rejected", (), "uninitializedUse")
NO_CLASS = Result("rejected", (), None)
BROKEN = Result("error", (), None, "timed out")


class Kind(unittest.TestCase):
    def test_agree_on_both(self):
        self.assertEqual(kind(TYPE, TYPE, TYPE), "agree")

    def test_fixed(self):
        self.assertEqual(kind(TYPE, FLOW, TYPE), "fixed")

    def test_disagree_on_both_even_when_the_result_changes(self):
        self.assertEqual(kind(RUN_1, TYPE, FLOW), "disagree")

    def test_a_change_of_rejection_class(self):
        self.assertEqual(kind(TYPE, TYPE, FLOW), "class changed")

    def test_a_run_that_becomes_a_rejection_regresses(self):
        self.assertEqual(kind(RUN_1, RUN_1, TYPE), "regressed")

    def test_a_rejection_that_becomes_a_run_regresses(self):
        self.assertEqual(kind(TYPE, TYPE, RUN_1), "regressed")

    def test_other_printed_lines_regress(self):
        self.assertEqual(kind(RUN_1, RUN_1, RUN_2), "regressed")

    def test_a_run_that_breaks_regresses(self):
        self.assertEqual(kind(TYPE, TYPE, BROKEN), "regressed")

    def test_a_rejection_with_no_class_agrees_with_any_rejection(self):
        self.assertEqual(kind(NO_CLASS, TYPE, FLOW), "agree")

    def test_a_rejection_with_no_class_that_becomes_a_run_regresses(self):
        self.assertEqual(kind(NO_CLASS, TYPE, RUN_1), "regressed")


class Run(unittest.TestCase):
    def test_a_run_that_cannot_start_is_an_error(self):
        with mock.patch.object(sweep, "run_model", side_effect=OSError("gone")):
            self.assertEqual(run(Path("p.mojo"), Path("m")).outcome, "error")


class Arguments(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.exe = Path(self.dir.name) / "m"
        self.exe.write_text("")
        self.exe.chmod(0o755)

    def test_both_builds_are_needed(self):
        with self.assertRaises(ValueError):
            parse_args(["--base", str(self.exe)])

    def test_a_missing_executable_is_refused(self):
        with self.assertRaises(ValueError):
            parse_args(["--base", "/nonexistent/a", "--head", "/nonexistent/b"])

    def test_a_file_that_cannot_run_is_refused(self):
        self.exe.chmod(0o644)
        with self.assertRaises(ValueError):
            parse_args(["--base", str(self.exe), "--head", str(self.exe)])

    def test_a_relative_executable_is_made_absolute(self):
        cwd = os.getcwd()
        os.chdir(self.dir.name)
        self.addCleanup(os.chdir, cwd)
        base, head, _, _ = parse_args(["--base", "m", "--head", "m"])
        self.assertEqual((base, head), (self.exe.resolve(), self.exe.resolve()))

    def test_jobs_and_programs(self):
        prog = Path(self.dir.name) / "p.mojo"
        prog.write_text("")
        e = str(self.exe)
        found = parse_args(["--base", e, "--head", e, "--jobs", "3", str(prog)])
        self.assertEqual(found, (self.exe, self.exe, 3, [prog.resolve()]))

    def test_main_reports_a_bad_argument(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(main(["--nope"]), 2)
        self.assertIn("both --base MODEL and --head MODEL", err.getvalue())

    def test_a_sweep_that_compares_nothing_fails(self):
        prog = Path(self.dir.name) / "p.mojo"
        prog.write_text("")
        e = str(self.exe)
        with redirect_stderr(io.StringIO()):
            self.assertEqual(main(["--base", e, "--head", e, str(prog)]), 2)


if __name__ == "__main__":
    unittest.main()
