import VersoManual
import MojoGrimoire.Core.Syntax
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Core.Syntax`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Places, expressions and statements: readable blocks" =>

:::moduleDocs (fingerprint := "14748316690280824463")
:::

:::readable MojoGrimoire.Core.Place MojoGrimoire.Core.Expr (fingerprint := "5147792290193113691")
*Definition: places and expressions.* A place $`p` names a location that holds a value:

```grammar MojoGrimoire.Core.Place
p
var    x
field  p.f
index  p[e]
```

$`x` is a variable, $`p.f` the field $`f` of the value in $`p`, and
$`p[e]` the element at index $`e` of the list in $`p`. Places and
expressions are defined together, since an index is an expression.
An expression $`e` is one of:

```grammar MojoGrimoire.Core.Expr
e
int,bool,str  n \mid b \mid s
place         p
transfer      p\,\hat{}
copy          p.\mathsf{copy}()
call          f(e^*)
method        p.m(e^*)
unary         \mathit{unop}~e
binary        e~\mathit{binop}~e
list          [e^*]_t
```

Here $`n` is an integer, $`b` a boolean and $`s` a string literal.

* $`p` uses a place. Read as a value, it copies the value implicitly, which
  only an implicitly copyable value allows. Passed as an argument to a
  $`\mathsf{read}`, $`\mathsf{mut}` or $`\mathsf{ref}` parameter, it passes
  the location itself.
* $`p\,\hat{}` transfers the value out of $`p`, which is uninitialized
  afterwards. The Lean calls it `transfer`.
* $`p.\mathsf{copy}()` makes an explicit copy of a copyable value.
* $`f(e^*)` calls the function $`f`, or constructs the struct $`f` when $`f`
  names a struct, as Mojo's `S(args)` does.
* $`p.m(e^*)` calls the method $`m` on the value in $`p`.
* $`[e^*]_t` builds a list of elements of type $`t`: Mojo's literal
  `[e1, e2]`, or `List[t]()` when it is empty.
:::

:::readable MojoGrimoire.Core.Stmt (fingerprint := "14081413901527619483")
*Definition: statements.* A statement $`s` is one of the following, where a
block $`s^*` is a sequence of statements:

```grammar MojoGrimoire.Core.Stmt
s
pass       \mathsf{pass}
decl       \mathsf{var}~x : t~(= e)^?
refDecl    \mathsf{ref}~x = e
assign     p = e
expr       e
print      \mathsf{print}(e^*)
ifElse     \mathsf{if}~e : s^*~\mathsf{else} : s^*
whileLoop  \mathsf{while}~e : s^*
ret        \mathsf{return}~e^?
drop       \mathsf{drop}~p
```

An $`\mathsf{if}` with no $`\mathsf{else}` has an empty else block. The Lean
calls the declaration `decl`, the loop `whileLoop` and the return `ret`.
$`\mathsf{ref}~x = e` binds $`x` to the location that $`e` names, a place
or a call that returns a reference, so that $`x` is another name for it.

$`\mathsf{drop}~p` destroys the value in $`p`. No Mojo program contains it:
Mojo destroys each value as soon as possible, after its last use, and
elaboration makes this explicit by inserting $`\mathsf{drop}`, so that a run
never has to find a value's last use.
:::
