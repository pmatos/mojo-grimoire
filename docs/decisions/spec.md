# Current decisions: spec

This page says what holds today for the specification document and its
published site. It is the record: when this page and an ADR disagree, the
page wins (ADR-2026-11-15-1902). The site's library and its checks are a port
of the one in the human's project funk, adapted to this repository.

## What the spec is

The spec is the Lean of `lean/MojoGrimoire` rendered with Verso, in the style
of the WebAssembly specification (ADR-2026-11-15-2030). The Lean definitions
are normative; the prose makes them readable. Each declaration is shown as a
readable block, prose with KaTeX math and grammar boxes, with its Lean one
click away under the block in an HTML `<details>`. The human asked for funk's
approach on 2026-11-15.

`docs/spec/` is a Lake package, `mojospec`, that requires `lean/` by path and
Verso at the tag of the Lean toolchain. It holds the document
`MojoSpec.lean`, the readable documents of each module in `MojoSpec/`, and
the library `MojoSpecSite/` that checks them and renders the ADR appendix. It
adds no definition that the semantics depends on. The rendered document is a
build output and is not committed.

Rejected: readable prose in `lean/`'s doc comments only. `lean/` has no Verso
dependency, so its doc comments cannot hold the checked directives.

## Every module, from the first

No Lean module of the model merges without its spec section, formal and
readable. The human ruled this on 2026-11-15: as soon as there is Lean code,
it has its documentation.

The readable blocks of the module `MojoGrimoire.X.Y` are the Verso document
`docs/spec/MojoSpec/X/Y.lean`, the module `MojoSpec.X.Y`, which
`MojoSpec/ReadableDocs.lean` imports. `MojoSpec.lean` renders the section
with `{includeReadable "." MojoGrimoire.X.Y "Title" MojoSpec.X.Y (level := 2)}`.
A module that declares nothing renders with `{includeLiterate}` and has no
document.

Rejected: writing the document once the model exists, which would leave a
backlog documented in a hurry.

## Checks that keep the prose true to the Lean

Drift between a readable block and its Lean is a build error
(ADR-2026-11-15-2030). `MojoSpecSite` checks, when the document is
elaborated:

- `:::readable N₁ … Nₖ` names the declarations a block explains, of one
  module, and each must exist.
- The block pins a fingerprint of what they say: a theorem's statement, a
  definition's type and body, an inductive type's constructors, a
  structure's fields. It is a hash of Lean's terms, so a new proof keeps it.
- A definition that the prose restates, from any module, is added with
  `(pin := P)`, and its body then counts too. Pins stay explicit.
- A `grammar T` box shows every constructor of `T` exactly once.
- `{includeReadable}` fails unless the document explains every declaration
  of the module exactly once, and fails on a document with no block.

When the Lean changes, the build fails and prints the new signatures and
fingerprint. Read the block again against the Lean, correct it, then pin the
new value in the same PR. A stale fingerprint forces a look, not a correct
rewrite; that stays with review.

### Module docs and every module

Each readable document holds one `:::moduleDocs (fingerprint := "…")`
directive, closed by `:::` on the next line, when its module has `/-! -/`
docs. Its fingerprint covers every declaration of the module, so a change to
what the module declares fails this pin too. Read the module's docs again,
then pin the value the build prints.

Every module under `lean/MojoGrimoire` is in the spec. `mojospec` fails when
`docs/spec/MojoSpec.lean`, or a chapter it includes with
`{include 1 MojoSpec.Chapters.Name}`, has no `{includeReadable}` or
`{includeLiterate}` line for a module. A chapter that would push
`MojoSpec.lean` over the file-size budget moves to `MojoSpec/Chapters/`.

## The ADR appendix and its citations

The spec's last part is the appendix "Architecture decision records", tagged
`adrs`. When `mojospec` renders, it reads each ADR in `docs/adrs/` in name
order, every `.md` file but `README.md` and `INDEX.md`, parses it with
MD4Lean and adds one page per ADR after an index table. Nothing is generated
into the tree, so the site matches the commit it names.

An ADR's page has the tag `ADR-<id>` and the address `adrs/ADR-<id>/`. The
block after the level-1 heading must be the `Status:` line. The build fails,
naming the file, on Markdown the document cannot show as GitHub does: raw
HTML, images, horizontal rules, strikethrough, task lists and hard line
breaks. A relative path to another ADR links to its page; any other relative
path links to the file on GitHub at `main`, and must exist.

`mojospec` turns each ADR citation in the document's text, in the docs that
`{includeLiterate}` renders and in the ADRs into a link to the ADR's page. A
citation in a heading, or in the text of another link, fails the build. A
citation in code is quoted, not linked. A citation of no ADR fails the
build, with its file, line and column.

The `adr-citations` hook checks every citation in every tracked text file on
every commit (ADR-2026-11-15-1902). Its grammar and `MojoSpecSite`'s share
the cases in `scripts/adr-citation-cases.json`, which both test suites read,
so a change to either grammar adds a case. `MojoSpecSite`'s `#guard` tests
run when it builds.

## Building the spec

`scripts/build-spec.sh [OUTPUT_DIR]` builds `docs/spec/` and renders the site
to `OUTPUT_DIR/html-multi`, by default under `docs/spec/_out`. It applies the
guards of `scripts/build-lean.sh` (ADR-2026-11-15-1905) to both packages.
`--update` runs `lake update` in `docs/spec/` under the same guards; never
run a bare `lake update` there. `docs/spec/lean-toolchain` is a link to
`lean/lean-toolchain`, so the two packages always share one toolchain, and a
toolchain bump moves Verso's `rev` to the matching tag in the same PR.

`docs/spec/` builds without `--wfail`: Verso's warnings are not ours. Our
code in `lean/` still fails on any warning through `lean-build`.

The `spec` pre-commit hook runs the script when a file under `lean/`,
`docs/spec/` or `docs/adrs/` changes, and CI runs it in the `lean` job after
`lean-build`. CI caches `docs/spec/.lake/packages` with the toolchain, keyed
by `lean/lean-toolchain` and `docs/spec/lake-manifest.json`; Verso's build
lives there.

## Publishing the site

Every push to `main` deploys the document to GitHub Pages through
`.github/workflows/pages.yml`, which also runs by hand. Pull requests never
deploy. The `build` job, which may only read the repository, runs
`scripts/build-spec.sh` and uploads `html-multi`; the `deploy` job, the only
one with `pages: write` and `id-token: write`, runs no code from the
repository. The deploy tries up to three times, each only if the one before
failed. It restores the caches that `ci.yml` saves and never saves one.

Pages must be enabled with the source "GitHub Actions" in the repository's
settings; the human does this once. The repository's default branch is
`main`, and the `github-pages` environment allows deployments from `main`
only. Enabling Pages writes the default branch of that moment into the
environment's branch rule. On 2026-11-16 that branch was not `main`, and
every deploy from `main` was rejected until the rule was changed.

Rejected: committing the HTML to a `gh-pages` branch, which puts build
output in git and needs `contents: write` in the job that runs Lake.

### Every page names its commit

`scripts/build-spec.sh` passes the first 12 hex digits of `HEAD`, with
`-dirty` when `git status --porcelain` lists anything, in `MOJOSPEC_COMMIT`,
and in Actions the commit's page in `MOJOSPEC_COMMIT_URL`.
`docs/spec/MojoSpecMain.lean` reads both when it renders and adds "Built
from commit …" to every page. Reading them at render time, not while the
document elaborates, keeps a warm local build from showing a stale commit.
