"""Tests for scripts/sweep.py. Run: python scripts/test_sweep.py"""

import io
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from conformance_compiler import Result
from sweep import kind, main, parse_args

RUN_1 = Result("finished", ("1",))
RUN_2 = Result("finished", ("2",))
TYPE = Result("rejected", (), "typeMismatch")
FLOW = Result("rejected", (), "uninitializedUse")


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


class Arguments(unittest.TestCase):
    def test_both_builds_are_needed(self):
        with tempfile.NamedTemporaryFile() as f, self.assertRaises(ValueError):
            parse_args(["--base", f.name])

    def test_a_missing_executable_is_refused(self):
        with self.assertRaises(ValueError):
            parse_args(["--base", "/nonexistent/a", "--head", "/nonexistent/b"])

    def test_jobs_and_programs(self):
        with tempfile.TemporaryDirectory() as d:
            exe, prog = Path(d) / "m", Path(d) / "p.mojo"
            exe.write_text("")
            prog.write_text("")
            base, head, jobs, chosen = parse_args(
                ["--base", str(exe), "--head", str(exe), "--jobs", "3", str(prog)]
            )
            self.assertEqual(
                (base, head, jobs, chosen), (exe, exe, 3, [prog.resolve()])
            )

    def test_main_reports_a_bad_argument(self):
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(main(["--nope"]), 2)
        self.assertIn("neither a program nor an option", err.getvalue())


if __name__ == "__main__":
    unittest.main()
