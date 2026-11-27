"""How the explorer, scripts/explorer.py, runs one program on the compiler and
on the model (docs/decisions/conformance.md#the-explorer).

The suite's own runners, `conformance_compiler.run_compiler` and
`conformance.run_model`, return only a `Result`, and read a program's whole
output with no limit. The explorer runs arbitrary programs, and shows more
than the `Result`: exit codes, timings, and where the compiler's error lies.
So it starts the processes itself, each in a fresh temporary directory, with a
timeout and a cap on its output, and builds the `Result` with the suite's
own helpers, branch for branch as `run_compiler` and `run_model` do; the
tests check that the two give the same `Result`. The verdict is the suite's
`compare`, with `known.json` read as `scripts/conformance.py check` reads it.
"""

from __future__ import annotations

import os
import re
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from conformance import compare, model_result
from conformance_compiler import (
    ERROR_LINE,
    LEVELS,
    Result,
    classify,
    failed_output,
    first_error,
    level_differences,
    lines,
)
from explorer_proc import Proc, rlimits, run_capped

PROGRAM = "program.mojo"
SWEEP_LEVELS = ("-O0", "-O1", "-O2", "-O3", "ASSERT=all")


@dataclass(frozen=True)
class Limits:
    """How long each step may take, in seconds, how many bytes each of its
    two output streams may hold, and the resource limits of each child:
    its address space and file size in bytes, and how many tasks it may
    add to the user's."""

    build: float = 300.0
    run: float = 30.0
    model: float = 60.0
    output: int = 1 << 20
    memory: int = 16 << 30
    fsize: int = 1 << 30
    tasks: int = 512

    def of(self, timeout: float) -> dict[str, int]:
        return rlimits(timeout, self.memory, self.fsize, self.tasks)


def _run(argv: list[str], cwd: Path, timeout: float, limits: Limits) -> Proc:
    return run_capped(argv, cwd, timeout, limits.output, limits.of(timeout))


def _stopped(proc: Proc, step: str, cmd: str, limits: Limits) -> Result | None:
    """The "error" of a step that timed out or printed too much."""
    if proc.timed_out:
        return Result("error", (), None, f"timed out: {cmd} ({step})")
    if proc.overflowed:
        return Result(
            "error", (), None, f"{step} printed more than {limits.output} bytes"
        )
    return None


# --- the compiler ---------------------------------------------------------

LOCATED = re.compile(r"^(.*?):(\d+):(\d+): (error|warning|note): (.*)$")


def diagnostics(stderr: str, program: Path) -> list[dict]:
    """The compiler's messages located in the program, in order; `primary`
    marks the one whose error `first_error` reports."""
    found, first = [], True
    for line in stderr.splitlines():
        is_error = ERROR_LINE.search(line) is not None
        m = LOCATED.match(line)
        if m and m.group(1) == str(program):
            found.append(
                {
                    "line": int(m.group(2)),
                    "column": int(m.group(3)),
                    "severity": m.group(4),
                    "message": m.group(5).strip(),
                    "primary": is_error and first,
                }
            )
        if is_error:
            first = False
    return found


def _shown(text: str, tmp: Path) -> str:
    return text.replace(str(tmp) + os.sep, "")


def compiler_result(
    build: Proc, run: Proc | None, patterns: list[tuple[str, str]]
) -> Result:
    """The Result that `run_compiler` gives for a build and, when the build
    succeeded, a run that ended by themselves."""
    if build.code != 0:
        if not ERROR_LINE.search(build.stderr):
            tail = build.stderr.strip()[-200:]
            return Result("error", (), None, f"build exit {build.code}: {tail}")
        message = first_error(build.stderr)
        return Result("rejected", (), classify(message, patterns), message)
    assert run is not None
    if run.code == 0:
        return Result("finished", lines(run.stdout))
    printed, assertion = failed_output(run.stdout)
    detail = assertion or first_error(run.stderr) or f"exit {run.code}"
    return Result("failed", printed, None, detail)


def run_on_compiler(
    source: str, mojo: str, patterns, flags: tuple[str, ...], limits: Limits
) -> dict:
    """Builds and runs `source` with the compiler, as `build_at` does."""
    report: dict = {"flags": list(flags), "build": None, "run": None}
    with tempfile.TemporaryDirectory(prefix="mojo-explorer-") as name:
        tmp = Path(name)
        program, binary = tmp / PROGRAM, tmp / "program"
        program.write_text(source)
        try:
            build = _run(
                [mojo, "build", *flags, str(program), "-o", str(binary)],
                tmp,
                limits.build,
                limits,
            )
            report["build"] = _step(build, tmp)
            report["diagnostics"] = diagnostics(build.stderr, program)
            result = _stopped(build, "the build", mojo, limits)
            run = None
            if result is None and build.code == 0:
                run = _run([str(binary)], tmp, limits.run, limits)
                report["run"] = _step(run, tmp)
                result = _stopped(run, "the program", str(binary), limits)
            if result is None:
                result = compiler_result(build, run, patterns)
        except OSError as e:
            result = Result("error", (), None, f"cannot run: {e}")
        report["result"] = _result_json(result, tmp)
    report["_result"] = result
    return report


def _step(proc: Proc, tmp: Path) -> dict:
    return {
        "exit": proc.code,
        "seconds": round(proc.seconds, 3),
        "stdout": _shown(proc.stdout, tmp),
        "stderr": _shown(proc.stderr, tmp),
        "timed_out": proc.timed_out,
        "overflowed": proc.overflowed,
    }


def _result_json(result: Result, tmp: Path | None = None) -> dict:
    data = result.to_json()
    if tmp is not None and data["diagnostic"]:
        data["diagnostic"] = _shown(data["diagnostic"], tmp)
    return data


# --- the model ------------------------------------------------------------

POSITIONED = re.compile(r"^(syntax error|outside the subset): line (\d+): (.*)$")
REJECTED_IN = re.compile(r"^rejected: (\w+) in (\S+)$", re.MULTILINE)


def run_on_model(source: str, model: Path, fuel: int | None, limits: Limits) -> dict:
    """Runs `source` with the model's executable, as `run_model` does."""
    with tempfile.TemporaryDirectory(prefix="mojo-explorer-") as name:
        tmp = Path(name)
        program = tmp / PROGRAM
        program.write_text(source)
        argv = [str(model), str(program)]
        if fuel is not None:
            argv += ["--fuel", str(fuel)]
        try:
            proc = _run(argv, tmp, limits.model, limits)
        except OSError as e:
            proc = None
            result = Result("error", (), None, f"cannot run: {e}")
        report: dict = {"step": None, "position": None, "decl": None}
        if proc is not None:
            report["step"] = _step(proc, tmp)
            result = _stopped(proc, "the model", str(model), limits)
            if result is None:
                result = model_result(proc.code, proc.stdout, proc.stderr)
            report.update(_model_position(proc.stderr))
    report["result"] = _result_json(result)
    report["_result"] = result
    return report


def _model_position(stderr: str) -> dict:
    """The line that a syntax error or an "outside the subset" names, and
    the declaration that a rejection names."""
    found: dict = {}
    for line in stderr.splitlines():
        if m := POSITIONED.match(line.strip()):
            found["position"] = {
                "kind": m.group(1),
                "line": int(m.group(2)),
                "message": m.group(3),
            }
            break
    if m := REJECTED_IN.search(stderr):
        found["decl"] = m.group(2)
    return found


# --- the verdict ----------------------------------------------------------


def verdict(expected: Result, actual: Result, known_entry: str | None) -> dict:
    """Whether the model agrees with the compiler, by the suite's `compare`
    and, for a suite program that known.json lists, as `check` decides."""
    if expected.outcome == "error":
        return {
            "state": "no-verdict",
            "problems": [f"the compiler gave no result: {expected.detail}"],
        }
    found = compare(expected, actual)
    if found and known_entry:
        return {"state": "known", "entry": known_entry, "problems": found}
    if not found and known_entry:
        problem = f"agrees, but known.json lists it under {known_entry}"
        return {"state": "disagree", "entry": known_entry, "problems": [problem]}
    return {"state": "disagree" if found else "agree", "problems": found}


def level_flags(level: str) -> tuple[str, ...]:
    """The flags of a level of the selector: none for the default build,
    as `record` builds, or those that `levels` uses."""
    if level == "default":
        return ()
    if level not in LEVELS:
        raise ValueError(f"unknown level {level!r}")
    return LEVELS[level]


def sweep_levels(compile_at, jobs: int, model: Result) -> list[dict]:
    """The compiler's result at each level, how it differs from -O3's by
    `level_differences`, as `scripts/conformance.py levels` compares them,
    and the model's verdict against each. `compile_at(flags)` gives the
    report of `run_on_compiler` for the program."""

    def at(level: str) -> dict:
        return compile_at(LEVELS[level])

    with ThreadPoolExecutor(max(1, jobs)) as pool:
        reports = dict(zip(SWEEP_LEVELS, pool.map(at, SWEEP_LEVELS), strict=True))
    reference = reports["-O3"]["_result"]
    rows = []
    for level, report in reports.items():
        result = report["_result"]
        broken = "error" in (reference.outcome, result.outcome)
        differences = (
            []
            if broken or level == "-O3"
            else level_differences(reference, result, level)
        )
        rows.append(
            {
                "level": level,
                "compiler": _public(report),
                "differs": bool(differences),
                "differences": differences,
                "verdict": verdict(result, model, None),
            }
        )
    return rows


def _public(report: dict) -> dict:
    return {k: v for k, v in report.items() if not k.startswith("_")}
