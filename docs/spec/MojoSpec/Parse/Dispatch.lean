import VersoManual
import MojoGrimoire.Parse.Dispatch
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Dispatch`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Methods of operators on structs: readable blocks" =>

:::moduleDocs (fingerprint := "14121114416614882663")
:::

:::readable MojoGrimoire.Parse.declaredMethod MojoGrimoire.Parse.reflectedMethod MojoGrimoire.Parse.inPlaceMethod MojoGrimoire.Parse.otherParam (fingerprint := "14327447033417783899")
*Definition: the methods an operator may call.* A struct type declares a
method by its name. The reflected method of a binary operator, called on
its right operand, is `__radd__`, `__rsub__`, `__rmul__`,
`__rfloordiv__` and `__rmod__` for $`+`, $`-`, $`\times`, `//` and `%`;
`__gt__`, `__ge__`, `__lt__` and `__le__` for $`<`, $`\le`, $`>` and
$`\ge`; and `__eq__` and `__ne__` for $`==` and $`!=`. The in-place
method of $`p \mathrel{\mathit{op}{=}} e` is `__iadd__`, `__isub__` or
`__imul__`. The parameter that takes a binary operator's other operand is
the one after `self`, of a method that takes exactly one.
:::

:::readable MojoGrimoire.Parse.TyEnv MojoGrimoire.Parse.TyEnv.lookup MojoGrimoire.Parse.TyEnv.push MojoGrimoire.Parse.TyEnv.freePlace MojoGrimoire.Parse.TyEnv.placeTy (fingerprint := "16972769437246771461")
*Definition: the types in scope.* Inference keeps the types of the
variables in scope, innermost first, and the variables that may not
change: `read` and `ref` parameters, and `ref` bindings that may not
change what they point to. A place may change when its variable may and
it is no transfer. An operator's result has its `binaryResult`.
:::

:::readable MojoGrimoire.Parse.TyEnv.mutableAt MojoGrimoire.Parse.TyEnv.mutableArgs MojoGrimoire.Parse.TyEnv.canPass (fingerprint := "14590106347368136584")
*Definition: what may change.* An operand may change when it is a place
that may, or a call or a method call that returns a reference whose
origins are all parameters it may change: `mut` ones, `self` among them,
or `ref` ones passed what may change. Only what may change is passed to a
`mut` parameter, which decides which method of an operator is viable
(#191).
:::

:::readable MojoGrimoire.Parse.chooseBinary (fingerprint := "2002475636821204314")
*Rule: the method of a binary operator.* $`a \mathbin{\mathit{op}} b`
calls the method of $`a`'s struct that $`\mathit{op}` names when $`b`
fits its parameter, else the reflected method of $`b`'s struct when $`a`
fits its parameter, whatever $`a`'s type, its own included, else the
method of $`a`'s struct, whose misfit the checker reports; with no
method of $`a`'s struct and no reflected method that fits, the operator
stays as it is (#191). A method fits only when its receiver and its
other operand can be passed with their conventions: a `mut` parameter,
`self` among them, takes only a place that may change, as in the
compiler, so a temporary or a read-only operand moves the choice on.
:::
