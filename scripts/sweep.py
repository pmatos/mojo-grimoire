#!/usr/bin/env python3
"""Runs the probe sweep of tests/sweep/ against two builds of the model, and
counts how a change moves each program against the compiler
(docs/decisions/conformance.md#the-probe-sweep).

Each program `tests/sweep/GROUP/NAME.mojo` has the pinned compiler's result
in `GROUP/NAME.json`, recorded with `scripts/conformance.py record` as the
suite's are. The sweep is run by hand for each part of #96, not as a hook.

Usage:
  scripts/sweep.py --base MODEL --head MODEL [--jobs N] [PROGRAM...]
      Runs both executables of the model, the one built from `main` and the
      one built from the change, on every recorded program of the sweep, or
      on the PROGRAMs given, 8 at a time unless --jobs says, and compares
      each result with the compiler's. It prints how many programs agree on
      both builds, how many the change fixes and how many disagree on both,
      and lists every program that agreed on `main` and no longer does. A
      change of rejection class is allowed under the decision page's rule;
      any other such program fails the sweep with exit 1. Exit 2 means that
      nothing could be compared.
"""

from __future__ import annotations

import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from conformance import (
    ROOT,
    compare,
    jobs_and_programs,
    name_of,
    programs,
    recorded,
    run_model,
)
from conformance_compiler import Result

SWEEP = ROOT / "tests" / "sweep"

KINDS = ("agree", "fixed", "disagree", "class changed", "regressed")
LISTED = ("fixed", "class changed", "regressed")


def agrees(expected: Result, actual: Result) -> bool:
    """Whether a build's result agrees with the compiler's. A rejection whose
    diagnostic has no class yet (#319) agrees with any rejection that prints
    the same lines."""
    if expected.outcome == "rejected" and expected.error_class is None:
        return actual.outcome == "rejected" and actual.stdout == expected.stdout
    return not compare(expected, actual)


def kind(expected: Result, base: Result, head: Result) -> str:
    """How the change moves a program: whether each build agrees with the
    compiler's result, and, for a program that agreed and no longer does,
    whether only the class of its rejection changed."""
    base_agrees, head_agrees = agrees(expected, base), agrees(expected, head)
    if base_agrees and head_agrees:
        return "agree"
    if head_agrees:
        return "fixed"
    if not base_agrees:
        return "disagree"
    if expected.outcome == base.outcome == head.outcome == "rejected":
        return "class changed"
    return "regressed"


def describe(r: Result) -> str:
    """A result in one short line."""
    if r.outcome == "rejected":
        return f"rejected {r.error_class}"
    if r.outcome == "error":
        return f"error {r.detail}"
    return f"{r.outcome} {list(r.stdout)}"


def run(program: Path, model: Path) -> Result:
    """A build's result for a program; a run that times out or cannot start
    is an error, so that it counts against the build that it ran on."""
    try:
        return run_model(program, model)
    except (subprocess.TimeoutExpired, OSError) as e:
        return Result("error", (), None, str(e))


def executable(arg: str) -> Path:
    """The absolute path of an executable named on the command line."""
    path = Path(arg).resolve()
    if not (path.is_file() and os.access(path, os.X_OK)):
        raise ValueError(f"no executable at {arg}")
    return path


def parse_args(args: list[str]) -> tuple[Path, Path, int, list[Path]]:
    """The two executables, the number of jobs and the programs; ValueError
    when an argument is missing or unknown."""
    models: dict[str, Path] = {}
    rest = list(args)
    while rest and rest[0] in ("--base", "--head"):
        if len(rest) < 2:
            raise ValueError(f"{rest[0]} needs an executable")
        models[rest[0]] = executable(rest[1])
        rest = rest[2:]
    if set(models) != {"--base", "--head"}:
        raise ValueError("both --base MODEL and --head MODEL are needed, first")
    jobs, chosen = jobs_and_programs(rest, 8)
    return models["--base"], models["--head"], jobs, chosen


def main(argv: list[str]) -> int:
    try:
        base, head, jobs, chosen = parse_args(argv)
    except ValueError as e:
        print(f"{e}\n{__doc__}", file=sys.stderr)
        return 2
    found, unrecorded = [], []
    for program in chosen or programs(SWEEP):
        expected = recorded(program)
        if expected is None:
            unrecorded.append(name_of(program, SWEEP))
        else:
            found.append((program, expected))
    if not found:
        print("No program with a recorded result was given.", file=sys.stderr)
        return 2

    def one(item: tuple[Path, Result]) -> tuple[str, str]:
        program, expected = item
        b, h = run(program, base), run(program, head)
        k = kind(expected, b, h)
        line = f"{name_of(program, SWEEP)}: compiler {describe(expected)}, "
        return k, line + f"main {describe(b)}, change {describe(h)}"

    by_kind: dict[str, list[str]] = {k: [] for k in KINDS}
    with ThreadPoolExecutor(jobs) as pool:
        for k, line in pool.map(one, found):
            by_kind[k].append(line)
    summary = ", ".join(f"{len(v)} {k}" for k, v in by_kind.items())
    print(f"{len(found)} programs: {summary}")
    if unrecorded:
        print(f"{len(unrecorded)} have no recorded result: {', '.join(unrecorded)}")
    for k in LISTED:
        if by_kind[k]:
            print(f"\n{k}:")
            print("\n".join(f"  {e}" for e in by_kind[k]))
    return 1 if by_kind["regressed"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
