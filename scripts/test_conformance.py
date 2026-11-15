"""Tests for scripts/conformance.py. Run: python scripts/test_conformance.py"""

import io
import json
import os
import stat
import tempfile
import textwrap
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from conformance import (
    SUITE,
    Result,
    check_known,
    classify,
    compare,
    first_error,
    load_patterns,
    model_result,
    name_of,
    programs,
    record,
    runs_cleanly,
)


class ModelOutput(unittest.TestCase):
    def test_finished(self):
        r = model_result(0, "a 1\nb\n", "")
        self.assertEqual(r, Result("finished", ("a 1", "b")))

    def test_rejected(self):
        r = model_result(1, "", "rejected: implicitCopy in main\n")
        self.assertEqual((r.outcome, r.error_class), ("rejected", "implicitCopy"))

    def test_failed_keeps_output(self):
        r = model_result(2, "before\n", "run-time error: divisionByZero\n")
        self.assertEqual(r.outcome, "failed")
        self.assertEqual(r.stdout, ("before",))
        self.assertEqual(r.detail, "divisionByZero")

    def test_syntax_error_is_an_error(self):
        r = model_result(3, "", "syntax error: line 2: expected a name\n")
        self.assertEqual(r.outcome, "error")
        self.assertIn("line 2", r.detail)


class Diagnostics(unittest.TestCase):
    def test_first_error_drops_the_location(self):
        stderr = "/x/a.mojo:3:5: error: use of uninitialized value 'a'\nnote: here\n"
        self.assertEqual(first_error(stderr), "use of uninitialized value 'a'")

    def test_classify_takes_the_first_match(self):
        patterns = [("uninit", "uninitializedUse"), ("value", "other")]
        self.assertEqual(
            classify("use of uninitialized value", patterns), "uninitializedUse"
        )
        self.assertIsNone(classify("something else", patterns))

    def test_the_suite_patterns_load_and_name_known_classes(self):
        lean = (
            SUITE.parent.parent / "lean" / "MojoGrimoire" / "Driver" / "Main.lean"
        ).read_text()
        for _, cls in load_patterns():
            self.assertIn(f'=> "{cls}"', lean)


class Compare(unittest.TestCase):
    def test_agreement(self):
        r = Result("finished", ("1",))
        self.assertEqual(compare(r, r), [])

    def test_outcome_differs(self):
        found = compare(Result("finished", ()), Result("rejected", (), "x"))
        self.assertEqual(len(found), 1)
        self.assertIn("outcome", found[0])

    def test_output_differs(self):
        found = compare(Result("finished", ("1",)), Result("finished", ("2",)))
        self.assertIn("output", found[0])

    def test_rejection_class(self):
        exp = Result("rejected", (), "implicitCopy")
        self.assertEqual(compare(exp, Result("rejected", (), "implicitCopy")), [])
        self.assertIn("class", compare(exp, Result("rejected", (), "typeMismatch"))[0])
        unclassified = Result("rejected", (), None)
        self.assertIn("no class", compare(unclassified, exp)[0])

    def test_failure_compares_output_not_class(self):
        exp = Result("failed", ("before",), None, "abort")
        act = Result("failed", ("before",), None, "indexOutOfBounds")
        self.assertEqual(compare(exp, act), [])

    def test_stuck_is_never_agreement(self):
        exp = Result("failed", ())
        act = Result("failed", (), None, "stuck (no value)")
        self.assertIn("stuck", compare(exp, act)[0])
        self.assertIn("stuck", runs_cleanly(act)[0])

    def test_error_is_never_agreement(self):
        act = Result("error", (), None, "syntax error")
        self.assertIn("could not run", compare(Result("finished", ()), act)[0])


class Known(unittest.TestCase):
    LOG = "### D-0002: something\n"

    def test_valid(self):
        self.assertEqual(check_known({"a/b": "D-0002"}, {"a/b"}, self.LOG), [])

    def test_missing_program_and_entry(self):
        found = check_known({"a/c": "D-0009"}, {"a/b"}, self.LOG)
        self.assertEqual(len(found), 2)


class Record(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        # A stand-in compiler: it rejects a program that contains REJECT,
        # and builds any other into a script that prints its PRINT lines
        # and fails when it contains FAIL.
        fake = self.tmp / "mojo"
        fake.write_text(
            textwrap.dedent("""\
            #!/usr/bin/env python3
            import sys
            src = open(sys.argv[2]).read()
            if "REJECT" in src:
                print(sys.argv[2] + ":1:1: error: use of uninitialized value 'a'",
                      file=sys.stderr)
                sys.exit(1)
            out = [l.split("PRINT ", 1)[1] for l in src.splitlines() if "PRINT " in l]
            code = 1 if "FAIL" in src else 0
            with open(sys.argv[4], "w") as f:
                f.write("#!/bin/sh\\n" + "".join(f"echo '{l}'\\n" for l in out)
                        + f"exit {code}\\n")
            import os
            os.chmod(sys.argv[4], 0o755)
            """)
        )
        fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
        self.fake = str(fake)

    def recorded(self, name: str, text: str) -> dict:
        program = self.tmp / f"{name}.mojo"
        program.write_text(text)
        with redirect_stdout(io.StringIO()):
            self.assertEqual(record(["--mojo", self.fake, str(program)]), 0)
        return json.loads(program.with_suffix(".json").read_text())

    def test_finished(self):
        data = self.recorded("ok", "# PRINT hello\n# PRINT 2\n")
        self.assertEqual(data["outcome"], "finished")
        self.assertEqual(data["stdout"], ["hello", "2"])

    def test_rejected_with_class(self):
        data = self.recorded("bad", "# REJECT\n")
        self.assertEqual(data["outcome"], "rejected")
        self.assertEqual(data["class"], "uninitializedUse")

    def test_failed(self):
        data = self.recorded("boom", "# PRINT before\n# FAIL\n")
        self.assertEqual(data["outcome"], "failed")
        self.assertEqual(data["stdout"], ["before"])


class Suite(unittest.TestCase):
    def test_names(self):
        progs = programs()
        self.assertTrue(progs)
        self.assertTrue(all(not os.path.isabs(name_of(p)) for p in progs))
        self.assertIn("basics/arithmetic", {name_of(p) for p in progs})


if __name__ == "__main__":
    unittest.main()
