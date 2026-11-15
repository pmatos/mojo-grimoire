import VersoManual
import MojoGrimoire
import MojoSpecSite.ReadableElab
import MojoSpec.ReadableDocs

open Verso.Genre Manual
open MojoSpecSite

set_option pp.rawOnError true

#doc (Manual) "The Mojo specification" =>

Mojo is a programming language in the Python family for systems and
accelerator programming. Mojo has no written specification: the open-source
Mojo compiler at a pinned release is the reference (ADR-2026-11-15-1907).
This document is mojo-grimoire's specification of Mojo, an executable,
proof-carrying semantics in Lean 4 whose fidelity to that compiler is
checked by differential testing.

The specification is literate Lean (ADR-2026-11-15-2030). Its formal content
is the Lean definitions of the package `mojo-grimoire` in the repository's
`lean/` directory, and the prose beside them explains them. This document
renders both from the same source on every change, so the readable
specification cannot drift from the formal one. Where the two seem to
disagree, the Lean definitions are normative.

Each section shows each Lean declaration as a readable block: what it says,
in words and in mathematical notation, in the style of the WebAssembly
specification. The Lean, with its statements and proofs, is hidden under
each block and opens with a click. The build checks every block against the
Lean it explains, and fails when the Lean changes under it
(ADR-2026-11-15-2030).

Readable blocks use the notation of the WebAssembly specification.
$`A ::= B \mid C` gives the alternatives of $`A`, one per row of a grammar
box. $`A^?` is an optional $`A`, and $`A^*` a possibly empty sequence of
$`A`. $`\epsilon` is the empty sequence, and $`|s|` the length of the
sequence $`s`.

The decisions behind the definitions are architecture decision records
(ADRs), cited by their ids, such as ADR-2026-11-15-1908. Each citation
links to the ADR in the appendix, which holds every ADR.

# The reference compiler

The model is tested against one release line of the Mojo compiler, and the
model, the conformance suite and the decision log name the same one.

{includeReadable "." MojoGrimoire.Reference "The reference release" MojoSpec.Reference (level := 2)}

# The core calculus

The core calculus is the subset of Mojo that Phase 1 models: structs and
their methods, the argument conventions, moves and copies, control flow and
`Int`. Its abstract syntax is designed in this project's own terms
(ADR-2026-11-15-1908).

{includeReadable "." MojoGrimoire.Core.Types "Names, types, conventions and operators" MojoSpec.Core.Types (level := 2)}

{includeReadable "." MojoGrimoire.Core.Syntax "Places, expressions and statements" MojoSpec.Core.Syntax (level := 2)}

{includeReadable "." MojoGrimoire.Core.Equality "Equality of terms" MojoSpec.Core.Equality (level := 2)}

{includeReadable "." MojoGrimoire.Core.Program "Functions, structs and programs" MojoSpec.Core.Program (level := 2)}

# Architecture decision records
%%%
tag := "adrs"
file := "adrs"
number := false
htmlToc := false
%%%

An architecture decision record, or ADR, records one decision about
mojo-grimoire: what was decided, why, and what was rejected. This appendix
holds every ADR in the repository's `docs/adrs/` directory, one page each,
rendered from its Markdown file when this document is built, so it matches
the commit named at the foot of each page.

An ADR's id is the UTC minute it was written, and the spec and the ADRs cite
it as `ADR-` followed by the id, such as ADR-2026-11-15-1902, which also says
how ids stay unique. Every citation links to the ADR's page. An accepted ADR
is edited in place when its decision changes, and git keeps its history. A
deleted ADR's id is never used again.
