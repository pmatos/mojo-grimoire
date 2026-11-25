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

:::moduleDocs (fingerprint := "9341555976297903983")
:::

:::readable MojoGrimoire.Check.binaryMethod MojoGrimoire.Check.reflectedMethod MojoGrimoire.Check.unaryMethod (fingerprint := "14078108206647463870")
*Definition: the method of an operator.* $`a + b` calls `__add__` on
$`a`, and likewise `__sub__`, `__mul__`, `__floordiv__` and `__mod__`
for $`-`, $`\times`, `//` and `%`; $`<`, $`\le`, $`>`, $`\ge`, $`==`
and $`!=` call `__lt__`, `__le__`, `__gt__`, `__ge__`, `__eq__` and
`__ne__`. The reflected method of a binary operator, called on its right
operand, is `__radd__`, `__rsub__`, `__rmul__`, `__rfloordiv__` and
`__rmod__` for $`+`, $`-`, $`\times`, `//` and `%`; `__gt__`, `__ge__`,
`__lt__` and `__le__` for $`<`, $`\le`, $`>` and $`\ge`; and `__eq__`
and `__ne__` for $`==` and $`!=`. Negation calls `__neg__`, and
$`\mathsf{not}`, $`\mathsf{and}` and $`\mathsf{or}` call `__bool__` on
each operand.
:::

:::readable MojoGrimoire.Check.hasMethod (fingerprint := "10449175719696369603")
*Definition: the methods of a type.* Of the methods that operators and
calls need, an $`\mathsf{Int}` has every one but `__call__`. A
$`\mathsf{Bool}` has the comparisons and `__bool__`, and no arithmetic
or negation. A list has `__add__`, `__mul__`, `__eq__`, `__ne__` and
`__bool__`. An array has the comparisons only. A struct has the methods
it declares; those its traits supply are not yet modelled (#194). `None`
has none, nor has $`?`. A string literal, which is only printed, is
taken to have them all: the model claims nothing of it.
:::

:::readable MojoGrimoire.Check.overloaded MojoGrimoire.Check.intLiteral (fingerprint := "14804267025960426371")
*Definition: methods with several overloads.* Of the methods the model
calls, a list's `pop` has several overloads, and so has `__getitem__`
of a list or an array, which an index calls. Their misfits are
`noMatchingMethod`. An index of an $`\mathsf{Int}` reports its misfit as
an ordinary call does. An integer literal, or an expression made only of
them, negation and arithmetic, has the type `IntLiteral`, whose operators
have several overloads too.
:::

:::readable MojoGrimoire.Check.operandTy MojoGrimoire.Check.operandTy.formTy MojoGrimoire.Check.operandTy.sameTy (fingerprint := "16582612392293717366")
*Definition: the type of an operand from its form.* The type of an
operand is found, without checking or reading it, from its form: a
literal's, a place's type, the result of the function, struct or method
it calls, an $`\mathsf{Int}` for the built-in `len` that nothing hides,
the result of its operator, or, for $`\mathsf{and}` and $`\mathsf{or}`
on operands whose forms give the same struct type, that type (#191), an
array of its first element's type for a
literal with no type expected each of whose elements' forms gives that
type (one whose element's form gives none, or another type, is left to
checking), a list or an array literal's type, an $`\mathsf{Int}` for $`[e]` of type $`\mathsf{Int}`, and
$`\mathsf{List}[u]` for $`\mathsf{List}[u](\ldots)`. As `main` typed
them, $`\mathsf{and}` and $`\mathsf{or}` give a $`\mathsf{Bool}` at any
depth when asked to (`MojoGrimoire.Check.mainFormTy`). A call of a name
that a variable hides, and any other form, gives none, and so does a
lookup that fails: checking the operand then reports why.
:::

:::readable MojoGrimoire.Check.lacks MojoGrimoire.Check.unaryMisfit (fingerprint := "8538711511074234144")
*Rule: a method that an operand's type lacks.* An operand whose type is
known and lacks the method $`m` is `missingMethod` of that type and
$`m`. A unary operator's misfit is that its operand's type lacks the
operator's method (#176); a binary operator's is `binaryMisfit`'s, with
the comparisons of arrays and lists
(`MojoGrimoire.Check.Compare`).
:::

:::readable MojoGrimoire.Check.lenMisfit MojoGrimoire.Check.lenCall (fingerprint := "812077125582950664")
*Rule: a call of `len`.* The built-in `len` takes one list, array or
$`\mathsf{Int}`, a SIMD vector of width 1, and gives an $`\mathsf{Int}`.
A string is left to the check of a string outside `print`. Any other type,
a $`\mathsf{Bool}`, `None` or a struct, fits none of its overloads:
`noMatchingInit` of that type (#190). The model ignores a struct's
`Sized` conformance, which the compiler accepts (#230). The misfit is
found from the argument's form once the arguments are typed, so that an
error inside one comes first, and again from its checked type once it is
read. Any other number of arguments is `noMatchingInit` of $`?`, once
they are typed.
:::

:::readable MojoGrimoire.Check.methodCall (fingerprint := "13453130389364436081")
*Rule: a method call.* A call $`p.m(e^*)` of a method of signature
$`\mathit{sig}`, once the indices of $`p` are checked, takes the method's
receiver by its convention: $`p` is passed as a place, or, when $`p` is
$`q\hat{}` and `self` is `var`, $`q` is consumed once the arguments are
read. The arguments' own expressions come before any misfit, the
receiver is passed before the arguments are matched, and the receiver
and the location arguments must not alias a mutable one, which is
checked last (`callOrder`). The receiver and the arguments are
checked with the fit
`overload m` when the method has several overloads, `pop` of a list, so
that every misfit, a wrong number of arguments or a receiver that may not
change included, is `noMatchingMethod` (#88, #169), and as an ordinary
call otherwise. The
receiver and the arguments are checked again once all are read, and so
is what a literal argument reads late (`recheckLiterals`, #282); the
places the call changes are changed, and the call gives its result.
:::

:::readable MojoGrimoire.Check.methodUnaryTy (fingerprint := "3940445427345741236")
*Rule: the result of a unary operator, once its operand is checked.* A
method that the operand's type lacks is `missingMethod`; otherwise the
result is `unaryTy`'s.
:::

:::readable MojoGrimoire.Check.rejectAfter MojoGrimoire.Check.rejectMisfit (fingerprint := "15010750981306176417")
*Rule: an error found from types.* An error found from the types of
operands, before they are read, is reported once the operands are typed
in the type phase (`inTypePhase`): an error inside an operand, which the
compiler finds as it types it, comes first, and an error of a later
phase, such as a read of an uninitialized value, comes after it.
:::

:::readable MojoGrimoire.Check.callOrder MojoGrimoire.Check.arityMisfit (fingerprint := "6007945752370457372")
*Rule: the order inside a call.* The compiler reports a call's errors in
this order (#89, #96 part 9): each argument's own expression, in full,
left to right, the errors of a call nested in it included; the number of
arguments; each argument's type and mutability, left to right, the
receiver of a method first; the implicit copies; and the exclusivity of
the arguments passed by reference, which the caller checks after. The
checker checks the arguments in one pass and puts its errors in that
order where they meet. When the check fails with an error of the type
phase, the arguments' own expressions are typed first, and an error
inside one comes first. A wrong number of arguments comes before any
argument is matched (`arityMisfit`). When an argument fails with an
implicit copy, the arguments are checked again from the same state
without copies (`copyChecks`), and a misfit that this finds comes
first.
:::

:::readable MojoGrimoire.Check.rejectNoneCopy (fingerprint := "15599202572189854255")
*Rule: no copy of `None`.* $`p.\mathsf{copy}()` with $`p` of type
$`\mathsf{None}` is an unknown attribute: `None` has no `.copy()`, and
the compiler says that it has no attributes as it types the call, before
it reads $`p` (#131). So $`p` is typed first, in the type phase; an
error found while typing it is left to the checks that follow, and the
state is restored.
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

:::readable MojoGrimoire.Check.requireInPlace (fingerprint := "2635740280216961138")
*Rule: an in-place operator on a struct.* A call of a struct's
`__iadd__`, `__isub__` or `__imul__`, which inference makes of
$`p \mathrel{+}= e`, $`p \mathrel{-}= e` or $`p \mathrel{\times}= e`,
needs a receiver $`p` that may change, once its indices are typed, before
the method is looked up and its arguments checked, whatever the convention
of the method's `self`:
`immutablePlace` otherwise, as the compiler reports it (#191).
:::
