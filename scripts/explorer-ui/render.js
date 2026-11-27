// The explorer's views of a run: the two panes, the verdict, the sweep and
// the decision-log entry. Every text from a run goes in with textContent.
"use strict";

const Render = (() => {
  const REPO = "https://github.com/pmatos/mojo-grimoire";
  let spec = { classes: {}, runErrors: {} };
  let openSpec = () => {};
  let openEntry = () => {};

  function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === "class") node.className = v;
      else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
      else node.setAttribute(k, v === true ? "" : v);
    }
    for (const c of children.flat()) {
      if (c === null || c === undefined || c === false) continue;
      node.append(c instanceof Node ? c : document.createTextNode(String(c)));
    }
    return node;
  }

  function configure(specPayload, handlers) {
    spec = specPayload;
    openSpec = handlers.openSpec;
    openEntry = handlers.openEntry;
  }

  function chip(text, kind, title) {
    return el("span", { class: `chip ${kind || ""}`, title }, text);
  }

  function outcomeChip(result) {
    return chip(result.outcome, `o-${result.outcome}`);
  }

  function seconds(s) {
    return s === null || s === undefined ? "" : s < 1 ? `${Math.round(s * 1000)} ms` : `${s.toFixed(2)} s`;
  }

  function specLink(decl, text) {
    return el("a", {
      href: decl.url, class: "spec-link", title: decl.name,
      onclick: (e) => {
        if (e.ctrlKey || e.metaKey || e.shiftKey) return;
        e.preventDefault();
        openSpec(decl);
      },
    }, text);
  }

  function classLink(cls) {
    if (!cls) return el("span", { class: "muted" }, "no class: no pattern of diagnostics.json matches");
    const d = spec.classes[cls];
    return d ? specLink(d, cls) : el("code", {}, cls);
  }

  function runErrorLink(name) {
    const base = (name || "").split(" ")[0];
    const d = spec.runErrors[base];
    return d ? specLink(d, name) : el("code", {}, name);
  }

  function jump(line, column, text) {
    return el("button", { class: "jump", title: "Show in the editor",
      onclick: () => Editor.reveal(line, column) }, text);
  }

  function section(title, ...body) {
    return el("section", { class: "out-section" }, el("h3", {}, title), ...body);
  }

  function output(lines) {
    if (!lines.length) return el("p", { class: "muted" }, "(nothing printed)");
    return el("pre", { class: "stdout" }, lines.join("\n"));
  }

  function raw(title, step) {
    if (!step || !(step.stderr || step.stdout)) return null;
    const text = [step.stdout && `stdout:\n${step.stdout}`, step.stderr && `stderr:\n${step.stderr}`]
      .filter(Boolean).join("\n");
    return el("details", { class: "raw" }, el("summary", {}, title), el("pre", {}, text));
  }

  function compiler(report, chips, body) {
    const r = report.result;
    const build = report.build || {}, run = report.run;
    chips.replaceChildren(outcomeChip(r),
      chip(`build ${build.exit ?? "-"}${run ? ` · run ${run.exit ?? "-"}` : ""}`, "", "exit codes"),
      chip(`${seconds(build.seconds)}${run ? ` + ${seconds(run.seconds)}` : ""}`, "time", "build + run time"));
    const parts = [];
    const primary = (report.diagnostics || []).find((d) => d.primary);
    if (r.outcome === "rejected") {
      parts.push(section("Error class", classLink(r.class)));
      parts.push(section("First error",
        el("p", { class: "diag" }, r.diagnostic),
        primary ? jump(primary.line, primary.column, `line ${primary.line}:${primary.column}`) : null));
    } else if (r.outcome === "failed") {
      parts.push(section("Run-time failure", el("p", { class: "diag" }, r.diagnostic)));
    } else if (r.outcome === "error") {
      parts.push(section("No result", el("p", { class: "diag bad" }, r.diagnostic)));
    }
    if (r.outcome !== "rejected" && r.outcome !== "error") parts.push(section("Output", output(r.stdout)));
    const located = (report.diagnostics || []);
    if (located.length) {
      parts.push(section("Located messages", el("ul", { class: "located" }, located.map((d) =>
        el("li", { class: `sev-${d.severity}` }, jump(d.line, d.column, `${d.line}:${d.column}`),
          el("span", { class: "sev" }, d.severity), d.message)))));
    }
    parts.push(raw("Build output", build), raw("Run output", run));
    body.replaceChildren(...parts.filter(Boolean));
  }

  function model(report, chips, body) {
    const r = report.result, step = report.step || {};
    chips.replaceChildren(outcomeChip(r), chip(`exit ${step.exit ?? "-"}`, "", "exit code"),
      chip(seconds(step.seconds), "time", "run time"));
    const parts = [];
    if (r.outcome === "rejected") {
      const line = report.declLine;
      parts.push(section("Error class", classLink(r.class)));
      parts.push(section("Declaration", el("p", {}, el("code", {}, report.decl || r.diagnostic),
        line ? jump(line, 1, `line ${line}`) : null),
        el("p", { class: "muted small" }, "The driver names the declaration, not the line.")));
    } else if (r.outcome === "failed") {
      parts.push(section("Run-time error", runErrorLink(r.diagnostic)));
    }
    if (report.position) {
      const p = report.position;
      parts.push(section(p.kind === "syntax error" ? "Syntax error" : "Outside the subset",
        el("p", { class: "diag" }, p.message), jump(p.line, 1, `line ${p.line}`)));
    } else if (r.outcome === "error") {
      parts.push(section("No result", el("p", { class: "diag bad" }, r.diagnostic)));
    }
    if (r.outcome !== "rejected" && r.outcome !== "error") parts.push(section("Output", output(r.stdout)));
    parts.push(raw("Driver output", step));
    body.replaceChildren(...parts.filter(Boolean));
  }

  const BADGES = {
    agree: "Agree", known: "Known disagreement", disagree: "Disagree",
    "no-verdict": "No verdict", running: "Running…", idle: "Not run yet",
  };

  function entryButton(id) {
    return el("button", { class: "entry-link", onclick: () => openEntry(id) }, id);
  }

  function verdictLine(v) {
    return v.entry ? [BADGES[v.state], " · ", entryButton(v.entry)] : [BADGES[v.state]];
  }

  function verdict(box, answer) {
    const v = answer.verdict;
    box.dataset.state = v.state;
    const badge = box.querySelector("#verdict-badge");
    badge.replaceChildren(...verdictLine(v));
    const level = answer.level === "default" ? "the default build (-O3)" : answer.level;
    const detail = [el("p", {}, `By the suite's comparison, against ${level}.`)];
    if (v.problems.length) detail.push(el("ul", { class: "problems" }, v.problems.map((p) => el("li", {}, p))));
    const s = answer.suite;
    if (s) {
      const rec = s.recorded;
      const live = answer.compiler.result;
      const same = rec && answer.level === "default" && rec.outcome === live.outcome &&
        rec.class === live.class && JSON.stringify(rec.stdout) === JSON.stringify(live.stdout);
      detail.push(el("p", { class: "suite-line" }, "Suite program ", el("code", {}, s.name),
        rec ? `: recorded ${rec.outcome}${rec.class ? " " + rec.class : ""}` : ": no recorded result",
        answer.level === "default" && rec ? (same ? ", as the compiler gives now" : ", but the compiler now differs") : "",
        s.entry ? "; named by " : ".", s.entry ? entryButton(s.entry) : null));
      if (answer.checkVerdict) {
        detail.push(el("p", { class: "suite-line" }, "scripts/conformance.py check: ",
          el("strong", {}, ...verdictLine(answer.checkVerdict))));
      }
    }
    box.querySelector("#verdict-detail").replaceChildren(...detail);
  }

  function pending(box, text) {
    box.dataset.state = "running";
    box.querySelector("#verdict-badge").textContent = BADGES.running;
    box.querySelector("#verdict-detail").textContent = text;
  }

  function failure(box, text) {
    box.dataset.state = "no-verdict";
    box.querySelector("#verdict-badge").textContent = "Error";
    box.querySelector("#verdict-detail").textContent = text;
  }

  function summary(r) {
    if (r.outcome === "rejected") return r.class || "no class";
    if (r.outcome === "error") return r.diagnostic;
    const out = r.stdout.join(" ⏎ ");
    return (out.length > 60 ? out.slice(0, 60) + "…" : out) || "(nothing printed)";
  }

  function sweep(panel, answer) {
    const differ = answer.levels.filter((row) => row.differs).map((row) => row.level);
    const s = answer.suite;
    const head = el("header", { class: "sweep-head" },
      el("h2", {}, differ.length ? `The levels differ at ${differ.join(", ")}` : "Every level gives the same result"),
      s && s.entry ? el("span", { class: "muted" }, "named by ", entryButton(s.entry)) : null,
      el("button", { class: "ghost icon", "aria-label": "Close", onclick: () => { panel.hidden = true; } }, "✕"));
    const rows = answer.levels.map((row) => {
      const r = row.compiler.result;
      return el("tr", { class: row.differs ? "differs" : "" },
        el("th", { scope: "row" }, row.level),
        el("td", {}, outcomeChip(r)),
        el("td", { class: "sum" }, summary(r),
          row.differences.length ? el("div", { class: "diffs" }, row.differences.join("; ")) : null),
        el("td", {}, el("span", { class: `v v-${row.verdict.state}` }, BADGES[row.verdict.state])),
        el("td", { class: "time" }, seconds(row.compiler.build && row.compiler.build.seconds)));
    });
    const table = el("table", { class: "sweep-table" },
      el("thead", {}, el("tr", {}, ["Level", "Outcome", "Result", "Model", "Build"].map((h) => el("th", { scope: "col" }, h)))),
      el("tbody", {}, rows));
    panel.replaceChildren(head, el("p", { class: "muted small" },
      `Compared with -O3 as scripts/conformance.py levels compares them. The model: ${answer.model.result.outcome} (${summary(answer.model.result)}).`),
    table);
    panel.hidden = false;
  }

  function entry(title, body, data) {
    title.textContent = `${data.id}: ${data.title}`;
    const parts = [el("pre", { class: "entry-text" }, data.text)];
    const bug = data.bug;
    if (bug) {
      const dl = el("dl", { class: "bug" });
      const row = (k, v) => v && dl.append(el("dt", {}, k), el("dd", {}, v));
      row("Compiler bug", bug.title);
      row("Compiler", bug.compiler);
      row("Fixed compiler", bug.fixed);
      row("Model", bug.model);
      row("Ruling", bug.confirmation && `${bug.confirmation} (provisional until discussed with Modular)`);
      row("Upstream report", bug.upstream);
      if (bug.issue) dl.append(el("dt", {}, "Issue"), el("dd", {}, el("a", { href: `${REPO}/issues/${bug.issue}`, target: "_blank", rel: "noopener" }, `#${bug.issue}`)));
      parts.unshift(dl);
    }
    parts.push(el("p", {}, el("a", { href: data.url, target: "_blank", rel: "noopener" }, "The decision log on GitHub ↗")));
    body.replaceChildren(...parts);
  }

  return { el, configure, compiler, model, verdict, pending, failure, sweep, entry, summary, chip, outcomeChip, entryButton };
})();
