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
      default -O3 build's, unless a ruled compiler bug names it: known.json,
      or a bug's suite_programs in docs/conformance/compiler-bugs.json,
      lists it under an entry of the decision log. The recorded result is
      the default build's.
  scripts/conformance.py levels --mojo WRAPPER [--jobs N] [PROGRAM...]
      Builds each program, or the whole suite, at -O0, -O1, -O2 and -O3 and
      with -D ASSERT=all, 4 programs at a time unless --jobs says, and
      lists every program whose result differs between them. It fails when
      a program that no ruled compiler bug names differs. Run it whenever
      the pinned compiler moves.
  Both first check that the wrapper builds and runs a trivial program, and
  that each PROGRAM is a file; a build that fails with no error from the
  compiler, or that times out, is never recorded and fails the sweep.
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
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from conformance_compiler import (
    LEVELS,
    TIMEOUT,
    Result,
    across_levels,
    build_at,
    level_differences,
    lines,
    wrapper_problem,
)

ROOT = Path(__file__).resolve().parent.parent
SUITE = ROOT / "tests" / "conformance"
MODEL = ROOT / "lean" / ".lake" / "build" / "bin" / "mojo-grimoire"
DECISION_LOG = ROOT / "docs" / "conformance" / "decision-log.md"
COMPILER_BUGS = ROOT / "docs" / "conformance" / "compiler-bugs.json"


def programs(root: Path = SUITE) -> list[Path]:
    """The suite's programs, sorted."""
    return sorted(root.rglob("*.mojo"))


def name_of(program: Path, root: Path = SUITE) -> str:
    """A program's name: its path in the suite, without `.mojo`, or its own
    path when it is outside the suite."""
    if program.is_relative_to(root):
        return program.relative_to(root).with_suffix("").as_posix()
    return program.with_suffix("").as_posix()


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


def load_patterns(path: Path = SUITE / "diagnostics.json") -> list[tuple[str, str]]:
    data = json.loads(path.read_text())
    return [(entry["pattern"], entry["class"]) for entry in data["patterns"]]


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


def ruled_bugs(
    known: Path = SUITE / "known.json",
    bugs: Path = COMPILER_BUGS,
    log: Path = DECISION_LOG,
) -> dict[str, str]:
    """The programs that a ruled compiler bug names, with its entry: those
    that known.json lists, or that a bug of compiler-bugs.json lists in
    its suite_programs, under an entry of the decision log. A bug that
    shows only below -O3 names its programs in compiler-bugs.json alone,
    since the model agrees with their recorded result."""
    text = log.read_text()
    named = list(load_known(known).items()) + [
        (name, bug.get("decision_log", ""))
        for bug in json.loads(bugs.read_text())["bugs"]
        for name in bug.get("suite_programs", [])
    ]
    return {name: entry for name, entry in named if is_entry(entry, text)}


# --- commands -------------------------------------------------------------


def compiler_args(args: list[str], jobs_ok: bool) -> tuple[str, int, list[Path]]:
    """The wrapper, the number of jobs and the programs that `record` or
    `levels` is given; ValueError when an argument is neither."""
    if len(args) < 2 or args[0] != "--mojo":
        raise ValueError("no --mojo WRAPPER")
    mojo, rest, jobs, chosen = args[1], args[2:], 4, []
    while rest:
        arg = rest.pop(0)
        if jobs_ok and arg == "--jobs" and rest and rest[0].isdigit():
            jobs = max(1, int(rest.pop(0)))
        elif arg.endswith(".mojo") and Path(arg).is_file():
            chosen.append(Path(arg).resolve())
        else:
            raise ValueError(f"neither a program nor an option: {arg}")
    return mojo, jobs, chosen


def with_compiler(command, args: list[str], ruled, jobs_ok: bool) -> int:
    """Runs `record` or `levels` once its arguments and the wrapper are
    sound: a sweep or recording that compares nothing must not pass."""
    try:
        mojo, jobs, chosen = compiler_args(args, jobs_ok)
    except ValueError as e:
        print(f"{e}\n{__doc__}", file=sys.stderr)
        return 2
    if why := wrapper_problem(mojo):
        print(why, file=sys.stderr)
        return 2
    ruled = ruled_bugs() if ruled is None else ruled
    return command(mojo, jobs, chosen or programs(), ruled, load_patterns())


def record(args: list[str], ruled: dict[str, str] | None = None) -> int:
    return with_compiler(recording, args, ruled, jobs_ok=False)


def recording(mojo, _jobs, targets, ruled, patterns) -> int:
    unclassified, refused = [], []
    for program in targets:
        name = name_of(program)
        result = build_at(program, mojo, patterns, ())
        at_o0 = build_at(program, mojo, patterns, LEVELS["-O0"])
        pairs = (("-O3", result), ("-O0", at_o0))
        broken = [f"{lv}: {r.detail}" for lv, r in pairs if r.outcome == "error"]
        found = broken or level_differences(result, at_o0, "-O0")
        if broken or (found and name not in ruled):
            refused.extend(f"{name}: {p}" for p in found)
            print(f"{name}: not recorded")
            continue
        if found:
            print(f"{name}: differs at -O0, a compiler bug ruled in {ruled[name]}")
        out = program.with_suffix(".json")
        out.write_text(json.dumps(result.to_json(), indent=2) + "\n")
        print(f"{name}: {result.outcome}", result.error_class or "")
        if result.outcome == "rejected" and result.error_class is None:
            unclassified.append(f"{name}: {result.detail}")
    if unclassified:
        print("\nDiagnostics with no class; add a pattern to diagnostics.json:")
        print("\n".join(unclassified))
    if refused:
        print(
            "\nNot recorded: a build failed with no compiler error, or the result "
            "differs at -O0 and no ruled compiler bug names the program:",
            file=sys.stderr,
        )
        print("\n".join(refused), file=sys.stderr)
    return 1 if refused else 0


def levels(args: list[str], ruled: dict[str, str] | None = None) -> int:
    return with_compiler(sweep, args, ruled, jobs_ok=True)


def sweep(mojo, jobs, targets, ruled, patterns) -> int:
    with ThreadPoolExecutor(jobs) as pool:
        found = list(pool.map(lambda p: across_levels(p, mojo, patterns), targets))
    counts = {"the same": 0, "differ by a ruled compiler bug": 0, "differ": 0}
    counts["could not be built"] = 0
    problems = []
    for program, (broken, differences) in zip(targets, found, strict=True):
        name = name_of(program)
        if broken:
            counts["could not be built"] += 1
            problems.extend(f"{name}: {d}" for d in broken + differences)
        elif not differences:
            counts["the same"] += 1
        elif name in ruled:
            counts["differ by a ruled compiler bug"] += 1
            print(
                f"{name}: differs between levels, a compiler bug ruled in {ruled[name]}"
            )
            print("\n".join(f"  {d}" for d in differences))
        else:
            counts["differ"] += 1
            problems.extend(f"{name}: {d}" for d in differences)
    summary = ", ".join(f"{v} {k}" for k, v in counts.items())
    print(f"{len(targets)} programs at {', '.join(LEVELS)}: {summary}")
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
