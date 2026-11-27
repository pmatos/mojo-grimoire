// The editor: a textarea over the highlighted text, a gutter with line
// numbers and the run's markers, a hover card for each linked token, and
// the program kept in the URL's hash.
"use strict";

const Editor = (() => {
  const $ = (id) => document.getElementById(id);
  const area = $("source");
  const hl = $("hl");
  const gutter = $("gutter");
  const card = $("hover-card");
  let tokens = {}; // the token map, as /api/spec gives it
  let links = new Set();
  let marks = {};
  let onOpen = () => {};
  let leaveTab = false;
  let hoverTimer = null;
  let hoverKey = null;

  function setTokens(map, openSpec) {
    tokens = map;
    links = new Set(Object.keys(map).filter((k) => map[k].decls.length));
    onOpen = openSpec;
    paint();
  }

  function paint() {
    hl.innerHTML = Highlight.render(area.value, links, marks) + "\n";
    const count = area.value.split("\n").length;
    let html = "";
    for (let n = 1; n <= count; n++) {
      const m = marks[n] || [];
      const kind = m.length ? ` g-${m[0].kind}` : "";
      const title = m.map((x) => x.message).filter(Boolean).join("\n");
      html += `<div class="g-line${kind}" data-line="${n}"${title ? ` title="${escapeAttr(title)}"` : ""}>${n}</div>`;
    }
    gutter.innerHTML = html;
    sync();
  }

  function escapeAttr(t) {
    return t.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  }

  function sync() {
    hl.scrollTop = area.scrollTop;
    hl.scrollLeft = area.scrollLeft;
    gutter.scrollTop = area.scrollTop;
  }

  // Markers: {line: [{kind, column, message}]}; kind is error, note,
  // model or decl.
  function setMarks(m) {
    marks = m;
    paint();
  }

  function clearMarks() {
    if (Object.keys(marks).length) setMarks({});
  }

  function lineStart(n) {
    const lines = area.value.split("\n");
    let offset = 0;
    for (let i = 0; i < n - 1 && i < lines.length; i++) offset += lines[i].length + 1;
    return offset;
  }

  function reveal(line, column) {
    const offset = lineStart(line) + Math.max(0, (column || 1) - 1);
    area.focus();
    area.setSelectionRange(offset, offset);
    const lh = parseFloat(getComputedStyle(area).lineHeight) || 20;
    const top = (line - 1) * lh;
    if (top < area.scrollTop || top > area.scrollTop + area.clientHeight - lh * 2) {
      area.scrollTop = Math.max(0, top - area.clientHeight / 3);
    }
    caret();
  }

  function insert(text) {
    // insertText keeps the browser's undo history.
    if (!document.execCommand("insertText", false, text)) {
      area.setRangeText(text, area.selectionStart, area.selectionEnd, "end");
      area.dispatchEvent(new Event("input"));
    }
  }

  function onKey(e) {
    const mod = e.ctrlKey || e.metaKey;
    if (e.key === "Escape") { leaveTab = true; hideCard(); return; }
    if (e.key === "Tab" && !leaveTab && !mod) {
      e.preventDefault();
      const start = area.value.lastIndexOf("\n", area.selectionStart - 1) + 1;
      if (e.shiftKey) {
        const head = area.value.slice(start, start + 4);
        const cut = head.length - head.replace(/^ {1,4}/, "").length;
        if (cut) {
          area.setSelectionRange(start, start + cut);
          insert("");
        }
      } else {
        const col = area.selectionStart - start;
        insert(" ".repeat(4 - (col % 4)));
      }
      return;
    }
    leaveTab = false;
    if (e.key === "Enter" && !mod && !e.shiftKey && !e.altKey) {
      e.preventDefault();
      const start = area.value.lastIndexOf("\n", area.selectionStart - 1) + 1;
      const before = area.value.slice(start, area.selectionStart);
      let indent = /^\s*/.exec(before)[0];
      if (/:\s*(#.*)?$/.test(before)) indent += "    ";
      insert("\n" + indent);
    }
  }

  // The linked token under the pointer. The textarea takes the pointer and
  // hit testing skips the highlighted text, so the two swap for one query.
  function tokenUnder(x, y) {
    area.style.pointerEvents = "none";
    hl.style.pointerEvents = "auto";
    const el = document.elementFromPoint(x, y);
    area.style.pointerEvents = "";
    hl.style.pointerEvents = "";
    return el && el.dataset && el.dataset.k && hl.contains(el) ? el : null;
  }

  function onMove(e) {
    const el = tokenUnder(e.clientX, e.clientY);
    area.classList.toggle("over-link", !!el && (e.ctrlKey || e.metaKey));
    const key = el ? el.dataset.k : null;
    if (key === hoverKey) return;
    hoverKey = key;
    clearTimeout(hoverTimer);
    if (!el) { hoverTimer = setTimeout(maybeHide, 250); return; }
    hoverTimer = setTimeout(() => showCard(key, el.getBoundingClientRect()), 280);
  }

  function onClick(e) {
    if (!(e.ctrlKey || e.metaKey)) return;
    const el = tokenUnder(e.clientX, e.clientY);
    if (el && tokens[el.dataset.k]) {
      e.preventDefault();
      onOpen(tokens[el.dataset.k].decls[0]);
    }
  }

  function short(name) {
    return name.replace(/^MojoGrimoire\./, "");
  }

  function showCard(key, rect) {
    const entry = tokens[key];
    if (!entry || !entry.decls.length) return;
    card.replaceChildren();
    const head = document.createElement("div");
    head.className = "card-head";
    const tok = document.createElement("code");
    tok.textContent = key.replace(/\(.*\)$/, "");
    const kind = document.createElement("span");
    kind.className = "card-kind";
    kind.textContent = entry.kind;
    head.append(tok, kind);
    card.append(head);
    for (const d of entry.decls) card.append(declBlock(d));
    card.hidden = false;
    const w = card.offsetWidth, h = card.offsetHeight;
    let left = Math.min(rect.left, window.innerWidth - w - 12);
    let top = rect.bottom + 6;
    if (top + h > window.innerHeight - 8) top = Math.max(8, rect.top - h - 6);
    card.style.left = Math.max(8, left) + "px";
    card.style.top = top + "px";
  }

  function declBlock(d) {
    const box = document.createElement("div");
    box.className = "card-decl";
    const link = document.createElement("a");
    link.href = d.url;
    link.textContent = short(d.name);
    link.className = "card-name";
    link.addEventListener("click", (e) => {
      if (e.ctrlKey || e.metaKey || e.shiftKey) return;
      e.preventDefault();
      onOpen(d);
      hideCard();
    });
    const where = document.createElement("span");
    where.className = "card-where";
    where.textContent = d.title;
    const sig = document.createElement("pre");
    sig.className = "card-sig";
    sig.textContent = short(d.sig || d.name);
    box.append(link, where, sig);
    const docText = d.doc || (d.parent && d.parent.doc);
    if (docText) {
      const doc = document.createElement("p");
      doc.className = "card-doc";
      const from = d.doc ? "" : `${short(d.parent.name)}: `;
      const text = from + (docText.length > 420 ? docText.slice(0, 420) + "…" : docText);
      // The docstring's inline code is written between backticks.
      text.split("`").forEach((part, i) => {
        if (i % 2) {
          const c = document.createElement("code");
          c.textContent = part;
          doc.append(c);
        } else {
          doc.append(part);
        }
      });
      box.append(doc);
    }
    return box;
  }

  function maybeHide() {
    if (!card.matches(":hover")) hideCard();
  }

  function hideCard() {
    card.hidden = true;
    hoverKey = null;
  }

  // The status line: the caret's line and column and its token's section.
  function caret() {
    const pos = area.selectionStart;
    const before = area.value.slice(0, pos);
    const line = before.split("\n").length;
    const col = pos - before.lastIndexOf("\n");
    $("caret").textContent = `Ln ${line}, Col ${col}`;
    const tok = Highlight.tokenAt(area.value, pos);
    const slot = $("caret-token");
    slot.replaceChildren();
    if (tok && tok.key && links.has(tok.key)) {
      const d = tokens[tok.key].decls[0];
      const a = document.createElement("a");
      a.href = d.url;
      a.textContent = `${tok.text} → ${short(d.name)}`;
      a.addEventListener("click", (e) => { e.preventDefault(); onOpen(d); });
      slot.append(a);
    }
  }

  // The hash: #code=BASE64URL&level=L&fuel=N.
  function encode(text) {
    const bytes = new TextEncoder().encode(text);
    let bin = "";
    bytes.forEach((b) => { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  function decode(text) {
    const bin = atob(text.replace(/-/g, "+").replace(/_/g, "/"));
    return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
  }

  function readHash() {
    const params = new URLSearchParams(location.hash.slice(1));
    let code = null;
    try { code = params.has("code") ? decode(params.get("code")) : null; } catch (e) { code = null; }
    return { code, level: params.get("level"), fuel: params.get("fuel") };
  }

  function writeHash(extra) {
    const params = new URLSearchParams({ code: encode(area.value) });
    for (const [k, v] of Object.entries(extra)) if (v) params.set(k, v);
    history.replaceState(null, "", location.pathname + "#" + params.toString());
  }

  let changed = () => {};
  let hashTimer = null;
  function onInput() {
    paint();
    caret();
    clearTimeout(hashTimer);
    hashTimer = setTimeout(() => changed(), 250);
  }

  function init(onChange) {
    changed = onChange;
    area.addEventListener("input", onInput);
    area.addEventListener("scroll", sync);
    area.addEventListener("keydown", onKey);
    area.addEventListener("mousemove", onMove);
    area.addEventListener("mouseleave", () => { hoverKey = null; hoverTimer = setTimeout(maybeHide, 250); });
    area.addEventListener("mousedown", onClick);
    ["keyup", "click", "focus"].forEach((ev) => area.addEventListener(ev, caret));
    card.addEventListener("mouseleave", () => setTimeout(maybeHide, 200));
    gutter.addEventListener("click", (e) => {
      const n = e.target.dataset && e.target.dataset.line;
      if (n) reveal(Number(n), 1);
    });
    window.addEventListener("keyup", (e) => {
      if (e.key === "Control" || e.key === "Meta") area.classList.remove("over-link");
    });
  }

  function setValue(text) {
    area.value = text;
    marks = {};
    paint();
    caret();
  }

  return {
    init, setTokens, setMarks, clearMarks, setValue, reveal, readHash, writeHash,
    value: () => area.value, focus: () => area.focus(), hideCard,
  };
})();
