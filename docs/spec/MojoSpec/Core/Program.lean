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

:::moduleDocs (fingerprint := "13188387416140284251")
:::

:::readable MojoGrimoire.Core.Param (fingerprint := "15254264730588750988")
*Definition: parameters.* A parameter $`c~x : t` has a convention $`c`, a
name $`x` and a type $`t`.
:::

:::readable MojoGrimoire.Core.FunDecl (fingerprint := "15043811440320529459")
*Definition: functions.* A function
$`\mathsf{def}~f(c_1~x_1 : t_1, \dots, c_n~x_n : t_n) \to t : s^*` has a
name $`f`, parameters, a result type $`t` and a body $`s^*`. A function that
returns nothing has the result type $`\mathsf{None}`. A function may return
a reference instead of a value, Mojo's
$`\to \mathsf{ref}~[x_1, \dots, x_k]~t`: its origin names the parameters
whose values the reference may point into.

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

:::readable MojoGrimoire.Core.Member MojoGrimoire.Core.Decl (fingerprint := "16020552063474706497")
*Definition: the order of declarations.* Where a declaration stands in the
source:

```grammar MojoGrimoire.Core.Member
m
field   \mathsf{field}~i
init    \mathsf{\_\_init\_\_}
deinit  \mathsf{\_\_deinit\_\_}
method  \mathsf{method}~i
```

```grammar MojoGrimoire.Core.Decl
d
func    \mathsf{function}~i
struct  \mathsf{struct}~i~m^*
```

A member of a struct is its $`i`-th field, its initializer, its destructor
or its $`i`-th other method. A declaration of a program is its $`i`-th
function, or its $`i`-th struct with the order of its members. The
compiler reports some errors in the order of the source (#96).
:::

:::readable MojoGrimoire.Core.Program (fingerprint := "1897037947152094274")
*Definition: programs.* A program is a list of structs and a list of
functions, with the order of its declarations in the source, which the
parser records and which is empty in a program built otherwise. It runs
by calling the function $`\mathsf{main}`. Two programs are equal when
their structs, functions and order of declarations are.
:::

:::readable MojoGrimoire.Core.StructDecl.defaultMembers MojoGrimoire.Core.Program.declOrder (fingerprint := "8311956066181836934")
*Definition: the order of a program.* The order of a program's
declarations is the one that the parser recorded. A program built with no
order, such as one built by hand, takes its structs and then its
functions, and each struct its fields, then its initializer, its
destructor and its other methods. Later passes read the order so.
:::

:::readable MojoGrimoire.Core.deinitDecl (fingerprint := "824444876881085203")
*Definition: destructors.* A destructor is the function
$`\mathsf{\_\_deinit\_\_}(\mathsf{deinit}~\mathsf{self})` of its
struct that returns nothing.
:::
