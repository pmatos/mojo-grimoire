"""Tests for scripts/conformance.py. Run: python scripts/test_conformance.py"""

import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

import conformance_compiler
from conformance import (
    SUITE,
    check_known,
    compare,
    levels,
    load_patterns,
    model_result,
    name_of,
    programs,
    record,
    ruled_bugs,
    runs_cleanly,
)
from conformance_compiler import (
    Result,
    classify,
    failed_output,
    first_error,
    level_differences,
    same_first_error,
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

    def test_failed_instantiation_names_its_constraint(self):
        stderr = (
            "/x/a.mojo:1:5: error: function instantiation failed\n"
            "/x/a.mojo:3:13: note: call expansion failed\n"
            "list.mojo:9:9: note: constraint failed: negative indexing is not supported\n"
            "mojo: error: failed to run the pass manager\n"
        )
        self.assertEqual(
            first_error(stderr),
            "function instantiation failed: "
            "constraint failed: negative indexing is not supported",
        )

    def test_a_constraint_after_the_next_error_is_not_taken(self):
        stderr = (
            "a.mojo:1:5: error: function instantiation failed\n"
            "a.mojo:2:5: error: other\n"
            "note: constraint failed: unrelated\n"
        )
        self.assertEqual(first_error(stderr), "function instantiation failed")

    def test_an_assertion_is_not_printed_output(self):
        stdout = "before\nAt: /x/a.mojo:5:13: Assert Error: index -1 is out of bounds\n"
        self.assertEqual(
            failed_output(stdout), (("before",), "index -1 is out of bounds")
        )
        self.assertEqual(failed_output("a\nb\n"), (("a", "b"), None))

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


class Levels(unittest.TestCase):
    NOTED = "function instantiation failed: constraint failed: negative index"

    def test_the_same_result(self):
        r = Result("finished", ("1",))
        self.assertEqual(level_differences(r, r, "-O0"), [])

    def test_outcome_output_and_first_error_differ(self):
        ok = Result("finished", ("1",))
        found = level_differences(ok, Result("failed", ("1",)), "-O1")
        self.assertIn("outcome: finished at -O3, failed at -O1", found[0])
        self.assertIn("output", level_differences(ok, Result("finished", ()), "-O0")[0])
        a = Result("rejected", (), "x", "use of uninitialized value 'a'")
        b = Result("rejected", (), "x", "use of uninitialized value 'b'")
        self.assertIn("first error", level_differences(a, b, "-O2")[0])

    def test_a_missing_constraint_note_is_no_difference(self):
        self.assertTrue(same_first_error(self.NOTED, "function instantiation failed"))
        self.assertTrue(same_first_error("function instantiation failed", self.NOTED))
        bare = Result("rejected", (), None, "function instantiation failed")
        noted = Result("rejected", (), None, self.NOTED)
        self.assertEqual(level_differences(noted, bare, "-O0"), [])

    def test_two_constraint_notes_differ(self):
        other = "function instantiation failed: constraint failed: other"
        self.assertFalse(same_first_error(self.NOTED, other))
        self.assertFalse(same_first_error("function instantiation", self.NOTED))

    def test_a_failed_runs_detail_is_not_compared(self):
        a = Result("failed", ("before",), None, "index 3 is out of bounds")
        b = Result("failed", ("before",), None, "#0 0x7f18 PrintStackTrace")
        self.assertEqual(level_differences(a, b, "-O0"), [])


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
        self.fake = str(Path(__file__).resolve().with_name("fake_mojo.py"))

    def program(self, name: str, text: str) -> Path:
        program = self.tmp / f"{name}.mojo"
        program.write_text(text)
        return program

    def run_command(
        self, command, program: Path, ruled: dict, mojo: str = ""
    ) -> tuple[int, str]:
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            code = command(["--mojo", mojo or self.fake, str(program)], ruled=ruled)
        return code, out.getvalue()

    def recorded(self, name: str, text: str, ruled: dict | None = None) -> dict:
        program = self.program(name, text)
        self.assertEqual(self.run_command(record, program, ruled or {})[0], 0)
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

    def test_a_result_that_differs_at_O0_is_not_recorded(self):
        program = self.program("unstable", "# PRINT a\n# LEVEL -O0 garbage\n")
        code, out = self.run_command(record, program, {})
        self.assertEqual(code, 1)
        self.assertIn("output: ['a'] at -O3, ['a', 'garbage'] at -O0", out)
        self.assertFalse(program.with_suffix(".json").exists())

    def test_a_ruled_compiler_bug_is_recorded_at_O3(self):
        name = (self.tmp / "unstable").as_posix()
        text = "# PRINT a\n# LEVEL -O0 garbage\n"
        data = self.recorded("unstable", text, {name: "D-0003"})
        self.assertEqual(data["stdout"], ["a"])

    def test_the_assertion_line_at_O0_is_no_difference(self):
        data = self.recorded("assert", "# PRINT before\n# FAIL\n")
        self.assertEqual(data["stdout"], ["before"])

    def test_the_sweep_fails_on_a_difference_at_any_level(self):
        program = self.program("o1", "# PRINT a\n# LEVEL ASSERT=all b\n")
        code, out = self.run_command(levels, program, {})
        self.assertEqual(code, 1)
        self.assertIn("ASSERT=all: output: ['a'] at -O3, ['a', 'b'] at ASSERT=all", out)
        self.assertIn("1 programs at -O0, -O1, -O2, -O3, ASSERT=all", out)

    def test_the_sweep_lists_a_ruled_compiler_bug_and_passes(self):
        program = self.program("o2", "# PRINT a\n# LEVEL -O2 b\n")
        ruled = {(self.tmp / "o2").as_posix(): "D-0003"}
        code, out = self.run_command(levels, program, ruled)
        self.assertEqual(code, 0)
        self.assertIn("a compiler bug ruled in D-0003", out)
        self.assertIn("-O2: output", out)

    def test_the_sweep_reports_a_timeout_at_every_level(self):
        program = self.program("slow", "# PRINT a\n")
        real = conformance_compiler.run_compiler

        def slow(program, *args):
            if program.name == "smoke.mojo":
                return real(program, *args)
            raise subprocess.TimeoutExpired([self.fake, "build"], 1)

        with mock.patch("conformance_compiler.run_compiler", side_effect=slow):
            code, out = self.run_command(levels, program, {name_of(program): "D-1"})
        self.assertEqual(code, 1)
        self.assertIn("-O0: timed out", out)
        self.assertIn("1 could not be built", out)

    def test_a_build_with_no_compiler_error_is_never_compared(self):
        program = self.program("crash", "# PRINT a\n# CRASH -O1\n")
        code, out = self.run_command(levels, program, {name_of(program): "D-1"})
        self.assertEqual(code, 1)
        self.assertIn("-O1: build exit 139: Segmentation fault", out)
        for name, ruled in (("c0", False), ("c1", True)):
            program = self.program(name, "# CRASH -O0\n")
            named = {name_of(program): "D-0003"} if ruled else {}
            code, out = self.run_command(record, program, named)
            self.assertEqual(code, 1)
            self.assertIn("-O0: build exit 139", out)
            self.assertFalse(program.with_suffix(".json").exists())

    def test_record_refuses_a_ruled_program_whose_build_times_out(self):
        program = self.program("slow0", "# PRINT a\n")
        real = conformance_compiler.run_compiler

        def slow(program, mojo, patterns, flags=()):
            if "-O0" in flags:
                raise subprocess.TimeoutExpired([self.fake, "build"], 1)
            return real(program, mojo, patterns, flags)

        with mock.patch("conformance_compiler.run_compiler", side_effect=slow):
            code, out = self.run_command(record, program, {name_of(program): "D-0003"})
        self.assertEqual(code, 1)
        self.assertIn("-O0: timed out", out)
        self.assertFalse(program.with_suffix(".json").exists())

    def test_a_broken_wrapper_compares_nothing(self):
        broken = self.tmp / "broken"
        broken.write_text("#!/bin/sh\necho 'mojo: not found' >&2\nexit 127\n")
        broken.chmod(0o755)
        program = self.program("fine", "# PRINT a\n")
        for command in (levels, record):
            code, out = self.run_command(command, program, {}, str(broken))
            self.assertEqual(code, 2)
            self.assertIn("does not build and run a trivial program", out)
            code, out = self.run_command(command, program, {}, str(self.tmp / "none"))
            self.assertEqual(code, 2)

    def test_a_wrapper_that_rejects_everything_compares_nothing(self):
        rejecting = self.tmp / "rejecting"
        rejecting.write_text(
            "#!/bin/sh\necho \"x.mojo:1:1: error: unable to locate module 'std'\" >&2\n"
            "exit 1\n"
        )
        rejecting.chmod(0o755)
        program = self.program("fine", "# PRINT a\n")
        for command in (levels, record):
            code, out = self.run_command(command, program, {}, str(rejecting))
            self.assertEqual(code, 2)
            self.assertIn("does not build and run a trivial program", out)

    def test_arguments_that_are_not_programs_are_refused(self):
        program = self.program("fine", "# PRINT a\n")
        for args in (
            [str(self.tmp / "nosuch.mojo")],
            [str(program), "--bogus"],
            [str(program), "--jobs", "2"],
        ):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(record(["--mojo", self.fake, *args], ruled={}), 2)
        with redirect_stdout(io.StringIO()):
            self.assertEqual(
                levels(["--mojo", self.fake, str(program), "--jobs", "2"], ruled={}), 0
            )

    def test_the_excuse_rule_reads_known_compiler_bugs_and_the_log(self):
        text = "# PRINT a\n# LEVEL -O0 garbage\n"
        known, unentried, bug_only, bad_bug, unnamed = (
            self.program(n, text) for n in ("k", "u", "b", "x", "n")
        )
        (self.tmp / "known.json").write_text(
            json.dumps(
                {"known": {name_of(known): "D-0003", name_of(unentried): "D-0099"}}
            )
        )
        # A bug that shows only below -O3 names its program in
        # compiler-bugs.json alone: the model agrees with the -O3 result.
        bugs = [
            {"decision_log": "D-0010", "suite_programs": [name_of(bug_only)]},
            {"decision_log": "D-0042", "suite_programs": [name_of(bad_bug)]},
        ]
        (self.tmp / "bugs.json").write_text(json.dumps({"bugs": bugs}))
        (self.tmp / "log.md").write_text("### D-0003: one\n### D-0010: two\nD-0042\n")
        ruled = ruled_bugs(
            self.tmp / "known.json", self.tmp / "bugs.json", self.tmp / "log.md"
        )
        self.assertEqual(ruled, {name_of(known): "D-0003", name_of(bug_only): "D-0010"})
        for program, code in ((known, 0), (unentried, 1), (bug_only, 0), (bad_bug, 1)):
            self.assertEqual(self.run_command(record, program, ruled)[0], code)
            self.assertEqual(program.with_suffix(".json").exists(), code == 0)
            self.assertEqual(self.run_command(levels, program, ruled)[0], code)
        code, out = self.run_command(record, unnamed, ruled)
        self.assertEqual(code, 1)
        self.assertIn("no ruled compiler bug names the program", out)

    def test_the_suites_ruled_bugs_are_entries_of_the_log(self):
        ruled = ruled_bugs()
        self.assertEqual(ruled["structs/field_by_field_unset_nested"], "D-0003")
        self.assertTrue(set(ruled) <= {name_of(p) for p in programs()})

    def test_the_sweep_passes_when_every_level_agrees(self):
        program = self.program("stable", "# PRINT a\n# FAIL\n")
        code, out = self.run_command(levels, program, {})
        self.assertEqual(code, 0)
        self.assertIn("1 the same", out)


class Suite(unittest.TestCase):
    def test_names(self):
        progs = programs()
        self.assertTrue(progs)
        self.assertTrue(all(not os.path.isabs(name_of(p)) for p in progs))
        self.assertIn("basics/arithmetic", {name_of(p) for p in progs})

    def test_every_recorded_rejection_classifies_as_recorded(self):
        patterns, seen, wrong = load_patterns(), 0, []
        for name, recorded in recorded_rejections():
            seen += 1
            got = classify(recorded["diagnostic"], patterns)
            if got != recorded["class"]:
                wrong.append(f"{name}: {recorded['class']} -> {got}")
        self.assertTrue(seen)
        self.assertEqual(wrong, [], "re-record the programs a pattern reclassifies")

    def test_no_loose_pattern_can_take_a_quoted_name(self):
        patterns = [pattern for pattern, _ in load_patterns()]
        quoting = [p for p in patterns if "'[^']*'" in p or "'.*'" in p]
        loose, wrong = [], [p for p in quoting if not whole(p)]
        for p in patterns:
            if p in quoting:
                wrong += [
                    f"{above} above {p}" for above in loose if takes_a_name(above)
                ]
            elif not whole(p):
                loose.append(p)
        for name, recorded in recorded_rejections():
            message = recorded["diagnostic"]
            first = next((p for p in patterns if re.search(p, message)), None)
            if "'" in message and first not in quoting:
                wrong.append(f"{name}: no whole pattern for {message}")
        self.assertEqual(wrong, [])


def recorded_rejections():
    """Each recorded rejection of the suite, with its program's name."""
    for program in programs():
        path = program.with_suffix(".json")
        if path.exists():
            recorded = json.loads(path.read_text())
            if recorded["outcome"] == "rejected":
                yield name_of(program), recorded


def whole(pattern: str) -> bool:
    return pattern.startswith("^") and pattern.endswith("$")


def takes_a_name(pattern: str) -> bool:
    """Whether a loose pattern matches a quoted name made of its words."""
    words = re.findall(r"[A-Za-z_]\w*", pattern)
    return any(re.search(pattern, f"'{n}'") for n in [*words, "_".join(words)])


if __name__ == "__main__":
    unittest.main()
