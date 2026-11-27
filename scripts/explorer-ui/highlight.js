// The explorer's Mojo highlighter: it splits each line into tokens, gives
// each the key that the token map (tokens.json) knows it by, and renders the
// lines with the markers of the last run. Comments and strings are single
// tokens, so nothing inside them is linked.
"use strict";

const Highlight = (() => {
  const OPERATORS = ["->", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=",
    "(", ")", "[", "]", ",", ":", ".", "=", "+", "-", "*", "%", "<", ">",
    "^", "&", "|", "~", "/", "{", "}", ";"];
  const KEYWORDS = new Set(["def", "fn", "struct", "var", "ref", "if", "elif",
    "else", "while", "for", "in", "break", "continue", "return", "pass",
    "raises", "and", "or", "not", "is", "comptime", "alias", "trait", "with",
    "import", "from", "as", "assert", "raise", "try", "except", "finally",
    "self", "Self"]);
  const CONVENTIONS = new Set(["mut", "imm", "out", "deinit", "owned", "read"]);
  const METHODS = new Set(["copy", "append", "pop"]);
  // A token after one of these starts an operand, so `-` is unary and `[`
  // opens a list literal.
  const OPERAND_START = new Set(["(", "[", ",", ":", "=", "==", "!=", "<",
    "<=", ">", ">=", "+", "-", "*", "//", "%", "+=", "-=", "*=", "->",
    "and", "or", "not", "return", "in", "if", "elif", "while", "print"]);

  // The tokens of one line: {text, start, kind, key}. `state` carries the
  // bracket depth and whether the line's statement is a `def`, across lines.
  function tokenize(line, state) {
    const tokens = [];
    let i = 0;
    if (state.depth === 0 && !state.triple) state.inDef = /^\s*(def|fn)\b/.test(line);
    const prev = () => {
      for (let k = tokens.length - 1; k >= 0; k--) {
        if (tokens[k].kind !== "space") return tokens[k];
      }
      return state.depth > 0 ? state.lastToken : null;
    };
    const push = (text, kind, key) => {
      tokens.push({ text, start: i, kind, key: key || null });
      i += text.length;
    };
    if (state.triple) {
      const end = line.indexOf(state.triple);
      const stop = end < 0 ? line.length : end + 3;
      push(line.slice(0, stop), "string");
      if (end >= 0) state.triple = null;
    }
    while (i < line.length) {
      const rest = line.slice(i);
      const c = line[i];
      let m;
      if (rest.startsWith('"""') || rest.startsWith("'''")) {
        const q = rest.slice(0, 3);
        const end = rest.indexOf(q, 3);
        if (end < 0) state.triple = q;
        push(end < 0 ? rest : rest.slice(0, end + 3), "string", "STRING");
        continue;
      }
      if ((m = /^\s+/.exec(rest))) { push(m[0], "space"); continue; }
      if (c === "#") { push(rest, "comment"); continue; }
      if (c === '"' || c === "'") {
        let j = i + 1;
        while (j < line.length && line[j] !== c) j += line[j] === "\\" ? 2 : 1;
        push(line.slice(i, Math.min(j + 1, line.length)), "string", "STRING");
        continue;
      }
      if ((m = /^\d[\d_]*(\.\d+)?/.exec(rest))) { push(m[0], "number", "INT"); continue; }
      if ((m = /^@[A-Za-z_]\w*/.exec(rest))) { push(m[0], "decorator", m[0]); continue; }
      if ((m = /^[A-Za-z_]\w*/.exec(rest))) {
        const w = m[0];
        const p = prev();
        const after = line.slice(i + w.length);
        let kind = "name", key = null;
        if (w === "True" || w === "False" || w === "None") {
          kind = w === "None" ? "type" : "literal"; key = w;
        } else if ((w === "var" || w === "ref") && state.inDef && state.depth > 0) {
          kind = "convention"; key = w + "(param)";
        } else if (KEYWORDS.has(w)) {
          kind = "keyword"; key = w;
        } else if (CONVENTIONS.has(w) && /^\s+[A-Za-z_]/.test(after)) {
          kind = "convention"; key = w;
        } else if (p && p.text === "." && METHODS.has(w)) {
          kind = "builtin"; key = w;
        } else if (/^__\w+__$/.test(w)) {
          kind = "special"; key = w;
        } else if (/^[A-Z]/.test(w)) {
          kind = "type"; key = w;
        } else if (["print", "len", "range"].includes(w) && /^\s*\(/.test(after)) {
          kind = "builtin"; key = w;
        } else if (p && p.text === "def") {
          kind = "function";
        }
        push(w, kind, key);
        continue;
      }
      const op = OPERATORS.find((o) => rest.startsWith(o));
      if (op) {
        const p = prev();
        const operand = !p || OPERAND_START.has(p.text) ||
          (p.kind === "keyword" && p.text !== "self");
        let key = op;
        if (op === "-" && operand) key = "-(unary)";
        if (op === "[" && !operand) key = p.kind === "type" ? "[(type)" : "[(index)";
        if ("([{".includes(op)) state.depth++;
        if (")]}".includes(op)) state.depth = Math.max(0, state.depth - 1);
        push(op, "operator", key);
        continue;
      }
      push(c, "other");
    }
    const last = prev();
    if (last) state.lastToken = last;
    return tokens;
  }

  function escape(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // The HTML of the highlighted source. `links` holds the keys that have a
  // spec section; `marks` maps a line number to a list of
  // {kind, column, message}, the column 0 when only the line is known.
  function render(source, links, marks) {
    const state = { depth: 0, inDef: false, lastToken: null, triple: null };
    const out = [];
    source.split("\n").forEach((line, n) => {
      const lineMarks = marks[n + 1] || [];
      const pending = lineMarks.filter((m) => m.column > 0);
      let html = "";
      for (const t of tokenize(line, state)) {
        const cls = ["t-" + t.kind];
        const linked = t.key && links.has(t.key);
        if (linked) cls.push("linked");
        const end = t.start + t.text.length;
        for (let k = pending.length - 1; k >= 0; k--) {
          const col = pending[k].column - 1;
          if (t.kind !== "space" && col >= t.start && col < end) {
            cls.push("squiggle-" + pending[k].kind);
            pending.splice(k, 1);
          }
        }
        const attr = linked ? ` data-k="${escape(t.key)}"` : "";
        html += `<span class="${cls.join(" ")}"${attr}>${escape(t.text)}</span>`;
      }
      const kinds = [...new Set(lineMarks.map((m) => " mark-" + m.kind))].join("");
      const text = lineMarks.map((m) => m.message).filter(Boolean).join("  \u00b7  ");
      const msg = text ? ` data-msg="${escape(text).replace(/"/g, "&quot;")}"` : "";
      out.push(`<span class="line${kinds}"${msg}>${html || " "}</span>`);
    });
    return out.join("");
  }

  // The token at a character offset of the source, or null.
  function tokenAt(source, offset) {
    const state = { depth: 0, inDef: false, lastToken: null, triple: null };
    let base = 0;
    for (const line of source.split("\n")) {
      const tokens = tokenize(line, state);
      if (offset <= base + line.length) {
        const col = offset - base;
        return tokens.find((t) => t.kind !== "space" && col >= t.start &&
          col <= t.start + t.text.length) || null;
      }
      base += line.length + 1;
    }
    return null;
  }

  return { tokenize, render, tokenAt };
})();
