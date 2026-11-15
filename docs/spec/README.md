# The Mojo specification

mojo-grimoire's specification of Mojo is literate Lean, rendered with Verso
(ADR-2026-11-15-2030). Its formal content is the Lean modules of the package
`mojo-grimoire` in [`lean/`](../../lean); this directory is the Verso
document that renders them, with prose in the style of the WebAssembly
specification. [`MojoSpec.lean`](MojoSpec.lean) gives the order of the
chapters and the prose that belongs to no definition. Once GitHub Pages is
enabled, every push to `main` publishes it
([publishing the site](../decisions/spec.md#publishing-the-site)).

## Readable blocks

Each section shows a readable block in place of each declaration, and hides
the Lean under it in a `<details>`. The blocks of the module
`MojoGrimoire.X.Y` are the Verso document `MojoSpec/X/Y.lean`, which
[`MojoSpec/ReadableDocs.lean`](MojoSpec/ReadableDocs.lean) imports, and
`MojoSpec.lean` renders the section with
`{includeReadable "." MojoGrimoire.X.Y "Title" MojoSpec.X.Y (level := 2)}`.
[`MojoSpec/Reference.lean`](MojoSpec/Reference.lean) is the first example.

A block names the declarations it explains, pins with `(pin := …)` each
further definition its prose restates, and pins their fingerprint:

```
:::readable MojoGrimoire.referenceMojo (pin := MojoGrimoire.MojoVersion) (fingerprint := "…")
*Definition: the reference release.* ...
:::
```

The build fails when a declaration's statement, body, fields or
constructors change, printing the new signatures and fingerprint: read the
block again against the Lean, correct it, then pin the new fingerprint. It
also fails when a declaration of the module has no block, when a
```` ```grammar ```` box misses a constructor or shows one twice, when a
module's `:::moduleDocs (fingerprint := "…")` pin is stale, and when a module
under `lean/MojoGrimoire` has no section
([the checks](../decisions/spec.md#checks-that-keep-the-prose-true-to-the-lean)).

To add a module: write its document under `MojoSpec/`, import it in
`MojoSpec/ReadableDocs.lean`, add its `{includeReadable}` line to
`MojoSpec.lean`, build once with `"0"` as every fingerprint, and pin the
values the build prints after reading each block against the Lean.

## Appendix and build

The document ends with an appendix that renders every ADR in
[`docs/adrs/`](../adrs), and every ADR citation in the spec and the ADRs
links to the ADR's page. The library in [`MojoSpecSite/`](MojoSpecSite) adds
both when `mojospec` renders the document, and the build fails, naming the
file and line, on a citation of an ADR that does not exist
([the ADR appendix](../decisions/spec.md#the-adr-appendix-and-its-citations)).

```sh
scripts/build-spec.sh            # writes docs/spec/_out/html-multi/index.html
scripts/build-spec.sh --update   # for a toolchain bump: lake update, then build
```

The first build compiles Verso and takes a while; later builds reuse it.
