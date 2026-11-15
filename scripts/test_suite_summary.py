"""Tests for scripts/suite_summary.py. Run: python scripts/test_suite_summary.py"""

import io
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from suite_summary import lean_counts, main, strip_lean


class Summary(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.summary = self.tmp / "summary.md"
        self.enterContext(
            mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(self.summary)})
        )

    def run_main(self, *args: str) -> tuple[int, str]:
        out = io.StringIO()
        with redirect_stdout(out):
            status = main(list(args))
        return status, out.getvalue()

    def test_strip_lean_blanks_comments_and_literals(self):
        src = (
            "/- outer /- inner -/\n#guard 1 -/\n"
            '#guard s = "a /- b"\n'
            "def q := '\"' -- #guard\n"
            "theorem t' : x' = '/' := rfl\n"
            '/-- doc\ntheorem in a doc -/\nexample : "two\nlines" = "" := rfl\n'
        )
        out = strip_lean(src)
        self.assertEqual(out.count("\n"), src.count("\n"))
        self.assertEqual(out.splitlines()[1], "")
        self.assertEqual(out.splitlines()[2], "#guard s = ")
        self.assertEqual(out.splitlines()[3], "def q :=  ")
        self.assertEqual(out.splitlines()[4], "theorem t' : x' =  := rfl")
        self.assertEqual(out.splitlines()[5:], ["", "", "example : ", " =  := rfl"])

    def test_lean_counts_each_library(self):
        lean = self.tmp / "lean"
        (lean / "Fir").mkdir(parents=True)
        (lean / "FirTest" / "Deep").mkdir(parents=True)
        (lean / ".lake" / "FirTest").mkdir(parents=True)
        (lean / "Fir.lean").write_text("import Fir.A\n#guard true\n")
        (lean / "Fir" / "A.lean").write_text(
            "@[simp] theorem a : 1 = 1 := rfl\n  private theorem b : True := ⟨⟩\n"
        )
        (lean / "FirTest" / "Deep" / "B.lean").write_text(
            "#guard_msgs in\n#eval 1\n  #guard 2 = 2\nexample : True := ⟨⟩\n"
            "-- #guard false\n/- theorem c -/\n#guard_expr 1 = 1\n"
        )
        (lean / ".lake" / "FirTest" / "C.lean").write_text("#guard true\n")
        (lean / "lakefile.lean").write_text("#guard true\n")
        self.assertEqual(
            lean_counts(lean), [["Fir", 1, 0, 2, 0], ["FirTest", 1, 1, 0, 1]]
        )
        status, out = self.run_main("lean", str(lean))
        self.assertEqual(status, 0)
        self.assertIn(
            "Lean checks that building lean/ ran: FirTest: 1 #guard,"
            " 1 #guard_msgs, 0 theorems, 1 examples\n",
            out,
        )
        self.assertIn(
            "| :-- | --: | --: | --: | --: |\n| Fir | 1 | 0 | 2 | 0 |",
            self.summary.read_text(),
        )

    def test_counts_writes_one_row(self):
        status, out = self.run_main("counts", "Round trip", "texts=861", "result=ok")
        self.assertEqual(status, 0)
        self.assertEqual(out, "Round trip: 861 texts, ok result\n")
        self.assertIn(
            "| Texts | Result |\n| --: | --: |\n| 861 | ok |", self.summary.read_text()
        )

    def test_usage(self):
        out = io.StringIO()
        with mock.patch("sys.stderr", out):
            self.assertEqual(main(["counts", "Title"]), 2)
            self.assertEqual(main(["lean"]), 2)
        self.assertFalse(self.summary.exists())


if __name__ == "__main__":
    unittest.main()
