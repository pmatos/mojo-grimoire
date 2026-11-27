"""The conformance suite as the explorer, scripts/explorer.py, shows it: its
programs as examples, each with its recorded result, and the decision-log
entry or ruled compiler bug that names it
(docs/decisions/conformance.md#the-explorer).

A program in the editor is the suite program whose text it is, line ends and
trailing spaces aside; only then do known.json and the record apply to it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

from conformance import (
    COMPILER_BUGS,
    DECISION_LOG,
    SUITE,
    load_known,
    name_of,
    programs,
    recorded,
    ruled_bugs,
)
from conformance_compiler import Result

ENTRY_HEADING = re.compile(r"^### (D-\d{4}): (.*)$")
REPO = "https://github.com/pmatos/mojo-grimoire"


def normalized(source: str) -> str:
    text = source.replace("\r\n", "\n").replace("\r", "\n")
    return "\n".join(line.rstrip() for line in text.split("\n")).strip("\n")


def decision_entries(log: Path = DECISION_LOG) -> dict[str, dict]:
    """The entries of the decision log, by id, with their title and text."""
    entries: dict[str, dict] = {}
    current = None
    for line in log.read_text().splitlines():
        if m := ENTRY_HEADING.match(line):
            current = {"id": m.group(1), "title": m.group(2), "lines": []}
            entries[m.group(1)] = current
        elif line.startswith(("## ", "### ")):
            current = None
        elif current is not None:
            current["lines"].append(line)
    for entry in entries.values():
        entry["text"] = "\n".join(entry.pop("lines")).strip()
        entry["url"] = f"{REPO}/blob/main/docs/conformance/decision-log.md"
    return entries


def compiler_bugs(bugs: Path = COMPILER_BUGS) -> dict[str, dict]:
    """The ruled compiler bugs, by their decision-log id."""
    found = {}
    for bug in json.loads(bugs.read_text())["bugs"]:
        detail_file = bugs.parent / bug.get("entry", "")
        detail = json.loads(detail_file.read_text()) if detail_file.is_file() else {}
        found[bug["decision_log"]] = {
            "title": bug.get("title"),
            "issue": bug.get("issue"),
            "compiler": detail.get("compiler"),
            "fixed": detail.get("fixed"),
            "model": detail.get("model"),
            "confirmation": (detail.get("confirmation") or {}).get("status"),
            "upstream": (detail.get("upstream") or {}).get("status"),
            "programs": bug.get("suite_programs", []),
        }
    return found


@dataclass
class Example:
    name: str
    path: Path
    expected: Result | None
    known: str | None
    ruled: str | None

    def summary(self) -> dict:
        e = self.expected
        return {
            "name": self.name,
            "outcome": e.outcome if e else None,
            "class": e.error_class if e else None,
            "known": self.known,
            "entry": self.known or self.ruled,
        }


class Suite:
    """The suite's programs, read once when the explorer starts."""

    def __init__(self, root: Path = SUITE) -> None:
        known = load_known(root / "known.json")
        ruled = ruled_bugs(known=root / "known.json")
        self.examples: dict[str, Example] = {}
        self.by_text: dict[str, str] = {}
        for program in programs(root):
            name = name_of(program, root)
            example = Example(
                name, program, recorded(program), known.get(name), ruled.get(name)
            )
            self.examples[name] = example
            self.by_text.setdefault(normalized(program.read_text()), name)
        self.entries = decision_entries()
        self.bugs = compiler_bugs()

    def listing(self) -> list[dict]:
        return [e.summary() for e in self.examples.values()]

    def match(self, source: str) -> Example | None:
        name = self.by_text.get(normalized(source))
        return self.examples.get(name) if name else None

    def entry(self, entry_id: str) -> dict | None:
        found = self.entries.get(entry_id)
        if found is None:
            return None
        return {**found, "bug": self.bugs.get(entry_id)}

    def describe(self, example: Example) -> dict:
        data = example.summary()
        data["recorded"] = example.expected.to_json() if example.expected else None
        if data["entry"]:
            data["entryInfo"] = self.entry(data["entry"])
        return data
