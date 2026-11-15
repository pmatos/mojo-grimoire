import VersoManual
import MojoGrimoire.Core.Program
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Core.Program`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Functions, structs and programs: readable blocks" =>

:::moduleDocs (fingerprint := "16555158738056274582")
:::

:::readable MojoGrimoire.Core.Param (fingerprint := "15254264730588750988")
*Definition: parameters.* A parameter $`c~x : t` has a convention $`c`, a
name $`x` and a type $`t`.
:::

:::readable MojoGrimoire.Core.FunDecl (fingerprint := "3868834581323395352")
*Definition: functions.* A function
$`\mathsf{def}~f(c_1~x_1 : t_1, \dots, c_n~x_n : t_n) \to t : s^*` has a
name $`f`, parameters, a result type $`t` and a body $`s^*`. A function that
returns nothing has the result type $`\mathsf{None}`.

A method is a function whose first parameter is $`\mathsf{self}`, and an
initializer a method whose $`\mathsf{self}` has the convention
$`\mathsf{out}`.
:::

:::readable MojoGrimoire.Core.Copying (fingerprint := "6297036913896180406")
*Definition: copying.* How the values of a struct can be copied:

```grammar MojoGrimoire.Core.Copying
\kappa
none      \mathsf{none}
explicit  \mathsf{Copyable}
implicit  \mathsf{ImplicitlyCopyable}
```

A value that is $`\mathsf{Copyable}` can be copied with
$`p.\mathsf{copy}()`, and one that is $`\mathsf{ImplicitlyCopyable}` also
wherever it is read as a value. Every struct can be moved: Mojo synthesizes
a move initializer for a struct that declares no conformance.
:::

:::readable MojoGrimoire.Core.StructDecl (fingerprint := "13720803519696074767")
*Definition: structs.* A struct declaration has:

* a name $`S`, and fields $`(f : t)^*`;
* how its values can be copied;
* whether it is `@fieldwise_init`, in which case $`S(e^*)` initializes its
  fields from its arguments, in order;
* an optional initializer $`\mathsf{\_\_init\_\_}(\mathsf{out}~\mathsf{self}, \dots)`;
* the body of an optional destructor
  $`\mathsf{\_\_deinit\_\_}(\mathsf{deinit}~\mathsf{self})`;
* its other methods.

Copy and move initializers are always the ones Mojo synthesizes.
:::

:::readable MojoGrimoire.Core.Program (fingerprint := "523312046829913975")
*Definition: programs.* A program is a list of structs and a list of
functions. It runs by calling the function $`\mathsf{main}`.
:::
