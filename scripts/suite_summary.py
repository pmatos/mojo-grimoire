"""Writes a test suite's counts to the GitHub job summary and to the log
(ADR-2026-11-15-1903).

The scripts of the test hooks call it only when GITHUB_STEP_SUMMARY is set,
as it is in a step of a GitHub Actions job, so that a hook run locally
behaves as before. It appends a Markdown table to the file that
GITHUB_STEP_SUMMARY names, and prints the same counts on standard output,
which CI's `pre-commit run --verbose` shows in the log.

Usage: python3 -I scripts/suite_summary.py COMMAND ARGS...
  lean DIR                  the checks that building the Lean package in
                            DIR ran, by library
  counts TITLE NAME=VALUE...
                            one row of counts that a script worked out
"""

import os
import re
import sys
from pathlib import Path

# Lean commands counted at the start of a line, once comments and string
# and character literals are gone.
LEAN_CHECKS = {
    "#guard": re.compile(r"^[ \t]*#guard(?!\w)", re.MULTILINE),
    "#guard_msgs": re.compile(r"^[ \t]*#guard_msgs\b", re.MULTILINE),
    "theorems": re.compile(
        r"^[ \t]*(?:@\[[^\]\n]*\]\s*)?(?:(?:private|protected)\s+)?theorem\b",
        re.MULTILINE,
    ),
    "examples": re.compile(r"^[ \t]*(?:@\[[^\]\n]*\]\s*)?example\b", re.MULTILINE),
}


def number(value) -> str:
    return f"{value:,}" if isinstance(value, int) else str(value)


def write(
    title: str, header: list[str], rows: list[list], note: str = "", labelled=False
) -> None:
    """Appends a table to the job summary and prints it as text. When
    `labelled`, each row's first cell names it."""
    lines = [f"### {title}", ""]
    lines.append("| " + " | ".join(h[:1].upper() + h[1:] for h in header) + " |")
    aligns = [":--" if labelled and i == 0 else "--:" for i in range(len(header))]
    lines.append("| " + " | ".join(aligns) + " |")
    lines += ["| " + " | ".join(number(v) for v in row) + " |" for row in rows]
    if note:
        lines += ["", note]
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n\n")
    for row in rows:
        cells = list(zip(header, row))
        label = f"{cells.pop(0)[1]}: " if labelled else ""
        print(f"{title}: {label}" + ", ".join(f"{number(v)} {h}" for h, v in cells))
    if note:
        print(f"{title}: {note}")


def strip_lean(src: str) -> str:
    """`src` with its comments and its string and character literals blanked
    out, keeping the line breaks so that each line stays at its start."""
    out, i, n, depth = [], 0, len(src), 0
    while i < n:
        if src.startswith("/-", i):
            depth, i = depth + 1, i + 2
        elif depth and src.startswith("-/", i):
            depth, i = depth - 1, i + 2
        elif depth:
            out.append("\n" if src[i] == "\n" else "")
            i += 1
        elif src.startswith("--", i):
            i = n if (j := src.find("\n", i)) < 0 else j
        elif src[i] == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append("\n" * src.count("\n", i, j + 1))
            i = j + 1
        elif src[i] == "'" and (m := re.match(r"'(?:\\[^'\n]+|[^'\\\n])'", src[i:])):
            prev = src[i - 1] if i else " "
            if prev.isalnum() or prev in "_'.!?":
                out.append("'")
                i += 1
            else:
                i += m.end()
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def lean_counts(root: Path) -> list[list]:
    """For each library of the Lean package in `root`, the number of each
    command of LEAN_CHECKS in its modules: a root file X.lean and the files
    under X/. Hidden directories, such as Lake's .lake, are left out."""
    libraries: dict[str, list[int]] = {}
    for path in sorted(root.rglob("*.lean")):
        parts = path.relative_to(root).parts
        if path.name == "lakefile.lean" or any(p.startswith(".") for p in parts):
            continue
        name = parts[0] if len(parts) > 1 else path.stem
        text = strip_lean(path.read_text(encoding="utf-8"))
        counts = libraries.setdefault(name, [0] * len(LEAN_CHECKS))
        for k, pattern in enumerate(LEAN_CHECKS.values()):
            counts[k] += len(pattern.findall(text))
    return [[name, *counts] for name, counts in sorted(libraries.items())]


def exited(what: str, status: str) -> str:
    return "" if status == "0" else f"{what} exited with status {status}."


def main(argv: list[str]) -> int:
    command, args = (argv[0], argv[1:]) if argv else ("", [])
    if command == "lean" and len(args) == 1:
        header = ["library", *LEAN_CHECKS]
        rows = lean_counts(Path(args[0]))
        write("Lean checks that building lean/ ran", header, rows, labelled=True)
        return 0
    if command == "counts" and len(args) >= 2 and all("=" in a for a in args[1:]):
        cells = [a.split("=", 1) for a in args[1:]]
        values = [int(v) if v.isdigit() else v for _, v in cells]
        write(args[0], [h for h, _ in cells], [values])
        return 0
    print(__doc__.split("\n\n")[2], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
