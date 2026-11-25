import VersoManual
import MojoGrimoire.Parse.Compared
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Compared`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Expected types of literals: readable blocks" =>

:::moduleDocs (fingerprint := "2793904399368221008")
:::

:::readable MojoGrimoire.Parse.openLiteralTy MojoGrimoire.Parse.elemExpected (fingerprint := "17740833371835876722")
*Definition: expected types.* A literal expected to have a list type or an
array type has that type, which the checker compares with its elements;
otherwise its elements decide. Its elements are expected to have its
element type.
:::

:::readable MojoGrimoire.Parse.foldable (fingerprint := "1995746572076948755")
*Definition: a literal that stays.* An expression made only of literals,
negations, `not` and binary operators, or of a literal
$`[e]_{\mathsf{Int}}` of one, reads no place and calls nothing. A literal
$`[e]` of type $`\mathsf{Int}` that holds one stays a literal, so that the
checker does not compute an index from it, as Mojo does not (#103).
:::

:::readable MojoGrimoire.Parse.TyEnv.leafTy MojoGrimoire.Parse.TyEnv.literalFit MojoGrimoire.Parse.TyEnv.heldCopy MojoGrimoire.Parse.converts (fingerprint := "14857081779414229261")
*Rule: the fit of a compared literal.* The literal is inferred once with
no type expected, so that an operator or a call of a struct in it is a
call of the method it calls. An element of it then has the type its form
gives, as the checker's `operandTy` gives it: a literal's constant, a
place's declared type, the result of a call or a method call that the
program declares, and a built-in operator's result; a literal, a call of
a name that a variable hides, and a call the program does not declare,
but `len`, have none. From these, a literal fits the type of the operand
it is compared with or not, as the checker decides it
(`MojoGrimoire.Check.literalFits`), when the comparison converts a
literal to it, on the left only when the comparison conforms
(`MojoGrimoire.Check.convertsTo`). A comparison with a literal that
holds a place whose value is not implicitly copyable, as the checker's
`MojoGrimoire.Check.heldCopy` finds it, keeps the expectations it had
before #166.
:::

:::readable MojoGrimoire.Parse.TyEnv.retype MojoGrimoire.Parse.TyEnv.retypeList MojoGrimoire.Parse.TyEnv.compared (fingerprint := "12263387979191851559")
*Rule: a compared literal's type.* A literal that fits the type $`t` of
the operand it is compared with takes $`t`, and so does one on the right
of $`==` or $`!=` of a list whose fit is not known (#185). Inference does
not infer it again: it gives each literal in it the type expected of it,
as the rules of literals say, and the elements that are no literals stay
as inferred, since no type is expected of them. Otherwise the literal
keeps what inference gave it with no type expected (#166).
:::
