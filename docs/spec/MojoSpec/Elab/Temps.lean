import VersoManual
import MojoGrimoire.Elab.Temps
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Temps`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Temporaries of returned references: readable blocks" =>

:::moduleDocs (fingerprint := "17264293641758289773")
:::

:::readable MojoGrimoire.Elab.envAfter (fingerprint := "3023937792142485577")
*Definition: the types after a statement.* The types of the variables
after a statement, which a declaration or a `ref` binding extends.
:::

:::readable MojoGrimoire.Elab.isTempArg MojoGrimoire.Elab.tempParams MojoGrimoire.Elab.Temps MojoGrimoire.Elab.wrapTemp (fingerprint := "5783578503431332955")
*Definition: a temporary origin argument.* An argument passed to a
parameter that the callee's origin names is a temporary when it is neither
a place nor a call of a function or a method that returns a reference. A
subscript that Mojo reads late (`lateGetter`, #191) is left as it is: it
is read once its call's arguments are evaluated, and so it is destroyed when
its call returns, as before. It
gets a hidden variable when the parameter's type is dropped: a struct, or a
list or an array of structs. Values of the other types cannot be seen being
destroyed. The `k`th temporary of a body is the place `tempName k`,
and `wrapTemp` replaces the argument with `temp (tempName k) a'`. Here `a'`
is the argument with its own temporaries named, and it records `k` and the
parameter's type.
:::

:::readable MojoGrimoire.Elab.tempExpr MojoGrimoire.Elab.tempArgs (fingerprint := "4693535660862386531")
*Definition: naming the temporaries of an expression.* The walk follows the
order of evaluation: the operands and arguments in order, and inside each
argument before the argument itself. A call or a method call that returns
a reference passes its arguments through `wrapTemp` with the parameters
that `tempParams` gives, from its signature (`refCallee`). Every other
expression is rebuilt as it is. A place is left as it is, indices and all:
elaboration does not look inside an index, so a temporary there would
never be dropped, and it keeps the old lifetime instead (#377). The
temporaries are recorded the last made first, and declared in the order
they are made.
:::

:::readable MojoGrimoire.Elab.tempDecls MojoGrimoire.Elab.withTemps MojoGrimoire.Elab.tempStmt MojoGrimoire.Elab.tempBlock (fingerprint := "10517432367083144952")
*Definition: naming the temporaries of a body.* Each statement is preceded,
in its own block, by the declarations with no value of the hidden variables
of the temporaries in its expressions, in the order they are made. That
includes the condition of an `if` or a `while`. The blocks a statement holds
name their own temporaries. Numbers run on through the body, so that each
hidden variable is declared once. Each declaration kills its slot for
liveness. On each iteration of a loop the body declares its temporaries
again, so that none of them lives across the back edge.
:::

:::readable MojoGrimoire.Elab.tempsIn MojoGrimoire.Elab.tempsList (fingerprint := "10168246435410966908")
*Definition: the temporaries of an expression.* These are the hidden
variables that the `temp` expressions in an expression name; none is in
the index of a place. A `while` loop keeps the temporaries of
its condition out of the slots live at its head: each run of the condition
makes them and destroys them again.
:::
