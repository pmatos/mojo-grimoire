import VersoManual
import MojoGrimoire.Core.Types
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Core.Types`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Names, types, conventions and operators: readable blocks" =>

:::moduleDocs (fingerprint := "10632303303006193387")
:::

:::readable MojoGrimoire.Core.Name (fingerprint := "17987575212195285839")
*Definition: names.* A name $`x` is a string. Variables, fields, functions,
methods and structs are all named by names, and the context says which.
:::

:::readable MojoGrimoire.Core.Ty (fingerprint := "4354194502057206910")
*Definition: types.* A type $`t` is one of:

```grammar MojoGrimoire.Core.Ty
t
int        \mathsf{Int}
bool       \mathsf{Bool}
str        \mathsf{Str}
noneType   \mathsf{None}
struct     S
list       \mathsf{List}[t]
array      \mathsf{Array}[t, n]
```

Here $`S` is the name of a struct, $`\mathsf{List}[t]` is a list of
values of type $`t`, whose length may change, and
$`\mathsf{Array}[t, n]` an array of exactly $`n` of them. $`\mathsf{Str}` is the type of string
literals, which a program may only print, and $`\mathsf{None}` the type of a
call to a function that returns nothing.
:::

:::readable MojoGrimoire.Core.Conv (fingerprint := "11609666784133341925")
*Definition: argument conventions.* A convention $`c` says how a parameter
receives its argument:

```grammar MojoGrimoire.Core.Conv
c
read     \mathsf{read}
mutable  \mathsf{mut}
owned    \mathsf{var}
ref      \mathsf{ref}
out      \mathsf{out}
deinit   \mathsf{deinit}
```

* $`\mathsf{read}`, the default, which Mojo writes with no keyword: the
  parameter is an immutable reference to the caller's value.
* $`\mathsf{mut}`: a mutable reference to the caller's value.
* $`\mathsf{var}`: the parameter owns its value, which the caller transfers
  or copies into it. The Lean calls it `owned`.
* $`\mathsf{ref}`: a reference whose mutability follows the argument's.
* $`\mathsf{out}`: the parameter is uninitialized on entry, and the function
  must initialize it. Only `self` of `__init__` has it.
* $`\mathsf{deinit}`: the parameter's value is being destroyed. Only `self`
  of `__deinit__` has it.
:::

:::readable MojoGrimoire.Core.UnOp (fingerprint := "1802749205680380359")
*Definition: unary operators.*

```grammar MojoGrimoire.Core.UnOp
\mathit{unop}
neg  -
not  \mathsf{not}
```

$`-` negates an $`\mathsf{Int}`, and $`\mathsf{not}` a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Core.BinOp (fingerprint := "3044402931478875106")
*Definition: binary operators.*

```grammar MojoGrimoire.Core.BinOp
\mathit{binop}
add,sub,mul,floorDiv,mod  + \mid - \mid * \mid /\!/ \mid \%
lt,le,gt,ge,eq,ne         < \mid {\le} \mid > \mid {\ge} \mid {=}{=} \mid {!}{=}
and,or                    \mathsf{and} \mid \mathsf{or}
```

The first row is integer arithmetic, where $`/\!/` is division rounded
towards negative infinity, the Lean's `floorDiv`, and $`\%` its remainder.
The second row compares integers. $`\mathsf{and}` and $`\mathsf{or}`
short-circuit, as in Mojo: the right operand is evaluated only when the left
one does not decide the result.
:::

:::readable MojoGrimoire.Core.BinOp.arith (fingerprint := "7794664695434502313")
*Definition: integer arithmetic.* Each operator of the first row is a
function on the integers, before any wrapping to 64 bits: $`/\!/` rounds
toward negative infinity and $`\%` takes the sign of the divisor, and both
give $`0` for a zero divisor, as Mojo defines them. Constant indices and
runs use the same functions.
:::
