#!/usr/bin/env python3
"""Runs the conformance suite of tests/conformance/ against the model, and
records the reference compiler's results (docs/decisions/conformance.md).

Each program `tests/conformance/AREA/NAME.mojo` has its expected result in
`AREA/NAME.json`, recorded from the pinned compiler:

    {"outcome": "finished" | "rejected" | "failed",
     "stdout": [the lines printed],
     "class": the class of error of a rejection, or null,
     "diagnostic": the compiler's first error, for a rejection}

A rejection's class is found by matching the compiler's first error against
the patterns of tests/conformance/diagnostics.json, in order; a diagnostic
that none matches is recorded with the class null, and `record` lists it, so
that a pattern is added for it. When the first error only says that a
function could not be instantiated, the note that names the constraint
which failed is added to it, since that note says why.

Usage:
  scripts/conformance.py record --mojo WRAPPER [PROGRAM...]
      Runs each program with the compiler, through the wrapper that
      scripts/install-mojo.sh prints, and writes its expected result: a
      program the compiler cannot build is rejected; one it builds is run,
      and finishes or fails by its exit status. Each program is also built at
      -O0, and is not recorded when its result there differs from the
      default -O3 build's, unless a ruled compiler bug names it: known.json
      lists it under an entry of the decision log. The recorded result is
      the default build's.
  scripts/conformance.py levels --mojo WRAPPER [--jobs N] [PROGRAM...]
      Builds each program, or the whole suite, at -O0, -O1, -O2 and -O3 and
      with -D ASSERT=all, and lists every program whose result differs
      between them. It fails when a program that no ruled compiler bug
      names differs. Run it whenever the pinned compiler moves.
  scripts/conformance.py check [--allow-unrecorded] [--no-build]
      Builds lean/ with scripts/build-lean.sh, unless --no-build, then runs
      the model's executable on every program and compares its outcome,
      printed lines and class of error with the expected result. A program
      listed in tests/conformance/known.json disagrees by a decision-log
      entry, which must exist. A program with no expected result fails
      unless --allow-unrecorded is given; then the model must still read
      the program and run it without getting stuck.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUITE = ROOT / "tests" / "conformance"
MODEL = ROOT / "lean" / ".lake" / "build" / "bin" / "mojo-grimoire"
DECISION_LOG = ROOT / "docs" / "conformance" / "decision-log.md"
TIMEOUT = 120

OUTCOMES = ("finished", "rejected", "failed")


@dataclass(frozen=True)
class Result:
    """How a run of a program ended, by the compiler or by the model."""

    outcome: str
    stdout: tuple[str, ...]
    error_class: str | None = None
    detail: str | None = None

    def to_json(self) -> dict:
        return {
            "outcome": self.outcome,
            "stdout": list(self.stdout),
            "class": self.error_class,
            "diagnostic": self.detail,
        }

    @staticmethod
    def from_json(data: dict) -> Result:
        if data.get("outcome") not in OUTCOMES:
            raise ValueError(f"unknown outcome {data.get('outcome')!r}")
        return Result(data["outcome"], tuple(data.get("stdout", [])), data.get("class"))


def programs(root: Path = SUITE) -> list[Path]:
    """The suite's programs, sorted."""
    return sorted(root.rglob("*.mojo"))


def name_of(program: Path, root: Path = SUITE) -> str:
    """A program's name: its path in the suite, without `.mojo`, or its own
    path when it is outside the suite."""
    if program.is_relative_to(root):
        return program.relative_to(root).with_suffix("").as_posix()
    return program.with_suffix("").as_posix()


def lines(text: str) -> tuple[str, ...]:
    """The lines of a program's standard output."""
    return tuple(text.splitlines())


# --- the model ------------------------------------------------------------

MODEL_REJECTED = re.compile(r"^rejected: (\w+) in (\S+)$", re.MULTILINE)
MODEL_FAILED = re.compile(r"^run-time error: (.+)$", re.MULTILINE)


def model_result(code: int, stdout: str, stderr: str) -> Result:
    """The result of a run of the model's executable, from its exit code and
    output (MojoGrimoire.Driver)."""
    if code == 0:
        return Result("finished", lines(stdout))
    if code == 1 and (m := MODEL_REJECTED.search(stderr)):
        return Result("rejected", (), m.group(1), f"in {m.group(2)}")
    if code == 2 and (m := MODEL_FAILED.search(stderr)):
        return Result("failed", lines(stdout), None, m.group(1))
    return Result("error", lines(stdout), None, stderr.strip() or f"exit {code}")


def run_model(program: Path, model: Path = MODEL) -> Result:
    proc = subprocess.run(
        [str(model), str(program)],
        capture_output=True,
        text=True,
        timeout=TIMEOUT,
        check=False,
    )
    return model_result(proc.returncode, proc.stdout, proc.stderr)


# --- the compiler ---------------------------------------------------------

ERROR_LINE = re.compile(r"error: (.*)")
CONSTRAINT_NOTE = re.compile(r"note: (constraint failed: .*)")


def first_error(stderr: str) -> str:
    """The message of the compiler's first error, without its location, with
    the failed constraint's note when the error is a failed instantiation."""
    lines = stderr.splitlines()
    for i, line in enumerate(lines):
        if m := ERROR_LINE.search(line):
            message = m.group(1).strip()
            if message == "function instantiation failed":
                for later in lines[i + 1 :]:
                    if ERROR_LINE.search(later):
                        break
                    if n := CONSTRAINT_NOTE.search(later):
                        return f"{message}: {n.group(1).strip()}"
            return message
    return stderr.strip().splitlines()[0] if stderr.strip() else ""


ASSERT_LINE = re.compile(r"^At: \S+: Assert Error: (.*)$")


def failed_output(stdout: str) -> tuple[tuple[str, ...], str | None]:
    """The lines that a failed run printed, and the message of the assertion
    that stopped it. The runtime writes a failed assertion on standard
    output, with the program's absolute path; it is how the run ended, not
    a line the program printed."""
    printed, assertion = [], None
    for line in lines(stdout):
        if m := ASSERT_LINE.match(line):
            assertion = assertion or m.group(1)
        else:
            printed.append(line)
    return tuple(printed), assertion


def classify(message: str, patterns: list[tuple[str, str]]) -> str | None:
    """The class of the first pattern that the diagnostic matches."""
    for pattern, cls in patterns:
        if re.search(pattern, message):
            return cls
    return None


def load_patterns(path: Path = SUITE / "diagnostics.json") -> list[tuple[str, str]]:
    data = json.loads(path.read_text())
    return [(entry["pattern"], entry["class"]) for entry in data["patterns"]]


def run_compiler(
    program: Path,
    mojo: str,
    patterns: list[tuple[str, str]],
    flags: tuple[str, ...] = (),
) -> Result:
    """The compiler's result for a program, built with the default -O3, or
    with `flags`, such as another optimization level."""
    with tempfile.TemporaryDirectory() as tmp:
        binary = Path(tmp) / "program"
        build = subprocess.run(
            [mojo, "build", *flags, str(program), "-o", str(binary)],
            capture_output=True,
            text=True,
            timeout=TIMEOUT * 5,
            check=False,
        )
        if build.returncode != 0:
            message = first_error(build.stderr)
            return Result("rejected", (), classify(message, patterns), message)
        run = subprocess.run(
            [str(binary)], capture_output=True, text=True, timeout=TIMEOUT, check=False
        )
        if run.returncode == 0:
            return Result("finished", lines(run.stdout))
        printed, assertion = failed_output(run.stdout)
        detail = assertion or first_error(run.stderr) or f"exit {run.returncode}"
        return Result("failed", printed, None, detail)


# --- optimization levels --------------------------------------------------

# The builds that the level sweep compares; -O3 is the default level.
LEVELS = {
    "-O0": ("-O0",),
    "-O1": ("-O1",),
    "-O2": ("-O2",),
    "-O3": ("-O3",),
    "ASSERT=all": ("-D", "ASSERT=all"),
}
INSTANTIATION = "function instantiation failed"


def same_first_error(a: str | None, b: str | None) -> bool:
    """Whether two builds gave the same first error. A failed instantiation
    whose constraint note one build left out agrees with the noted one."""
    if a == b:
        return True
    short, full = sorted((a or "", b or ""), key=len)
    return short == INSTANTIATION and full.startswith(INSTANTIATION + ": ")


def level_differences(reference: Result, other: Result, level: str) -> list[str]:
    """How the compiler's result at another level differs from its result
    at the default -O3; empty when they agree. Both come from run_compiler,
    so a failed assertion's line on standard output is never a printed
    line. A failed run's detail is not compared: without an assertion it
    is the runtime's first stack frame, which changes from run to run."""
    if reference.outcome != other.outcome:
        return [f"outcome: {reference.outcome} at -O3, {other.outcome} at {level}"]
    problems = []
    if reference.stdout != other.stdout:
        problems.append(
            f"output: {list(reference.stdout)} at -O3, {list(other.stdout)} at {level}"
        )
    if reference.outcome == "rejected" and not same_first_error(
        reference.detail, other.detail
    ):
        problems.append(
            f"first error: {reference.detail!r} at -O3, {other.detail!r} at {level}"
        )
    return problems


def build_at(program: Path, mojo: str, patterns, level: str) -> Result:
    """The compiler's result at a level of LEVELS; a build or run that
    times out is a result of its own, so that it is reported."""
    try:
        return run_compiler(program, mojo, patterns, LEVELS[level])
    except subprocess.TimeoutExpired as e:
        return Result("error", (), None, f"timed out: {e.cmd[0]}")


def across_levels(program: Path, mojo: str, patterns) -> list[str]:
    """How the program's result differs between the levels of LEVELS."""
    results = {level: build_at(program, mojo, patterns, level) for level in LEVELS}
    reference = results["-O3"]
    return [
        f"{level}: {p}"
        for level, result in results.items()
        if level != "-O3"
        for p in level_differences(reference, result, level)
    ]


# --- comparison -----------------------------------------------------------


def compare(expected: Result, actual: Result) -> list[str]:
    """How the model's result differs from the expected one; empty when they
    agree. Lines printed before a run-time failure count; its class does
    not, since the compiler does not name one."""
    if found := runs_cleanly(actual):
        return found
    if expected.outcome != actual.outcome:
        return [f"outcome: expected {expected.outcome}, model {actual.outcome}"]
    problems = []
    if expected.stdout != actual.stdout:
        problems.append(
            f"output: expected {list(expected.stdout)}, model {list(actual.stdout)}"
        )
    if expected.outcome == "rejected":
        if expected.error_class is None:
            problems.append("the compiler's diagnostic has no class")
        elif expected.error_class != actual.error_class:
            problems.append(
                f"class: expected {expected.error_class}, model {actual.error_class}"
            )
    return problems


def runs_cleanly(actual: Result) -> list[str]:
    """What is wrong with an unrecorded program's run by the model."""
    if actual.outcome == "error":
        return [f"the model could not run it: {actual.detail}"]
    if actual.outcome == "failed" and (actual.detail or "").startswith("stuck"):
        return [f"the model got stuck: {actual.detail}"]
    return []


def load_known(path: Path = SUITE / "known.json") -> dict[str, str]:
    return json.loads(path.read_text())["known"] if path.exists() else {}


def is_entry(entry: str, log: str) -> bool:
    """Whether `entry` is the id of an entry of the decision log."""
    return re.fullmatch(r"D-\d{4}", entry) is not None and f"### {entry}:" in log


def check_known(known: dict[str, str], names: set[str], log: str) -> list[str]:
    """Problems with the list of known disagreements."""
    problems = []
    for name, entry in sorted(known.items()):
        if name not in names:
            problems.append(f"known.json lists {name}, which is not a program")
        if not is_entry(entry, log):
            problems.append(f"known.json cites {entry} for {name}, not an entry")
    return problems


def ruled_bugs() -> dict[str, str]:
    """The programs that a ruled compiler bug names, with its entry: those
    that known.json lists under an entry of the decision log."""
    log = DECISION_LOG.read_text()
    return {name: e for name, e in load_known().items() if is_entry(e, log)}


# --- commands -------------------------------------------------------------


def record(args: list[str], ruled: dict[str, str] | None = None) -> int:
    if len(args) < 2 or args[0] != "--mojo":
        print(__doc__, file=sys.stderr)
        return 2
    mojo, chosen = args[1], args[2:]
    patterns = load_patterns()
    ruled = ruled_bugs() if ruled is None else ruled
    targets = [Path(p).resolve() for p in chosen] or programs()
    unclassified, refused = [], []
    for program in targets:
        name = name_of(program)
        result = run_compiler(program, mojo, patterns)
        at_o0 = run_compiler(program, mojo, patterns, LEVELS["-O0"])
        if found := level_differences(result, at_o0, "-O0"):
            if name not in ruled:
                refused.extend(f"{name}: {p}" for p in found)
                print(f"{name}: not recorded, its result differs at -O0")
                continue
            print(f"{name}: differs at -O0, a compiler bug ruled in {ruled[name]}")
        out = program.with_suffix(".json")
        out.write_text(json.dumps(result.to_json(), indent=2) + "\n")
        print(f"{name_of(program)}: {result.outcome}", result.error_class or "")
        if result.outcome == "rejected" and result.error_class is None:
            unclassified.append(f"{name_of(program)}: {result.detail}")
    if unclassified:
        print("\nDiagnostics with no class; add a pattern to diagnostics.json:")
        print("\n".join(unclassified))
    if refused:
        print(
            "\nNot recorded, the result differs between levels; rule on a "
            "compiler bug or change the program:",
            file=sys.stderr,
        )
        print("\n".join(refused), file=sys.stderr)
    return 1 if refused else 0


def levels(args: list[str], ruled: dict[str, str] | None = None) -> int:
    if len(args) < 2 or args[0] != "--mojo":
        print(__doc__, file=sys.stderr)
        return 2
    mojo, rest = args[1], args[2:]
    jobs = 4
    if rest[:1] == ["--jobs"] and len(rest) > 1:
        jobs, rest = int(rest[1]), rest[2:]
    patterns = load_patterns()
    ruled = ruled_bugs() if ruled is None else ruled
    targets = [Path(p).resolve() for p in rest] or programs()
    with ThreadPoolExecutor(jobs) as pool:
        found = list(pool.map(lambda p: across_levels(p, mojo, patterns), targets))
    same = excused = 0
    problems = []
    for program, differences in zip(targets, found, strict=True):
        name = name_of(program)
        if not differences:
            same += 1
            continue
        if name in ruled:
            excused += 1
            print(
                f"{name}: differs between levels, a compiler bug ruled in {ruled[name]}"
            )
            print("\n".join(f"  {d}" for d in differences))
            continue
        problems.extend(f"{name}: {d}" for d in differences)
    differ = len(targets) - same - excused
    print(
        f"{len(targets)} programs at {', '.join(LEVELS)}: {same} the same, "
        f"{excused} differ by a ruled compiler bug, {differ} differ"
    )
    for p in problems:
        print(p, file=sys.stderr)
    return 1 if problems else 0


def check(args: list[str]) -> int:
    allow_unrecorded = "--allow-unrecorded" in args
    if "--no-build" not in args:
        build = subprocess.run([str(ROOT / "scripts" / "build-lean.sh")], check=False)
        if build.returncode != 0:
            return build.returncode
    progs = programs()
    known = load_known()
    names = {name_of(p) for p in progs}
    problems = check_known(known, names, DECISION_LOG.read_text())
    counts = {"agree": 0, "known": 0, "unrecorded": 0, "disagree": 0}
    for program in progs:
        name = name_of(program)
        actual = run_model(program)
        expected_file = program.with_suffix(".json")
        if not expected_file.exists():
            counts["unrecorded"] += 1
            found = runs_cleanly(actual)
            if not allow_unrecorded:
                found = ["no expected result is recorded", *found]
        else:
            expected = Result.from_json(json.loads(expected_file.read_text()))
            found = compare(expected, actual)
            if found and name in known:
                counts["known"] += 1
                print(f"{name}: known disagreement, {known[name]}")
                continue
            if not found and name in known:
                found = [f"agrees, but known.json lists it under {known[name]}"]
            if not found:
                counts["agree"] += 1
        if found:
            counts["disagree"] += 1
            problems.extend(f"{name}: {p}" for p in found)
    summary = ", ".join(f"{v} {k}" for k, v in counts.items())
    print(f"{len(progs)} programs: {summary}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        subprocess.run(
            [
                sys.executable,
                "-I",
                str(ROOT / "scripts" / "suite_summary.py"),
                "counts",
                "Conformance suite",
                *(f"{k}={v}" for k, v in counts.items()),
            ],
            check=False,
        )
    for p in problems:
        print(p, file=sys.stderr)
    return 1 if problems else 0


def main(argv: list[str]) -> int:
    if argv and argv[0] == "record":
        return record(argv[1:])
    if argv and argv[0] == "check":
        return check(argv[1:])
    if argv and argv[0] == "levels":
        return levels(argv[1:])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
