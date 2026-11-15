import VersoManual
import MojoGrimoire.Check.Expr
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Expr`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Expressions and arguments: readable blocks" =>

:::moduleDocs (fingerprint := "16874973772176836938")
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.Access.canChange MojoGrimoire.Check.requireMutable (fingerprint := "8302185228131285645")
*Definition: places that may change.* A function may change a place, by
assigning to it or passing it `mut`, unless its variable is a `read` or
`ref` parameter, or a reference that may not be changed.
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.transferPlace (fingerprint := "15204379235399540026")
*Rule: reading and moving a place.* Using a place $`p` as a value copies it
implicitly: $`p` must be initialized, and its type implicitly copyable.
Transferring it, $`p\,\hat{}`, needs $`p` initialized and a variable
that the function may change, owned or held `mut`; afterwards $`p` is
uninitialized. An element of a list cannot be transferred out, nor can a
value through a reference.
:::

:::readable MojoGrimoire.Check.binaryTy MojoGrimoire.Check.unaryTy (fingerprint := "1780888884152816192")
*Rule: operators.* Arithmetic takes two $`\mathsf{Int}` and gives an
$`\mathsf{Int}`; $`<`, $`\le`, $`>` and $`\ge` take two
$`\mathsf{Int}` and give a $`\mathsf{Bool}`; $`==` and $`!=` take
two values of the same type, $`\mathsf{Int}` or $`\mathsf{Bool}`, and
give a $`\mathsf{Bool}`; $`\mathsf{and}` and $`\mathsf{or}` take
and give $`\mathsf{Bool}`. Negation takes an $`\mathsf{Int}`, and
$`\mathsf{not}` a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.constInt (fingerprint := "15094168963797231555")
*Definition: constant indices.* An index made only of integer literals,
negation, $`+`, $`-` and $`\times` has a value that Mojo computes when it
compiles the program.
:::

:::readable MojoGrimoire.Check.overlaps MojoGrimoire.Check.locationArgs MojoGrimoire.Check.checkExclusive MojoGrimoire.Check.checkExclusive.go (fingerprint := "15076359769503551250")
*Rule: argument exclusivity.* Two places overlap when they have the same
variable and one path is a prefix of the other. The arguments of a call
that are passed as locations are the places whose parameters are `read`,
`mut` or `ref`, and the receiver of a method unless its `self` is
`var`. A call is rejected when a location passed `mut` overlaps another
location of the same call, unless it is an $`\mathsf{Int}` or a
$`\mathsf{Bool}`, which Mojo passes by copy. A reference overlaps what its
origins overlap.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "12400455311882201308")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`.
:::

:::readable MojoGrimoire.Check.refResult MojoGrimoire.Check.checkExprAs MojoGrimoire.Check.checkArgs MojoGrimoire.Check.checkIndices MojoGrimoire.Check.checkExpr (fingerprint := "12024872483503844693")
*Rule: expressions.* An expression is checked from left to right, and has a
type:

* a literal has its type, but a string literal is rejected outside
  `print`;
* $`p` is copied implicitly, $`p\,\hat{}` transferred, and
  $`p.\mathsf{copy}()` needs an initialized place of a copyable type;
* $`f(e^*)` constructs the struct $`f` with the parameters of its
  `__init__` after `self`, or with one `var` parameter per field if it
  is `@fieldwise_init`, and is rejected if it has neither; otherwise it
  calls the function $`f`;
* $`p.m(e^*)` passes $`p` by the convention of the method's `self`,
  then the other arguments;
* operators have the types above;
* $`[e^*]_t` passes each element as to a `var` parameter of type $`t`;
* on a list, the only method is `append`, which needs a list the function
  may change and takes its argument as `var`; `len(e)`, when the program
  declares no function `len`, takes a list and gives an $`\mathsf{Int}`.

Every index in a place is checked first, and must be an $`\mathsf{Int}`;
a constant index may not be negative.
A call of a function that returns a reference gives the value it points to,
which must be implicitly copyable, unless the call is bound with `ref`.

The arguments of a call are checked in order against the parameters, after
the exclusivity rule: a place by `passPlace`, and any other expression by
its type, which must be the parameter's; a `mut` parameter needs a place.
The numbers of arguments and parameters must be equal.
:::
