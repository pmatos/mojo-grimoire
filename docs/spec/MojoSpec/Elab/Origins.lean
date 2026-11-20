import VersoManual
import MojoGrimoire.Elab.Origins
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Origins`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The origins of references: readable blocks" =>

:::moduleDocs (fingerprint := "309407173084607407")
:::

:::readable MojoGrimoire.Elab.TyEnv MojoGrimoire.Elab.placeTyOf MojoGrimoire.Elab.refCallee (fingerprint := "3982555203705002604")
*Definition: callees.* Elaboration follows the types of the variables
declared so far, to find the type of a place, $`p\,\hat{}` having the
type of $`p`, and so the signature of the method a call names. A call's signature, that of a function, of a
struct's construction or of a method, comes with its arguments, the
receiver of a method first.
:::

:::readable MojoGrimoire.Elab.locSlots MojoGrimoire.Elab.originArgs MojoGrimoire.Elab.refSlots (fingerprint := "13856677653426913393")
*Definition: what a reference points into.* A reference to a place points
into the slots that the place touches; one returned by a call, into the
slots that the arguments passed to the parameters its origin names point
into, the receiver of a method first: a place's, or, for a call that
returns a reference in turn, its own. A signature with no
origin, such as a struct's construction, points into nothing. The
reference has the type of the place, or the result type of the call.
:::

:::readable MojoGrimoire.Elab.addAlias MojoGrimoire.Elab.aliasStmt MojoGrimoire.Elab.aliasBlock MojoGrimoire.Elab.slotsOf (fingerprint := "14262126315433238538")
*Definition: the references of a body.* A pass through the body, in order,
records each `ref` binding with the slots it may point into, so that a
reference bound to another reference points into the same slots. Two
references of the same name in sibling blocks share one entry, with the
slots of both. The pass also records the type of each variable, starting
from the parameters', to find the methods that calls name.
:::

:::readable MojoGrimoire.Elab.callModes MojoGrimoire.Elab.methodModes (fingerprint := "15740976577910938643")
*Definition: operands passed by value.* A place passed to a `var`
parameter, or an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read`
one, is passed by value: the call reads it once its arguments are
evaluated. Any other place is passed by reference, and used until the call
returns. The signature of what is called gives each parameter's
convention, so a `@fieldwise_init` struct takes its fields by value,
`append` its list by reference and its element by value, and `pop` its
list by reference and its index by value. `len`, which has no signature,
takes its list by reference, and the standard library's `range` its
$`\mathsf{Int}`s by value (#121). A method's receiver is passed by value only
to a `var self`; the receiver's type, from the variables declared so far,
gives the method.
:::
