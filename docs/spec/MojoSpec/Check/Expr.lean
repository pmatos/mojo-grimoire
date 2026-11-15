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

:::moduleDocs (fingerprint := "18412038547163670720")
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.Access.canChange MojoGrimoire.Check.requireMutable (fingerprint := "1009883049977035658")
*Definition: places that may change.* A function may change a place, by
assigning to it or passing it `mut`, unless its variable is a `read` or
`ref` parameter.
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.transferPlace (fingerprint := "12997164720872610445")
*Rule: reading and moving a place.* Using a place $`p` as a value copies it
implicitly: $`p` must be initialized, and its type implicitly copyable.
Transferring it, $`p\,\hat{}`, needs $`p` initialized and a variable
that the function may change, owned or held `mut`; afterwards $`p` is
uninitialized.
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

:::readable MojoGrimoire.Check.overlaps MojoGrimoire.Check.locationArgs MojoGrimoire.Check.checkExclusive MojoGrimoire.Check.checkExclusive.go (fingerprint := "14443904418390470930")
*Rule: argument exclusivity.* Two places overlap when they have the same
variable and one path is a prefix of the other. The arguments of a call
that are passed as locations are the places whose parameters are `read`,
`mut` or `ref`, and the receiver of a method unless its `self` is
`var`. A call is rejected when a location passed `mut` overlaps another
location of the same call, unless it is an $`\mathsf{Int}` or a
$`\mathsf{Bool}`, which Mojo passes by copy.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "12400455311882201308")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`.
:::

:::readable MojoGrimoire.Check.checkExpr MojoGrimoire.Check.checkArgs (fingerprint := "1930052323461991855")
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
* operators have the types above.

The arguments of a call are checked in order against the parameters, after
the exclusivity rule: a place by `passPlace`, and any other expression by
its type, which must be the parameter's; a `mut` parameter needs a place.
The numbers of arguments and parameters must be equal.
:::
