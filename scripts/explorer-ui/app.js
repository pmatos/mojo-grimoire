// The explorer's page: the session's token, the API calls, and the wiring
// of the toolbar, the drawers and the run.
"use strict";

(() => {
  const $ = (id) => document.getElementById(id);
  const el = Render.el;
  const SAMPLE = [
    "@fieldwise_init",
    "struct Pair(Copyable):",
    "    var a: Int",
    "    var b: Int",
    "",
    "def swap(mut p: Pair):",
    "    var t = p.a",
    "    p.a = p.b",
    "    p.b = t",
    "",
    "def main():",
    "    var p = Pair(1, 2)",
    "    swap(p)",
    "    print(p.a, p.b)",
    "    var xs: List[Int] = [1, 2, 3]",
    "    xs.append(4)",
    "    print(len(xs), xs[3])",
    "",
  ].join("\n");

  // The token comes in the URL the server prints. It is kept in this tab's
  // sessionStorage, never localStorage, so that it lasts a reload, and is
  // dropped from the URL at once.
  function token() {
    const params = new URLSearchParams(location.search);
    const given = params.get("token");
    try {
      if (given) sessionStorage.setItem("explorer-token", given);
      return sessionStorage.getItem("explorer-token") || given;
    } catch (e) {
      return given;
    }
  }
  const TOKEN = token();
  if (location.search) history.replaceState(null, "", location.pathname + location.hash);

  async function api(path, body) {
    const opts = { headers: { "X-Explorer-Token": TOKEN || "" } };
    if (body !== undefined) {
      opts.method = "POST";
      opts.headers["Content-Type"] = "application/json";
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(path, opts);
    const data = await res.json().catch(() => ({ error: res.statusText }));
    if (res.status === 401) banner("This page has no valid token. Open the URL that scripts/explorer.py printed.");
    if (!res.ok) throw new Error(data.error || res.statusText);
    return data;
  }

  function banner(text) {
    const b = $("banner");
    b.textContent = text;
    b.hidden = false;
  }

  // --- drawers and the theme -------------------------------------------------

  function openSpec(decl) {
    $("spec-title").textContent = decl.name.replace(/^MojoGrimoire\./, "");
    $("spec-newtab").href = decl.url;
    $("spec-frame").src = decl.url;
    $("spec-drawer").hidden = false;
  }

  async function openEntry(id) {
    try {
      const data = await api(`/api/entry?id=${encodeURIComponent(id)}`);
      Render.entry($("entry-title"), $("entry-body"), data);
      $("entry-modal").hidden = false;
      $("entry-modal").querySelector("button").focus();
    } catch (e) {
      banner(`Cannot read ${id}: ${e.message}`);
    }
  }

  document.addEventListener("click", (e) => {
    const target = e.target.closest("[data-close]");
    if (target) $(target.dataset.close).hidden = true;
    if (e.target.id === "entry-modal") e.target.hidden = true;
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      if (!$("entry-modal").hidden) $("entry-modal").hidden = true;
      else if (!$("examples").hidden) $("examples").hidden = true;
      else if (!$("spec-drawer").hidden && document.activeElement !== $("source")) $("spec-drawer").hidden = true;
    }
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      e.preventDefault();
      if (e.shiftKey) sweep(); else run();
    }
  });

  $("theme").addEventListener("click", () => {
    const root = document.documentElement;
    const dark = root.dataset.theme ? root.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = dark ? "light" : "dark";
    try { localStorage.setItem("explorer-theme", root.dataset.theme); } catch (e) { /* no storage */ }
  });

  if (/Mac|iPhone|iPad/.test(navigator.platform)) $("run-key").textContent = "⌘ ↵";

  // --- the header ------------------------------------------------------------

  function header(info, specInfo) {
    const m = info.model;
    const meta = $("meta");
    meta.replaceChildren(
      Render.chip(`model ${m.commit}${m.dirty ? "-dirty" : ""}`, "meta-chip", "The commit of the checkout that holds the model"),
      Render.chip(info.compiler.replace(/^Mojo /, "mojo "), "meta-chip", "The compiler's version"),
      Render.chip(specInfo.available ? `spec ${specInfo.commit || "?"}` : "no spec", "meta-chip", "The commit the rendered spec was built from"));
    const w = info.warnings;
    if (w.length) {
      const btn = $("warnings");
      btn.hidden = false;
      btn.textContent = `⚠ ${w.length}`;
      btn.title = w.join("\n");
      btn.onclick = () => banner(w.join(" — "));
    }
  }

  // --- the run ---------------------------------------------------------------

  function settings() {
    const fuel = $("fuel").value.trim();
    return { level: $("level").value, fuel: fuel ? Number(fuel) : null };
  }

  function persist() {
    const s = settings();
    Editor.writeHash({ level: s.level === "default" ? "" : s.level, fuel: s.fuel || "" });
    matchSuite();
  }

  function declLine(source, decl) {
    if (!decl) return null;
    const lines = source.split("\n");
    const quote = (x) => x.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const [owner, member] = (decl.includes(".") ? decl.split(".") : [null, decl]).map((x) => x && quote(x));
    let from = 0;
    if (owner) {
      from = lines.findIndex((l) => new RegExp(`^struct\\s+${owner}\\b`).test(l));
      if (from < 0) return null;
    }
    const re = owner ? new RegExp(`^\\s+(def|fn)\\s+${member}\\b`)
      : new RegExp(`^((def|fn)\\s+${member}\\b|struct\\s+${member}\\b)`);
    for (let i = from; i < lines.length; i++) if (re.test(lines[i])) return i + 1;
    return null;
  }

  function markRun(answer, source) {
    const marks = {};
    const add = (line, m) => { (marks[line] = marks[line] || []).push(m); };
    for (const d of answer.compiler.diagnostics || []) {
      add(d.line, { kind: d.primary ? "error" : "note", column: d.column,
        message: `${d.primary ? "compiler" : d.severity}: ${d.message}` });
    }
    const p = answer.model.position;
    if (p) add(p.line, { kind: "model", column: 0, message: `model, ${p.kind}: ${p.message}` });
    const line = declLine(source, answer.model.decl);
    answer.model.declLine = line;
    if (line && answer.model.result.outcome === "rejected") {
      add(line, { kind: "decl", column: 0, message: `model: ${answer.model.result.class} in ${answer.model.decl}` });
    }
    Editor.setMarks(marks);
  }

  let busy = false;
  async function guarded(label, work) {
    if (busy) return;
    busy = true;
    $("run").disabled = $("sweep").disabled = true;
    Render.pending($("verdict"), label);
    try {
      await work();
    } catch (e) {
      Render.failure($("verdict"), e.message);
    } finally {
      busy = false;
      $("run").disabled = $("sweep").disabled = false;
    }
  }

  function run() {
    const source = Editor.value();
    const s = settings();
    return guarded("Building with the compiler and running the model…", async () => {
      const answer = await api("/api/run", { source, level: s.level, fuel: s.fuel });
      $("compiler-sub").textContent = answer.level === "default" ? "mojo build" : `mojo build ${answer.level}`;
      markRun(answer, source);
      Render.compiler(answer.compiler, $("compiler-chips"), $("compiler-body"));
      Render.model(answer.model, $("model-chips"), $("model-body"));
      Render.verdict($("verdict"), answer);
    });
  }

  function sweep() {
    const source = Editor.value();
    return guarded("Building at -O0, -O1, -O2, -O3 and with ASSERT=all…", async () => {
      const answer = await api("/api/sweep", { source, fuel: settings().fuel });
      Render.sweep($("sweep-panel"), answer);
      const differ = answer.levels.filter((r) => r.differs).length;
      // Amber only when a ruling covers the program; any other difference
      // between levels is a red flag.
      const ruled = answer.suite && answer.suite.entry;
      $("verdict").dataset.state = differ ? (ruled ? "known" : "disagree") : "agree";
      $("verdict-badge").textContent = differ ? `${differ} level${differ > 1 ? "s differ" : " differs"}` : "Levels agree";
      $("verdict-detail").textContent = "The sweep's table shows each level; Run gives the panes for one level.";
    });
  }

  $("run").addEventListener("click", run);
  $("sweep").addEventListener("click", sweep);

  // --- the examples ------------------------------------------------------------

  let examples = [];
  let loaded = null;

  // The tag of a loaded suite program stays while the text is still its own.
  function matchSuite() {
    if (loaded !== null && Editor.value() !== loaded) {
      $("suite-tag").hidden = true;
      loaded = null;
    }
  }

  function showExamples() {
    const q = $("example-filter").value.trim().toLowerCase();
    const only = $("example-entries").checked;
    const list = $("example-list");
    const shown = examples.filter((x) => (!only || x.entry) &&
      (!q || [x.name, x.outcome, x.class, x.entry].some((f) => f && f.toLowerCase().includes(q))));
    const cap = 400;
    $("example-count").textContent = `${shown.length} of ${examples.length} programs` +
      (shown.length > cap ? `, the first ${cap} shown; filter to see the others` : "");
    list.replaceChildren(...shown.slice(0, cap).map((x) => el("li", {},
      el("button", { class: "example", onclick: () => loadExample(x.name) },
        el("span", { class: "ex-name" }, x.name),
        el("span", { class: "ex-tags" },
          x.outcome ? Render.chip(x.outcome, `o-${x.outcome}`) : Render.chip("unrecorded", ""),
          x.class ? el("code", { class: "ex-class" }, x.class) : null,
          x.entry ? Render.chip(x.entry, x.known ? "entry known" : "entry", x.known ? "known.json lists it" : "a ruled compiler bug names it") : null)))));
  }

  async function loadExample(name) {
    try {
      const data = await api(`/api/example?name=${encodeURIComponent(name)}`);
      history.pushState(null, "", location.pathname + location.hash);
      loaded = data.source.replace(/\n$/, "");
      Editor.setValue(loaded);
      persist();
      $("examples").hidden = true;
      const tag = $("suite-tag");
      tag.replaceChildren(el("code", {}, data.name),
        data.recorded ? ` recorded ${data.recorded.outcome}${data.recorded.class ? " " + data.recorded.class : ""}` : " unrecorded",
        data.entry ? " · " : "", data.entry ? Render.entryButton(data.entry) : null);
      tag.hidden = false;
      Editor.focus();
    } catch (e) {
      banner(`Cannot load ${name}: ${e.message}`);
    }
  }

  $("examples-open").addEventListener("click", async () => {
    $("examples").hidden = false;
    $("example-filter").focus();
    if (!examples.length) {
      examples = await api("/api/examples");
      showExamples();
    }
  });
  $("example-filter").addEventListener("input", showExamples);
  $("example-entries").addEventListener("change", showExamples);

  // --- start -------------------------------------------------------------------

  async function start() {
    const fromHash = Editor.readHash();
    Editor.init(persist);
    Editor.setValue(fromHash.code ?? SAMPLE);
    if (!TOKEN) banner("This page has no token. Open the URL that scripts/explorer.py printed.");
    let info, specPayload;
    try {
      [info, specPayload] = await Promise.all([api("/api/info"), api("/api/spec")]);
    } catch (e) {
      banner(`The server refused: ${e.message}`);
      return;
    }
    $("level").replaceChildren(...info.levels.map((lv) =>
      el("option", { value: lv }, lv === "default" ? "default (-O3)" : lv)));
    const applyHash = (h) => {
      $("level").value = h.level && info.levels.includes(h.level) ? h.level : "default";
      $("fuel").value = h.fuel || "";
    };
    applyHash(fromHash);
    $("level").addEventListener("change", persist);
    $("fuel").addEventListener("change", persist);
    header(info, specPayload);
    Render.configure(specPayload, { openSpec, openEntry });
    Editor.setTokens(specPayload.tokens, openSpec);
    window.addEventListener("popstate", () => {
      const h = Editor.readHash();
      if (h.code !== null && h.code !== Editor.value()) Editor.setValue(h.code);
      applyHash(h);
    });
  }

  start();
})();
