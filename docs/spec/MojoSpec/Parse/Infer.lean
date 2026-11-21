import VersoManual
import MojoGrimoire.Parse.Infer
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Infer`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Type inference: readable blocks" =>

:::moduleDocs (fingerprint := "6304605100111211501")
:::

:::readable MojoGrimoire.Parse.foldable (fingerprint := "1995746572076948755")
*Definition: a literal that stays.* An expression made only of literals,
negations, `not` and binary operators, or of a literal
$`[e]_{\mathsf{Int}}` of one, reads no place and calls nothing. A literal
$`[e]` of type $`\mathsf{Int}` that holds one stays a literal, so that the
checker does not compute an index from it, as Mojo does not (#103).
:::

:::readable MojoGrimoire.Parse.inferPlace MojoGrimoire.Parse.inferExpr MojoGrimoire.Parse.inferArgs MojoGrimoire.Parse.inferArg MojoGrimoire.Parse.inferList (fingerprint := "390141909449305385")
*Definition: the types of places and expressions.* A variable has its
declared type, a field the type its struct declares, and an element the
element type of its list or array, or $`\mathsf{Int}` for the element of
an $`\mathsf{Int}` (#127), and $`p\,\hat{}` the type of $`p`. A literal has its own type, and
`p.copy()` the type of $`p`. A negation gives an $`\mathsf{Int}`, `not` a
$`\mathsf{Bool}`, and a binary operator the type of its result, as above.
A call or a method call
has the result of its signature. A call of a struct that cannot be built
still has the struct's type, so that the checker reports why, and `len`
gives an $`\mathsf{Int}`. A call of `range`, when the program declares no
function or struct `range`, expects an $`\mathsf{Int}` of each argument, by
`rangeParams` (#121). A call of a name that a variable in scope hides
follows no signature and has no type, so that the checker rejects it
(#176), unless the variable's struct declares `__call__`. An operator, a
subscript read as a value and a call whose operand is a struct that
declares the method are calls of the method that `chooseBinary` and
`declaredMethod` pick, with the type of its result: a subscript calls
`__getitem__`, its index expected to have the type of the getter's
parameter; an
operand that is a literal is inferred as an argument of the method's
other parameter, by `inferArg`, so that one passed `mut` or `ref` stays a
temporary (#191). `not` on a struct negates what its `__bool__` gives, and
`and` and `or` convert each struct operand with `__bool__` (`toBool`),
unless both have the same struct type, which the operator then gives
(#191). Any other call with no signature has no type. A literal left open takes the type expected where
it stands, a list type or an array type, and the checker compares an
array's size with the literal's length. With no list or array expected, it is
an array of its elements, of the type of the first: Mojo's
$`\mathsf{Array}[t, n]`. Inference gives that type to what holds the
literal, and leaves the literal's own type $`?`, so that the checker
tells it from a literal that initializes an expected type (#46).
A literal $`[e]` left open where an $`\mathsf{Int}` is expected, whose one
element has the type $`\mathsf{Int}` when it is expected to, is an
$`\mathsf{Int}` (#103): $`e` itself, which Mojo reads as that operand, or,
when $`e` is `foldable`, $`[e]_{\mathsf{Int}}`. The arguments of a call,
by `inferArgs`, keep a literal passed `mut` or `ref` as
$`[e]_{\mathsf{Int}}`: Mojo passes a temporary there, not the place or the
reference $`e` names, so `mut` rejects it, and `ref` gets a temporary
filled from $`e` when the call is made, which a returned reference keeps,
so it does not see a later change (#103). A place passed `mut` or `ref`
stays a place: a subscript of a struct there is not read through its
getter (#198). A literal of any other
length left open where an $`\mathsf{Int}` is expected is
$`[e^*]_{\mathsf{Int}}`, of type $`\mathsf{Int}`, with an
$`\mathsf{Int}` expected of each element, as SIMD's initializer takes
them; the checker rejects it (#153, #154). A function that returns
a reference expects no type of the values it returns. An index is expected to be
an $`\mathsf{Int}`, and so is either operand of an operator other than
`and` and `or` whose other operand is an $`\mathsf{Int}`, as Mojo reads it
(#160). The right operand of $`==` or $`!=` whose left operand is a list
is expected to have the list's type, as the argument of its `__eq__` or
`__ne__` (#185). Each
operand that is not a literal is inferred first, with no type expected,
and a literal operand once, with $`\mathsf{Int}` or the list's type
expected when the rules above say so.
$`\mathsf{List}[u](e^+)` is a list of $`u`, whose arguments are expected
to have no type. Its one argument $`p\,\hat{}` becomes the place
$`p\,\hat{}`, which Mojo borrows, since the initializer takes it by `ref`
(#103). The elements of a literal are expected to have its
element type, and the arguments of a call the types of its parameters; the
argument of `append` is expected to be an element of the list, and the
index of `pop(i)` an $`\mathsf{Int}`. The drops
that elaboration inserts have the type of their operation. Inference fills
in the literals inside an expression as it goes; where it finds no type,
it gives none. A transfer $`p\,\hat{}` of an $`\mathsf{Int}`, a
$`\mathsf{Bool}` or a $`\mathsf{None}` becomes the place $`p`, since Mojo does not move such a
value, wherever $`p` is: also an element of a list or an array, or a field
of one.
:::

:::readable MojoGrimoire.Parse.openLiteralTy MojoGrimoire.Parse.elemExpected MojoGrimoire.Parse.unsignedResult (fingerprint := "3606479627143958479")
*Definition: expected types.* A literal expected to have a list type or an
array type has that type, which the checker compares with its elements;
otherwise its elements decide. Its elements are expected to have its
element type. The arguments of a call or a method call are expected to
have the types of the parameters of its signature, for the number of
arguments of the call, and those of a call with no signature nothing. So
`append` takes an element of its list, `pop()` nothing and `pop(i)` an
$`\mathsf{Int}`, and a struct that cannot be built takes nothing. A call
with no signature has the type of a struct the program declares, `len`'s
$`\mathsf{Int}`, or none.
:::

:::readable MojoGrimoire.Parse.eagerValue (fingerprint := "4099641442443751981")
*Definition: the value of a setter.* The value $`v` of $`q[i] = v` is
read as it is evaluated, before the getters of the subscripts read late
in $`i`, as the compiler does: a subscript read late there is a call of
its getter as a method (#191).
:::

:::readable MojoGrimoire.Parse.inferTarget MojoGrimoire.Parse.inferStmt MojoGrimoire.Parse.inferBlock (fingerprint := "7720983360771632476")
*Definition: statements.* `var x = e` declares $`x` with the type of $`e`,
$`\mathsf{None}` for a call that returns nothing (#131),
and `ref x = e` binds $`x` with the type of $`e`; $`x` may change what
it points to when $`e`, once inferred, may (`TyEnv.mutableAt`), so also
when it is a call of a method or of `__call__` that returns a reference
through a `mut` parameter, or a place of a variable that may change, also
through $`q\,\hat{}`, whose transfer has no effect there (#191). An initial value is
expected to have the declared type of its variable, an assigned value the
type of the place it is assigned to, and a returned value the function's
result. The target of a `ref` binding, and the value a function that
returns a reference returns, keep a place as it is (`inferTarget`), so a
subscript of a struct there is not read through its getter (#198).
$`q[i] = e` on a struct that declares `__getitem__` and `__setitem__`
calls the setter, $`e` read by `eagerValue`; with a getter and no setter
it stays an assignment, which the checker rejects.
$`p \mathrel{\mathit{op}{=}} e` calls the in-place method of $`p`'s
struct (`inPlaceMethod`), which the checker reports when the struct lacks
it, and is otherwise `p = p op e`, with no method of $`e`'s struct
reflected. `print(…)` calls the `__call__` of a variable named `print`
whose struct declares one (#191). A block is
inferred in order, each statement seeing the variables declared before it;
the variables of an inner block do not leave it.
:::

:::readable MojoGrimoire.Parse.inferFun MojoGrimoire.Parse.inferStruct MojoGrimoire.Parse.inferProgram MojoGrimoire.Parse.inferRaw MojoGrimoire.Parse.parse (fingerprint := "18083049466737510802")
*Definition: parsing a program.* Inference starts each function from its
parameters, and each destructor from `self`. The values a function returns
are expected to have its result type, unless it returns a reference: then
none is expected, since a literal is no place. Parsing a program lexes and
parses its text, marks the types whose name a variable hides
(`markHidden`), replaces `Self` in each struct's methods (`resolveSelf`),
and then infers inside every declaration (`inferRaw`). It does not check
the constructs outside the subset, which the driver's `parseSubset` does.
:::
