"""The explorer's index of the rendered spec, docs/spec/_out/html-multi
(docs/decisions/conformance.md#the-explorer).

Verso gives every Lean declaration that the spec shows an anchor whose `id`
is its full name with each `.` written `___`, and the element that carries
it names the hover text of `-verso-docs.json`: the declaration's signature
and docstring. The index is built by scanning the HTML when the explorer
starts; no anchor is written by hand. The token map, scripts/explorer-ui/
tokens.json, names the declarations that a token of the editor links to,
and each name is checked against the index.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

PREFIX = "MojoGrimoire"
ANCHOR = re.compile(r"<[a-zA-Z][^>]*?\sid=\"(" + PREFIX + r"___[A-Za-z0-9_']+)\"[^>]*>")
HOVER = re.compile(r"data-verso-hover=\"(\d+)\"")
TITLE = re.compile(r"<title>(.*?)</title>", re.DOTALL)
COMMIT = re.compile(r"Built from commit\s*(?:<[^>]*>\s*)*([0-9a-f]{7,40}(?:-dirty)?)")
CHECK_ERROR = "MojoGrimoire.Check.CheckError"
RUN_ERROR = "MojoGrimoire.Interp.RunError"


def name_of_anchor(anchor: str) -> str:
    return anchor.replace("___", ".")


def anchor_of(name: str) -> str:
    return name.replace(".", "___")


class _Text(HTMLParser):
    """The text of a hover's HTML: its signature, the first <code> outside
    the docstring, and its docstring, a `div` or `code` of that class, with
    its inline code between backticks."""

    def __init__(self) -> None:
        super().__init__()
        self.sig: list[str] = []
        self.doc: list[str] = []
        self._in_sig = False
        self._sig_done = False
        self._doc_depth = 0

    def handle_starttag(self, tag, attrs):
        if self._doc_depth:
            self._doc_depth += 1
            if tag == "code":
                self.doc.append("`")
        elif "docstring" in (dict(attrs).get("class") or "").split():
            self._doc_depth = 1
        elif tag == "code" and not self._sig_done:
            self._in_sig = True

    def handle_endtag(self, tag):
        if self._doc_depth:
            self._doc_depth -= 1
            if tag == "code" and self._doc_depth:
                self.doc.append("`")
            elif tag == "p":
                self.doc.append("\n")
        elif tag == "code" and self._in_sig:
            self._in_sig, self._sig_done = False, True

    def handle_data(self, data):
        if self._doc_depth:
            self.doc.append(data)
        elif self._in_sig:
            self.sig.append(data)


def hover_text(html: str) -> tuple[str, str]:
    """The signature and the docstring of a hover, as plain text."""
    parser = _Text()
    parser.feed(html)
    parser.close()
    doc = re.sub(r"[ \t]*\n[ \t]*", " ", "".join(parser.doc)).strip()
    return "".join(parser.sig).strip(), doc


@dataclass
class Decl:
    name: str
    page: str
    title: str
    sig: str = ""
    doc: str = ""

    def url(self) -> str:
        return f"/spec/{self.page}#{anchor_of(self.name)}"

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "url": self.url(),
            "title": self.title,
            "sig": self.sig,
            "doc": self.doc,
        }


@dataclass
class SpecIndex:
    root: Path | None
    decls: dict[str, Decl] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)
    commit: str | None = None

    def get(self, name: str) -> Decl | None:
        return self.decls.get(name)


def _page_of(html_file: Path, root: Path) -> str:
    rel = html_file.relative_to(root)
    if rel.name == "index.html":
        parent = rel.parent.as_posix()
        return "" if parent == "." else parent + "/"
    return rel.as_posix()


def build_index(root: Path | None) -> SpecIndex:
    """The declarations of the rendered spec under `root`; with a warning,
    and no declaration, when it is not there."""
    index = SpecIndex(root)
    if root is None or not (root / "index.html").is_file():
        index.root = None
        index.warnings.append(
            f"no rendered spec at {root}; run scripts/build-spec.sh, "
            "or pass --spec DIR; the editor will have no links"
        )
        return index
    docs_file = root / "-verso-docs.json"
    hovers = json.loads(docs_file.read_text()) if docs_file.is_file() else {}
    seen_on: dict[str, str] = {}
    for html_file in sorted(root.rglob("*.html")):
        text = html_file.read_text(errors="replace")
        page = _page_of(html_file, root)
        title_m = TITLE.search(text)
        title = re.sub(r"\s+", " ", title_m.group(1)).strip() if title_m else page
        for m in ANCHOR.finditer(text):
            name = name_of_anchor(m.group(1))
            if name in seen_on:
                if seen_on[name] != page:
                    index.warnings.append(
                        f"{name} has an anchor on {seen_on[name]} and on {page}"
                    )
                continue
            seen_on[name] = page
            decl = Decl(name, page, title)
            if (h := HOVER.search(m.group(0))) and h.group(1) in hovers:
                decl.sig, decl.doc = hover_text(hovers[h.group(1)])
            index.decls[name] = decl
    front = (root / "index.html").read_text(errors="replace")
    if c := COMMIT.search(front):
        index.commit = c.group(1)
    return index


def load_tokens(path: Path) -> dict[str, dict]:
    """The token map: each token's kind and the declarations it names."""
    data = json.loads(path.read_text())
    return data["tokens"]


def check_tokens(tokens: dict[str, dict], index: SpecIndex) -> list[str]:
    """A warning for each declaration of the token map that the spec has
    no anchor for; none when there is no spec, which build_index warns of."""
    if index.root is None:
        return []
    return [
        f"tokens.json: {token!r} names {name}, which has no anchor in the spec"
        for token, entry in sorted(tokens.items())
        for name in entry["decls"]
        if index.get(name) is None
    ]


def spec_payload(tokens: dict[str, dict], index: SpecIndex) -> dict:
    """What the page needs to link tokens and error classes."""

    def card(d: Decl) -> dict:
        data = d.to_json()
        parent = index.get(d.name.rsplit(".", 1)[0])
        if not d.doc and parent is not None and parent.doc:
            data["parent"] = {"name": parent.name, "doc": parent.doc}
        return data

    linked = {}
    for token, entry in tokens.items():
        decls = [card(d) for n in entry["decls"] if (d := index.get(n))]
        linked[token] = {"kind": entry["kind"], "decls": decls}
    classes = {
        n.rsplit(".", 1)[1]: card(d)
        for n, d in index.decls.items()
        if n.startswith(CHECK_ERROR + ".") and n.count(".") == 3
    }
    run_errors = {
        n.rsplit(".", 1)[1]: card(d)
        for n, d in index.decls.items()
        if n.startswith(RUN_ERROR + ".") and n.count(".") == 3
    }
    return {
        "available": index.root is not None,
        "commit": index.commit,
        "tokens": linked,
        "classes": classes,
        "runErrors": run_errors,
    }
