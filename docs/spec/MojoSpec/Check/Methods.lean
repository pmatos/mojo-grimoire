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

:::moduleDocs (fingerprint := "4770595326657988530")
:::

:::readable MojoGrimoire.Check.binaryMethod MojoGrimoire.Check.unaryMethod (fingerprint := "10097334614036502845")
*Definition: the method of an operator.* $`a + b` calls `__add__` on
$`a`, and likewise `__sub__`, `__mul__`, `__floordiv__` and `__mod__`
for $`-`, $`\times`, `//` and `%`; $`<`, $`\le`, $`>`, $`\ge`, $`==`
and $`!=` call `__lt__`, `__le__`, `__gt__`, `__ge__`, `__eq__` and
`__ne__`. Negation calls `__neg__`, and $`\mathsf{not}`,
$`\mathsf{and}` and $`\mathsf{or}` call `__bool__` on each operand.
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

:::readable MojoGrimoire.Check.operandTy MojoGrimoire.Check.operandTy.formTy MojoGrimoire.Check.operandTy.sameTy (fingerprint := "2250277455228571407")
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

:::readable MojoGrimoire.Check.compares MojoGrimoire.Check.arrayCompare MojoGrimoire.Check.arrayCompare.conforms (fingerprint := "4263272370677617613")
*Definition: comparable arrays.* $`<`, $`\le`, $`>`, $`\ge`, $`==`
and $`!=` compare. Two arrays compare when their element type conforms
to `Comparable`, to order them, or to `Equatable`, for $`==` and $`!=`:
$`\mathsf{Int}`, $`\mathsf{Bool}` and arrays of them conform, `None`
does not, nor a list to order. An element type that holds a struct,
itself or through lists and arrays, is not modelled yet, since its
conformances come with #194, nor the equality of lists (#185): the
comparison keeps the rules it had before #166.
:::

:::readable MojoGrimoire.Check.arrayMisfit (fingerprint := "2923997297340939390")
*Rule: the misfit of a comparison of arrays.* When one operand of a
comparison is an array that compares, an operand of another type is a
type mismatch, as the compiler cannot convert it: the right one when the
left is such an array, and the array when the left is an
$`\mathsf{Int}` or a $`\mathsf{Bool}`. Two arrays of the same type
whose element type does not conform are `violatedConstraint` of their
type and the operator's method (#166).
:::

:::readable MojoGrimoire.Check.lacks MojoGrimoire.Check.binaryMisfit MojoGrimoire.Check.unaryMisfit (fingerprint := "27817254171827405")
*Rule: a method that an operand's type lacks.* An operator whose left
operand's type is known and lacks the operator's method is
`missingMethod` of that type and method. For $`\mathsf{and}` and
$`\mathsf{or}`, so is a right operand whose type lacks `__bool__`, and
for a unary operator its operand's (#176). A binary operator's misfit is
then that of a comparison of arrays (`arrayMisfit`).
:::

:::readable MojoGrimoire.Check.holdsLiteral MojoGrimoire.Check.convertsLiteral MojoGrimoire.Check.operandMisfit MojoGrimoire.Check.byRef (fingerprint := "12862265436166846129")
*Rule: operands of a comparison of arrays.* The misfit of a binary
operator is found from its operands' forms before they are read
(`operandTy`). An integer literal on the left gives no type, so that its
overloads report a comparison with an array (`noMatchingMethod`), and an
empty literal on the right of a comparison has a type that fits no array.
A literal compared with a list, which the compiler converts to a list, is
left to the checks that follow, as before #166, and so is a literal that
holds a literal compared with an operand whose type its form does not
show to be the same, which the compiler converts element by element (part
2 of #166): its operands are not passed by reference either. Any other
operand compared as an array is passed by reference, as `Array`'s comparisons take a `read`
argument: a place, or a call that returns a reference, is read, uncopied.
:::

:::readable MojoGrimoire.Check.lenMisfit MojoGrimoire.Check.lenCall (fingerprint := "3344581529509980139")
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

:::readable MojoGrimoire.Check.methodCall (fingerprint := "14781180816628587386")
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

:::readable MojoGrimoire.Check.methodBinaryTy MojoGrimoire.Check.methodUnaryTy (fingerprint := "7067538993756540430")
*Rule: the result of an operator, once its operands are checked.* A
method that an operand's type lacks is `missingMethod`, and a comparison
of arrays that does not fit is its misfit, found again from the checked
types; otherwise a comparison of arrays gives a $`\mathsf{Bool}`, and
any other operator's result is `binaryTy`'s or `unaryTy`'s.
:::

:::readable MojoGrimoire.Check.rejectAfter MojoGrimoire.Check.rejectMisfit (fingerprint := "6081766398198932002")
*Rule: an error found from types.* An error found from the types of
operands, before they are read, is reported once the operands are typed
in `State.typing`: an error inside an operand, which the compiler finds as
it types it, comes first, and an error of a later pass than typing, such
as a read of an uninitialized value, comes after it.
:::

:::readable MojoGrimoire.Check.rejectNoneCopy (fingerprint := "4407985107055440063")
*Rule: no copy of `None`.* $`p.\mathsf{copy}()` with $`p` of type
$`\mathsf{None}` is an unknown attribute: `None` has no `.copy()`, and
the compiler says that it has no attributes as it types the call, before
it reads $`p` (#131). So $`p` is typed first, in `State.typing`; an
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

:::readable MojoGrimoire.Check.requireInPlace (fingerprint := "18000915414203633187")
*Rule: an in-place operator on a struct.* A call of a struct's
`__iadd__`, `__isub__` or `__imul__`, which inference makes of
$`p \mathrel{+}= e`, $`p \mathrel{-}= e` or $`p \mathrel{\times}= e`,
needs a receiver $`p` that may change, once its indices are typed, before
the method is looked up and its arguments checked, whatever the convention
of the method's `self`:
`immutablePlace` otherwise, as the compiler reports it (#191).
:::
