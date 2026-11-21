"""The reference compiler's side of the conformance runner,
scripts/conformance.py: how a run of a program ended, and the compiler's
result for a program, built at the default level or another one, with the
comparison of two levels (docs/decisions/conformance.md#optimization-levels).
"""

from __future__ import annotations

import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

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


def lines(text: str) -> tuple[str, ...]:
    """The lines of a program's standard output."""
    return tuple(text.splitlines())


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


def run_compiler(
    program: Path,
    mojo: str,
    patterns: list[tuple[str, str]],
    flags: tuple[str, ...] = (),
) -> Result:
    """The compiler's result for a program, built with the default -O3, or
    with `flags`, such as another optimization level. A build that fails
    with no error from the compiler, such as a crash or a wrapper that
    cannot run, is an "error", never a rejection."""
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
            if not ERROR_LINE.search(build.stderr):
                tail = build.stderr.strip()[-200:]
                return Result(
                    "error", (), None, f"build exit {build.returncode}: {tail}"
                )
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


def build_at(program: Path, mojo: str, patterns, flags: tuple[str, ...]) -> Result:
    """The compiler's result with `flags`; a build or run that times out,
    or a wrapper that cannot start, is an "error" too."""
    try:
        return run_compiler(program, mojo, patterns, flags)
    except subprocess.TimeoutExpired as e:
        return Result("error", (), None, f"timed out: {e.cmd[0]}")
    except OSError as e:
        return Result("error", (), None, f"cannot run: {e}")


def across_levels(program: Path, mojo: str, patterns) -> tuple[list[str], list[str]]:
    """The levels of LEVELS at which the program could not be compared,
    because its build or run ended in an "error", and how its result
    differs between the levels that could."""
    results = {lv: build_at(program, mojo, patterns, LEVELS[lv]) for lv in LEVELS}
    broken = [f"{lv}: {r.detail}" for lv, r in results.items() if r.outcome == "error"]
    reference = results["-O3"]
    differences = [
        f"{level}: {p}"
        for level, result in results.items()
        if level != "-O3" and "error" not in (reference.outcome, result.outcome)
        for p in level_differences(reference, result, level)
    ]
    return broken, differences


SMOKE = 'def main():\n    print("ok")\n'


def wrapper_problem(mojo: str) -> str | None:
    """Why the compiler cannot build and run a trivial program, if it
    cannot; a sweep or recording with a broken wrapper compares nothing."""
    with tempfile.TemporaryDirectory() as tmp:
        program = Path(tmp) / "smoke.mojo"
        program.write_text(SMOKE)
        result = build_at(program, mojo, [], ())
    if result == Result("finished", ("ok",)):
        return None
    return f"{mojo} does not build and run a trivial program: {result}"
