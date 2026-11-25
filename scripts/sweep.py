#!/usr/bin/env python3
"""Runs the probe sweep of tests/sweep/ against two builds of the model, and
counts how a change moves each program against the compiler
(docs/decisions/conformance.md#the-probe-sweep).

Each program `tests/sweep/GROUP/NAME.mojo` has the pinned compiler's result
in `GROUP/NAME.json`, recorded with `scripts/conformance.py record` as the
suite's are. The sweep is run by hand for each part of #96, not as a hook:
the human ruled so on 2026-11-22 (#96, Q8).

Usage:
  scripts/sweep.py --base MODEL --head MODEL [--jobs N] [PROGRAM...]
      Runs both executables of the model, the one built from `main` and the
      one built from the change, on every recorded program of the sweep, or
      on the PROGRAMs given, 8 at a time unless --jobs says, and compares
      each result with the compiler's. It prints how many programs agree on
      both, how many the change fixes, how many disagree on both, and lists
      every program that agreed on `main` and disagrees on the change. Such
      a program is a change of rejection class when the compiler and both
      builds reject it, which a part of #96 may make if its PR lists it with
      the open issue that tracks the wrong rejection (process.md). Any other
      such program, such as a run that becomes a rejection, fails the sweep.
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from conformance import ROOT, compare, name_of, run_model
from conformance_compiler import Result

SWEEP = ROOT / "tests" / "sweep"

KINDS = ("agree", "fixed", "disagree", "class changed", "regressed")


def kind(expected: Result, base: Result, head: Result) -> str:
    """How the change moves a program: whether each build agrees with the
    compiler's result, and, for a program that agreed and no longer does,
    whether only the class of its rejection changed."""
    base_agrees, head_agrees = not compare(expected, base), not compare(expected, head)
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
    return f"{r.outcome} {list(r.stdout)}"


def parse_args(args: list[str]) -> tuple[Path, Path, int, list[Path]]:
    """The two executables, the number of jobs and the programs; ValueError
    when an argument is missing or unknown."""
    base = head = None
    jobs, chosen, rest = 8, [], list(args)
    while rest:
        arg = rest.pop(0)
        if arg in ("--base", "--head") and rest:
            path = Path(rest.pop(0))
            if not path.is_file():
                raise ValueError(f"no executable at {path}")
            base, head = (path, head) if arg == "--base" else (base, path)
        elif arg == "--jobs" and rest and rest[0].isdigit():
            jobs = max(1, int(rest.pop(0)))
        elif arg.endswith(".mojo") and Path(arg).is_file():
            chosen.append(Path(arg).resolve())
        else:
            raise ValueError(f"neither a program nor an option: {arg}")
    if base is None or head is None:
        raise ValueError("both --base MODEL and --head MODEL are needed")
    return base, head, jobs, chosen


def main(argv: list[str]) -> int:
    try:
        base, head, jobs, chosen = parse_args(argv)
    except ValueError as e:
        print(f"{e}\n{__doc__}", file=sys.stderr)
        return 2
    targets = chosen or sorted(SWEEP.rglob("*.mojo"))
    recorded = [p for p in targets if p.with_suffix(".json").exists()]
    unrecorded = [name_of(p, SWEEP) for p in targets if p not in recorded]

    def one(program: Path) -> tuple[str, Result, Result, Result]:
        expected = Result.from_json(
            json.loads(program.with_suffix(".json").read_text())
        )
        return (
            name_of(program, SWEEP),
            expected,
            run_model(program, base),
            run_model(program, head),
        )

    with ThreadPoolExecutor(jobs) as pool:
        found = list(pool.map(one, recorded))
    counts: dict[str, int] = dict.fromkeys(KINDS, 0)
    listed: dict[str, list[str]] = {
        k: [] for k in ("fixed", "class changed", "regressed")
    }
    for name, expected, b, h in found:
        k = kind(expected, b, h)
        counts[k] += 1
        if k in listed:
            listed[k].append(
                f"{name}: compiler {describe(expected)}, main {describe(b)}, change {describe(h)}"
            )
    summary = ", ".join(f"{v} {k}" for k, v in counts.items())
    print(f"{len(recorded)} programs: {summary}")
    if unrecorded:
        print(
            f"{len(unrecorded)} programs have no recorded result: {', '.join(unrecorded)}"
        )
    for k, entries in listed.items():
        if entries:
            print(f"\n{k}:")
            print("\n".join(f"  {e}" for e in entries))
    if listed["class changed"]:
        print(
            "\nEach change of class needs the open issue of its wrong rejection in the PR body."
        )
    return 1 if listed["regressed"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
