"""Tests for the explorer, scripts/explorer.py: its runners, verdicts, spec
index and suite. test_explorer_proc.py tests its processes, and
test_explorer_server.py its servers.
Run: python -m unittest discover -s scripts -p 'test_explorer*.py'"""

import json
import os
import stat
import tempfile
import unittest
from pathlib import Path

import explorer
import explorer_run as run
import explorer_spec as spec
from conformance import load_patterns, run_model
from conformance_compiler import Result, run_compiler
from explorer_suite import Suite, decision_entries, normalized

HERE = Path(__file__).resolve().parent
FAKE = str(HERE / "fake_mojo.py")
LIMITS = run.Limits(build=30, run=10, model=10, output=4096)
PATTERNS = load_patterns()
FINISHED = Result("finished", ("1",))
TYPE = Result("rejected", (), "typeMismatch", "x")
FLOW = Result("rejected", (), "uninitializedUse", "y")

PROGRAMS = {
    "prints": 'def main():\n    print("hi")\n# PRINT two\n',
    "rejected": "def main():\n    REJECT\n",
    "fails": "# PRINT before\n# FAIL\n",
    "crashes": "# CRASH -O0\n# PRINT x\n",
    "levels": "# LEVEL -O0 only at O0\n# PRINT always\n",
}


def script(directory: Path, name: str, body: str) -> Path:
    path = directory / name
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


class SameResultAsTheSuite(unittest.TestCase):
    """The explorer's runners give the Result that the suite's give."""

    def test_compiler(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name, source in PROGRAMS.items():
                program = Path(tmp) / f"{name}.mojo"
                program.write_text(source)
                for flags in ((), ("-O0",)):
                    with self.subTest(name=name, flags=flags):
                        mine = run.run_on_compiler(
                            source, FAKE, PATTERNS, flags, LIMITS
                        )
                        theirs = run_compiler(program, FAKE, PATTERNS, flags)
                        self.assertEqual(mine["_result"], theirs)

    def test_model(self):
        cases = {
            "finished": "echo 1; echo 2; exit 0",
            "rejected": "echo 'rejected: implicitCopy in S.m' >&2; exit 1",
            "failed": "echo a; echo 'run-time error: indexOutOfBounds' >&2; exit 2",
            "syntax": "echo 'syntax error: line 3: expected a name' >&2; exit 3",
            "outside": "echo 'outside the subset: line 2: async' >&2; exit 3",
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, body in cases.items():
                model = script(Path(tmp), name, f"#!/bin/sh\n{body}\n")
                program = Path(tmp) / "p.mojo"
                program.write_text("def main():\n    pass\n")
                with self.subTest(name=name):
                    mine = run.run_on_model("x", model, None, LIMITS)
                    self.assertEqual(mine["_result"], run_model(program, model))

    def test_model_positions(self):
        with tempfile.TemporaryDirectory() as tmp:
            model = script(
                Path(tmp),
                "m",
                "#!/bin/sh\necho 'outside the subset: line 2: async' >&2\nexit 3\n",
            )
            report = run.run_on_model("x", model, None, LIMITS)
            self.assertEqual(
                report["position"],
                {"kind": "outside the subset", "line": 2, "message": "async"},
            )
            model = script(
                Path(tmp),
                "r",
                "#!/bin/sh\necho 'rejected: notAPlace in S.m' >&2\nexit 1\n",
            )
            self.assertEqual(run.run_on_model("x", model, None, LIMITS)["decl"], "S.m")

    def test_model_gets_its_fuel(self):
        with tempfile.TemporaryDirectory() as tmp:
            model = script(Path(tmp), "m", '#!/bin/sh\necho "$2 $3"\n')
            report = run.run_on_model("x", model, 77, LIMITS)
            self.assertEqual(report["_result"].stdout, ("--fuel 77",))


class Verdicts(unittest.TestCase):
    def test_agree_and_disagree_by_compare(self):
        self.assertEqual(run.verdict(FINISHED, FINISHED, None)["state"], "agree")
        v = run.verdict(TYPE, FLOW, None)
        self.assertEqual(v["state"], "disagree")
        self.assertEqual(
            v["problems"], ["class: expected typeMismatch, model uninitializedUse"]
        )

    def test_a_model_syntax_error_never_agrees(self):
        model = Result("error", (), None, "syntax error: line 1: x")
        self.assertEqual(run.verdict(TYPE, model, None)["state"], "disagree")

    def test_known_as_check_reads_it(self):
        self.assertEqual(run.verdict(TYPE, FLOW, "D-0014")["state"], "known")
        v = run.verdict(TYPE, TYPE, "D-0014")
        self.assertEqual(v["state"], "disagree")
        self.assertIn("known.json lists it", v["problems"][0])

    def test_no_verdict_without_a_compiler_result(self):
        broken = Result("error", (), None, "timed out")
        self.assertEqual(run.verdict(broken, FINISHED, None)["state"], "no-verdict")

    def test_levels(self):
        self.assertEqual(run.level_flags("default"), ())
        self.assertEqual(run.level_flags("-O0"), ("-O0",))
        self.assertEqual(run.level_flags("ASSERT=all"), ("-D", "ASSERT=all"))
        with self.assertRaises(ValueError):
            run.level_flags("-O9")

    def test_sweep_flags_a_level_that_differs(self):
        def compile_at(flags):
            out = ("0",) if flags == ("-O0",) else ("3",)
            return {"_result": Result("finished", out)}

        rows = run.sweep_levels(compile_at, 2, Result("finished", ("3",)))
        differs = {r["level"]: r["differs"] for r in rows}
        self.assertEqual(
            differs,
            {
                "-O0": True,
                "-O1": False,
                "-O2": False,
                "-O3": False,
                "ASSERT=all": False,
            },
        )

    def test_diagnostics_located_in_the_program(self):
        program = Path("/tmp/x/program.mojo")
        stderr = (
            f"{program}:1:5: error: function instantiation failed\n"
            f"{program}:3:25: note: call expansion failed\n"
            "std/simd.mojo:9:9: note: constraint failed: no\n"
            "mojo: error: failed to run the pass manager\n"
        )
        found = run.diagnostics(stderr, program)
        self.assertEqual(
            [(d["line"], d["column"], d["primary"]) for d in found],
            [(1, 5, True), (3, 25, False)],
        )


HOVER = (
    '<code>A.b : Nat</code><span class="sep"></span><div class="docstring">'
    "<p>Some <code>b</code> doc.</p></div>"
)


class SpecIndex(unittest.TestCase):
    def make(self, tmp: Path) -> Path:
        (tmp / "Errors").mkdir()
        (tmp / "index.html").write_text(
            "<title>Spec</title><p>Built from commit <code>0123456789ab</code></p>"
        )
        (tmp / "Errors" / "index.html").write_text(
            '<title>Errors</title><span data-verso-hover="7" '
            'id="MojoGrimoire___Check___CheckError___notAPlace">x</span>'
            '<a href="#MojoGrimoire___Core___Stmt">Stmt</a>'
        )
        (tmp / "Other.html").write_text(
            '<span id="MojoGrimoire___Check___CheckError___notAPlace">x</span>'
        )
        (tmp / "-verso-docs.json").write_text(json.dumps({"7": HOVER}))
        return tmp

    def test_index_from_anchor_ids(self):
        with tempfile.TemporaryDirectory() as name:
            index = spec.build_index(self.make(Path(name)))
            decl = index.get("MojoGrimoire.Check.CheckError.notAPlace")
            self.assertEqual(
                decl.url("http://127.0.0.1:9"),
                "http://127.0.0.1:9/Errors/#MojoGrimoire___Check___CheckError___notAPlace",
            )
            self.assertEqual((decl.sig, decl.doc), ("A.b : Nat", "Some `b` doc."))
            self.assertIsNone(
                index.get("MojoGrimoire.Core.Stmt"), "an href is no anchor"
            )
            self.assertEqual(index.commit, "0123456789ab")
            self.assertEqual(len(index.warnings), 1)
            self.assertIn("Other.html", index.warnings[0])

    def test_missing_names_warn(self):
        with tempfile.TemporaryDirectory() as name:
            index = spec.build_index(self.make(Path(name)))
            tokens = {
                "x": {
                    "kind": "keyword",
                    "decls": [
                        "MojoGrimoire.Check.CheckError.notAPlace",
                        "MojoGrimoire.Nope",
                    ],
                }
            }
            self.assertEqual(len(spec.check_tokens(tokens, index)), 1)
            payload = spec.spec_payload(tokens, index)
            self.assertIn("notAPlace", payload["classes"])

    def test_no_spec_warns_once(self):
        index = spec.build_index(Path("/nonexistent"))
        self.assertEqual(len(index.warnings), 1)
        self.assertEqual(
            spec.check_tokens({"x": {"kind": "", "decls": ["A"]}}, index), []
        )

    def test_the_token_map_against_the_rendered_spec(self):
        if not (explorer.SPEC / "index.html").is_file():
            self.skipTest("the spec is not rendered; run scripts/build-spec.sh")
        index = spec.build_index(explorer.SPEC)
        tokens = spec.load_tokens(explorer.UI / "tokens.json")
        self.assertEqual(spec.check_tokens(tokens, index), [])
        payload = spec.spec_payload(tokens, index)
        self.assertIn("notAPlace", payload["classes"])
        self.assertIn("indexOutOfBounds", payload["runErrors"])


class TheSuite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.suite = Suite()

    def test_a_suite_program_matches_by_its_text(self):
        name = "arrays/or_unevaluated_literal_length"
        source = self.suite.examples[name].path.read_text()
        found = self.suite.match(source.replace("\n", "  \r\n") + "\n\n")
        self.assertEqual(found.name, name)
        self.assertEqual(found.known, "D-0014")
        self.assertIsNone(self.suite.match(source + "\n    print(1)\n"))

    def test_entries_and_bugs(self):
        entry = self.suite.entry("D-0014")
        self.assertIn("short-circuited", entry["title"])
        self.assertEqual(entry["bug"]["issue"], 324)
        self.assertIn("D-0002", decision_entries())
        self.assertEqual(normalized("a  \r\nb\n\n"), "a\nb")


if __name__ == "__main__":
    os.chdir(HERE)
    unittest.main()
