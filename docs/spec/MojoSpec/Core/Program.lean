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

:::moduleDocs (fingerprint := "15332183343010864468")
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

:::readable MojoGrimoire.Core.Program (fingerprint := "9032506628055028520")
*Definition: programs.* A program is a list of structs and a list of
functions, with the order of its declarations in the source, which the
parser records and which is empty in a program built otherwise. It runs
by calling the function $`\mathsf{main}`. It also says whether it is inferred and checked as `main` did, and holds its
twin: the bodies that inference gives in that mode, as functions, each
with the struct it belongs to or none, for the checker's bridge to
`main`'s order (#166). The twin is computed only when
the checker first needs it.
:::

:::readable MojoGrimoire.Core.instBEqProgram (fingerprint := "4903671369859018109")
*Definition: equal programs.* Two programs are equal when their structs,
functions, order of declarations and mode are. The twin is not compared, so as not to infer it;
elaboration and the stripping of tests change the functions and keep the
twin, so two programs equal so may differ in their twins.
:::

:::readable MojoGrimoire.Core.deinitDecl MojoGrimoire.Core.Program.asMain MojoGrimoire.Core.Program.twinBody (fingerprint := "12354485916356738237")
*Definition: twins.* A destructor is the function
$`\mathsf{\_\_deinit\_\_}(\mathsf{deinit}~\mathsf{self})` of its
struct that returns nothing. A program in `main`'s mode is the same
program, inferred and checked as `main` did. The twin of a function's
body is the body of the function of its twin with the same owner, the
same struct for a member or none for a free function, the same name and
the same parameters, so that a free function never stands for a method;
it is empty when there is none.
:::
