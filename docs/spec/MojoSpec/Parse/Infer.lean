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

:::moduleDocs (fingerprint := "13628731530693418711")
:::

:::readable MojoGrimoire.Parse.eagerValue (fingerprint := "681582824631525660")
*Definition: the value of a setter.* The value $`v` of $`q[i] = v` is
read as it is evaluated, before the getters of the subscripts read late
in $`i`, as the compiler does: a subscript read late there is a call of
its getter as a method (#191).
:::

:::readable MojoGrimoire.Parse.inferTarget MojoGrimoire.Parse.inferStmt MojoGrimoire.Parse.inferBlock (fingerprint := "11494058955055973050")
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

:::readable MojoGrimoire.Parse.inferFun MojoGrimoire.Parse.inferStruct MojoGrimoire.Parse.inferProgram MojoGrimoire.Parse.bodies MojoGrimoire.Parse.inferRaw MojoGrimoire.Parse.parse (fingerprint := "2805391567743726685")
*Definition: parsing a program.* Inference starts each function from its
parameters, and each destructor from `self`. The values a function returns
are expected to have its result type, unless it returns a reference: then
none is expected, since a literal is no place. Parsing a program lexes and
parses its text, marks the types whose name a variable hides
(`markHidden`), replaces `Self` in each struct's methods (`resolveSelf`),
and then infers inside every declaration (`inferRaw`). It also infers
them in `main`'s mode, and keeps the bodies that gives, each function's,
initializer's, destructor's and method's, as the program's twin, which
is inferred only when the checker first needs it. It does not check
the constructs outside the subset, which the driver's `parseSubset` does.
:::
