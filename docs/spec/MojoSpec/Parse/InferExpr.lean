import VersoManual
import MojoGrimoire.Parse.InferExpr
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.InferExpr`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Type inference in expressions: readable blocks" =>

:::moduleDocs (fingerprint := "12423167490377361527")
:::

:::readable MojoGrimoire.Parse.literalArg (fingerprint := "15594256188266583025")
*Definition: a literal argument.* Given the form that inference gave a
literal passed to a parameter, with the parameter's type expected, the
argument is that form; when the parameter is `mut` or `ref` and the
literal became an $`\mathsf{Int}`, it is put back in a literal, so that
it stays a temporary. It infers nothing itself, and its callers pass it
only the form of a literal.
:::

:::readable MojoGrimoire.Parse.lenConverted (fingerprint := "10627972790977335799")
*Definition: a literal converted for `len`.* Given the form and the type
of the first element of a literal passed to `len`, and a way to infer
its other elements given the types expected of them, the literal is
$`\mathsf{Array}[t, n]` of the first element's type $`t`, with $`t`
expected of each other element (#341). When the first element has no
type, as an empty literal, the literal stays open and nothing is
expected of the others.
:::

:::readable MojoGrimoire.Parse.inferPlace MojoGrimoire.Parse.inferExpr MojoGrimoire.Parse.inferArgs MojoGrimoire.Parse.inferArg MojoGrimoire.Parse.inferLenArgs MojoGrimoire.Parse.inferLenLiteral MojoGrimoire.Parse.inferList (fingerprint := "6759927460180264944")
*Definition: the types of places and expressions.* A variable has its
declared type, a field the type its struct declares, and an element the
element type of its list or array, or $`\mathsf{Int}` for the element of
an $`\mathsf{Int}` (#127), and $`p\,\hat{}` the type of $`p`. A literal has its own type, and
`p.copy()` the type of $`p`. A negation gives an $`\mathsf{Int}`, `not` a
$`\mathsf{Bool}`, and a binary operator the type of its result, as above.
A call or a method call
has the result of its signature. A call of a struct that cannot be built
still has the struct's type, so that the checker reports why, and `len`
gives an $`\mathsf{Int}`. Its one argument, when the program declares no
function or struct `len` and no variable hides it, is inferred by `inferLenArgs`: a
literal left open is converted as the compiler converts it to `len`'s
parameter, by `inferLenLiteral` (#341). Its first element is inferred
once, by this rule in turn when it is a literal left open, and the
literal is $`\mathsf{Array}[t, n]` of that element's type $`t`, which
each other element is expected to have (`lenConverted`). An empty
literal, or one whose first element is, has no type, and stays open. A call of `range`, when the program declares no
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
other parameter, as `inferArg` passes it (`literalArg`), so that one
passed `mut` or `ref` stays a temporary (#191). Such a literal is inferred
once with the type of the parameter that the choice of method tries, and
that inference is used again for the argument when the parameter is the
same, so that nested operators cost no more at each level. `not` on a
struct negates what its `__bool__` gives, and `and` and `or` convert each
struct operand with `__bool__` (`toBool`), unless both have the same
struct type, which the operator then gives (#191). Any other call with no signature has no type. A literal left open takes the type expected where
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
(#160). A literal compared with an array or a list is expected to have
that operand's type when it fits it: on the right, of the left operand,
and on the left, of a right operand that is no literal and whose
comparison conforms (#166), unless either operand is `List[u]()`, or a
literal that holds a place whose value is not implicitly copyable and
that the checker does not convert by its fit (`keepsBefore`, #338): such
a literal on the left that fits is converted, and one on the right,
beside an operand that is no literal, that does not fit keeps no type.
Beside a literal on the left, an array, the right one is expected to
have no type either way. The right operand of $`==` or $`!=` whose
left operand is a list is expected to have the list's type unless it
does not fit it, as the argument of its `__eq__` or `__ne__` (#185). Each
operand that is not a literal is inferred first, with no type expected,
and a literal operand once, with $`\mathsf{Int}` expected when the rules
above say so, and otherwise with no type expected, and then given the
other operand's type when the rules above say so (`TyEnv.compared`).
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

:::readable MojoGrimoire.Parse.unsignedResult (fingerprint := "9724387943405349278")
*Definition: expected types of arguments.* The arguments of a call or a
method call are expected to have the types of the parameters of its
signature, for the number of arguments of the call, and those of a call
with no signature nothing. So `append` takes an element of its list,
`pop()` nothing and `pop(i)` an $`\mathsf{Int}`, and a struct that cannot
be built takes nothing. A call with no signature has the type of a
struct the program declares, `len`'s $`\mathsf{Int}`, or none.
:::
