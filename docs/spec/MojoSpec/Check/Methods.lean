import VersoManual
import MojoGrimoire.Check.Methods
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Methods`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Methods: readable blocks" =>

:::moduleDocs (fingerprint := "11861127469728064369")
:::

:::readable MojoGrimoire.Check.binaryMethod MojoGrimoire.Check.unaryMethod (fingerprint := "10097334614036502845")
*Definition: the method of an operator.* $`a + b` calls `__add__` on
$`a`, and likewise `__sub__`, `__mul__`, `__floordiv__` and `__mod__`
for $`-`, $`\times`, `//` and `%`; $`<`, $`\le`, $`>`, $`\ge`, $`==`
and $`!=` call `__lt__`, `__le__`, `__gt__`, `__ge__`, `__eq__` and
`__ne__`. Negation calls `__neg__`, and $`\mathsf{not}`,
$`\mathsf{and}` and $`\mathsf{or}` call `__bool__` on each operand.
:::

:::readable MojoGrimoire.Check.hasMethod (fingerprint := "74535816480982210")
*Definition: the methods of a type.* Of the methods that operators and
calls need, an $`\mathsf{Int}` has every one but `__call__`. A
$`\mathsf{Bool}` has the comparisons and `__bool__`, and no arithmetic
or negation. A list has `__add__`, `__mul__`, `__eq__`, `__ne__` and
`__bool__`. An array has the comparisons only. A struct has the methods
it declares; those its traits supply are not yet modelled (#194). `None`
has none. A string literal, which is only printed, is
taken to have them all: the model claims nothing of it.
:::

:::readable MojoGrimoire.Check.overloaded MojoGrimoire.Check.intLiteral (fingerprint := "9175153237094737598")
*Definition: methods with several overloads.* Of the methods the model
calls, a list's `pop` has several overloads, and so has `__getitem__`
of a list or an array, which an index calls. Their misfits are
`noMatchingMethod`. An index of an $`\mathsf{Int}` reports its misfit as
an ordinary call does. An integer literal, or an expression made only of
them, negation and arithmetic, has the type `IntLiteral`, whose operators
have several overloads too.
:::

:::readable MojoGrimoire.Check.operandTy MojoGrimoire.Check.operandTy.formTy MojoGrimoire.Check.operandTy.sameTy (fingerprint := "16790746705646846013")
*Definition: the type of an operand from its form.* The type of an
operand is found, without checking or reading it, from its form: a
literal's, a place's type, the result of the function, struct or method
it calls, an $`\mathsf{Int}` for the built-in `len` that nothing hides,
the result of its operator, an array of its first element's type for a
literal with no type expected each of whose elements' forms gives that
type (one whose element's form gives none, or another type, is left to
checking), a list or an array literal's type, an $`\mathsf{Int}` for $`[e]` of type $`\mathsf{Int}`, and
$`\mathsf{List}[u]` for $`\mathsf{List}[u](\ldots)`. A call of a name
that a variable hides, and any other form, gives none, and so does a
lookup that fails: checking the operand then reports why.
:::

:::readable MojoGrimoire.Check.lacks MojoGrimoire.Check.binaryMisfit MojoGrimoire.Check.unaryMisfit (fingerprint := "15222351421749146837")
*Rule: a method that an operand's type lacks.* An operator whose left
operand's type is known and lacks the operator's method is
`missingMethod` of that type and method. For $`\mathsf{and}` and
$`\mathsf{or}`, so is a right operand whose type lacks `__bool__`, and
for a unary operator its operand's (#176).
:::

:::readable MojoGrimoire.Check.methodCall (fingerprint := "3090070374288288694")
*Rule: a method call.* A call $`p.m(e^*)` of a method of signature
$`\mathit{sig}`, once the indices of $`p` are checked, takes the method's
receiver by its convention: $`p` is passed as a place, or, when $`p` is
$`q\hat{}` and `self` is `var`, $`q` is consumed once the arguments are
read. The receiver and the location arguments must not alias a mutable
one. When a method with several overloads cannot be passed its
receiver, its arguments are typed first, so that an error inside one
comes before the receiver's misfit. The receiver and the arguments are
checked with the fit
`overload m` when the method has several overloads, `pop` of a list, so
that every misfit, a wrong number of arguments or a receiver that may not
change included, is `noMatchingMethod` (#88, #169), and as an ordinary
call otherwise. The
receiver and the arguments are checked again once all are read, the
places the call changes are changed, and the call gives its result.
:::

:::readable MojoGrimoire.Check.methodBinaryTy MojoGrimoire.Check.methodUnaryTy (fingerprint := "5771276043216569838")
*Rule: the result of an operator, once its operands are checked.* A
method that an operand's type lacks is `missingMethod`, found again from
the checked types; otherwise the operator's result is `binaryTy`'s or
`unaryTy`'s.
:::

:::readable MojoGrimoire.Check.rejectAfter MojoGrimoire.Check.rejectMisfit (fingerprint := "6081766398198932002")
*Rule: an error found from types.* An error found from the types of
operands, before they are read, is reported once the operands are typed
in `State.typing`: an error inside an operand, which the compiler finds as
it types it, comes first, and an error of a later pass than typing, such
as a read of an uninitialized value, comes after it.
:::

:::readable MojoGrimoire.Check.rejectCalledVar (fingerprint := "3043078157478825986")
*Rule: a called variable.* Within the scope of a variable or a
parameter, its name is the variable, also before it is initialized: a
call $`f(e^*)` where $`f` names one hides the function, `len`, `range`,
`print` or the struct $`f`. A variable whose type has no `__call__` cannot be
called: `missingMethod` of its type and `__call__`, once the arguments
are typed, since the compiler types them first (#176). A variable whose
struct type declares `__call__` never reaches this rule: inference makes
the call one of the method (#191).
:::

:::readable MojoGrimoire.Check.requireInPlace (fingerprint := "18000915414203633187")
*Rule: an in-place operator on a struct.* A call of a struct's
`__iadd__`, `__isub__` or `__imul__`, which inference makes of
$`p \mathrel{+}= e`, $`p \mathrel{-}= e` or $`p \mathrel{\times}= e`,
needs a receiver $`p` that may change, once its indices are typed, before
the method is looked up and its arguments checked, whatever the convention
of the method's `self`:
`immutablePlace` otherwise, as the compiler reports it (#191).
:::
