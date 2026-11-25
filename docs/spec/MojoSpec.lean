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

{includeReadable "." MojoGrimoire.Reference "The reference version" MojoSpec.Reference (level := 2)}

# The core calculus

The core calculus is the subset of Mojo that Phase 1 models: structs and
their methods, the argument conventions, moves and copies, control flow and
`Int`. Its abstract syntax is designed in this project's own terms
(ADR-2026-11-15-1908).

{includeReadable "." MojoGrimoire.Core.Types "Names, types, conventions and operators" MojoSpec.Core.Types (level := 2)}

{includeReadable "." MojoGrimoire.Core.Syntax "Places, expressions and statements" MojoSpec.Core.Syntax (level := 2)}

{includeReadable "." MojoGrimoire.Core.Equality "Equality of terms" MojoSpec.Core.Equality (level := 2)}

{includeReadable "." MojoGrimoire.Core.Program "Functions, structs and programs" MojoSpec.Core.Program (level := 2)}

# The static checker

The static checker decides which programs of the core calculus Mojo
accepts: it checks types, the argument conventions and ownership, and
rejects a program with a class of error. Its classes, not its wording, are
compared with the compiler's diagnostics.

{includeReadable "." MojoGrimoire.Check.Errors "Errors" MojoSpec.Check.Errors (level := 2)}

{includeReadable "." MojoGrimoire.Check.Env "The program's tables" MojoSpec.Check.Env (level := 2)}

{includeReadable "." MojoGrimoire.Check.State "The checker's state" MojoSpec.Check.State (level := 2)}

{includeReadable "." MojoGrimoire.Check.Loc "Located operands" MojoSpec.Check.Loc (level := 2)}

{includeReadable "." MojoGrimoire.Check.Fit "Arguments that do not fit" MojoSpec.Check.Fit (level := 2)}

{includeReadable "." MojoGrimoire.Check.Change "Changes and late re-checks" MojoSpec.Check.Change (level := 2)}

{includeReadable "." MojoGrimoire.Check.Transfer "Reading and transferring" MojoSpec.Check.Transfer (level := 2)}
{includeReadable "." MojoGrimoire.Check.Pass "Checking helpers" MojoSpec.Check.Pass (level := 2)}

{includeReadable "." MojoGrimoire.Check.Operators "Operators" MojoSpec.Check.Operators (level := 2)}

{includeReadable "." MojoGrimoire.Check.Methods "Methods" MojoSpec.Check.Methods (level := 2)}

{includeReadable "." MojoGrimoire.Check.Compare "Comparisons" MojoSpec.Check.Compare (level := 2)}

{includeReadable "." MojoGrimoire.Check.Logic "The test of a struct operand" MojoSpec.Check.Logic (level := 2)}

{includeReadable "." MojoGrimoire.Check.Elems "Elements of literals" MojoSpec.Check.Elems (level := 2)}

{includeReadable "." MojoGrimoire.Check.Range "The arguments of range" MojoSpec.Check.Range (level := 2)}

{includeReadable "." MojoGrimoire.Check.Expr "Expressions and arguments" MojoSpec.Check.Expr (level := 2)}

{includeReadable "." MojoGrimoire.Check.Ref "References" MojoSpec.Check.Ref (level := 2)}

{includeReadable "." MojoGrimoire.Check.Subscript "Assigning a subscript of a struct" MojoSpec.Check.Subscript (level := 2)}

{includeReadable "." MojoGrimoire.Check.Exit "Ends, exits, joins and loops" MojoSpec.Check.Exit (level := 2)}

{includeReadable "." MojoGrimoire.Check.Stmt "Statements" MojoSpec.Check.Stmt (level := 2)}

{includeReadable "." MojoGrimoire.Check.Block "Blocks and the bridge to main's order" MojoSpec.Check.Block (level := 2)}

{includeReadable "." MojoGrimoire.Check.Program "Programs" MojoSpec.Check.Program (level := 2)}

# ASAP elaboration

Mojo destroys each value as soon as possible, right after its last use.
Elaboration makes those points explicit: it inserts a `drop` wherever the
compiler destroys a value, so that the interpreter destroys only what a
`drop` names and what remains when a function returns.

{includeReadable "." MojoGrimoire.Elab.Live "Uses, moves and liveness" MojoSpec.Elab.Live (level := 2)}

{includeReadable "." MojoGrimoire.Elab.Origins "The origins of references" MojoSpec.Elab.Origins (level := 2)}

{includeReadable "." MojoGrimoire.Elab.Late "Subscripts read late" MojoSpec.Elab.Late (level := 2)}

{includeReadable "." MojoGrimoire.Elab.Operands "What an operation destroys" MojoSpec.Elab.Operands (level := 2)}

{includeReadable "." MojoGrimoire.Elab.Elaborate "Inserting drops" MojoSpec.Elab.Elaborate (level := 2)}

{includeReadable "." MojoGrimoire.Elab.Strip "Elaboration only inserts drops" MojoSpec.Elab.Strip (level := 2)}

# The interpreter

The interpreter runs an elaborated program, step by step, with fuel: what
it prints, and how the run ends, is what the conformance suite compares
with the compiler.

{includeReadable "." MojoGrimoire.Interp.Value "Values" MojoSpec.Interp.Value (level := 2)}

{includeReadable "." MojoGrimoire.Interp.Machine "The machine" MojoSpec.Interp.Machine (level := 2)}

{includeReadable "." MojoGrimoire.Interp.Args "Arguments and operands" MojoSpec.Interp.Args (level := 2)}

{includeReadable "." MojoGrimoire.Interp.Eval "Evaluation" MojoSpec.Interp.Eval (level := 2)}

{includeReadable "." MojoGrimoire.Interp.Run "Running a program" MojoSpec.Interp.Run (level := 2)}

# The parser

The parser reads the text of a `.mojo` file into a program of the core
calculus: the lexer splits it into tokens and marks its indentation, the
parser builds the abstract syntax, and inference fills in the types that
the program leaves implicit. The driver runs the result from the command
line, as the compiler's `mojo run` does.

{includeReadable "." MojoGrimoire.Parse.Lexer "The lexer" MojoSpec.Parse.Lexer (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Parser "The parser's monad and types" MojoSpec.Parse.Parser (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Expr "Expressions" MojoSpec.Parse.Expr (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Stmt "Statements and declarations" MojoSpec.Parse.Stmt (level := 2)}

{includeReadable "." MojoGrimoire.Parse.HiddenTypes "Types that a variable hides" MojoSpec.Parse.HiddenTypes (level := 2)}

{includeReadable "." MojoGrimoire.Parse.SelfType "Self in methods" MojoSpec.Parse.SelfType (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Dispatch "Methods of operators on structs" MojoSpec.Parse.Dispatch (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Compared "Expected types of literals" MojoSpec.Parse.Compared (level := 2)}

{includeReadable "." MojoGrimoire.Parse.InferExpr "Type inference in expressions" MojoSpec.Parse.InferExpr (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Infer "Type inference" MojoSpec.Parse.Infer (level := 2)}

{includeReadable "." MojoGrimoire.Parse.Subset "Constructs outside the subset" MojoSpec.Parse.Subset (level := 2)}

{includeReadable "." MojoGrimoire.Driver.Main "The command-line driver" MojoSpec.Driver.Main (level := 2)}

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
