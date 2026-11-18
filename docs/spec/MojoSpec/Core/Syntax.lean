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

:::moduleDocs (fingerprint := "7137499917617355434")
:::

:::readable MojoGrimoire.Core.Place MojoGrimoire.Core.Expr (fingerprint := "519563516514138862")
*Definition: places and expressions.* A place $`p` names a location that holds a value:

```grammar MojoGrimoire.Core.Place
p
var    x
field  p.f
index  p[e]
transferred  p\,\hat{}
```

$`x` is a variable, $`p.f` the field $`f` of the value in $`p`, and
$`p[e]` the element at index $`e` of the list or array in $`p`. The place
$`p\,\hat{}`, which the Lean calls `transferred`, is Mojo's `p^` followed
by a field or a method, as in `p^.f` or `p^.m()`: the compiler borrows
$`p` instead of moving it, so it is the place $`p`, through which nothing
may be changed, except that a method whose `self` is `var` consumes it.
Places and expressions are defined together, since an index is an
expression.
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
listInit      \mathsf{List}[t](e^+)
withDrops     \mathsf{drops}(e; p^*; p^*)
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
* $`[e^*]_t` builds a value of the type $`t`, a list or an array, with the
  elements $`e^*`: Mojo's literal `[e1, e2]`, or `List[u]()` when it is
  empty. Mojo gives `[e1, e2]` the type `Array[u, 2]` unless a list is
  expected where it stands. The parser gives a literal the type `None`,
  which inference replaces only when a list or an array is expected, or
  with $`\mathsf{Int}` for a literal `[e]` of one `Int` made of literals
  and operators where an `Int` is expected, which is the value of $`e`
  (#103).
* $`\mathsf{List}[t](e^+)` is Mojo's `List[u](e1, e2)` with at least one
  argument. With one, a list or an array of $`t`, it is a new list of
  copies of its elements (#103); with more, Mojo 1.2.0 rejects it (#46):
  no initializer of `List` takes its elements as arguments. The Lean
  calls it `listInit`.
* $`\mathsf{drops}(e; p^*; q^*)` performs the operation $`e`, destroying
  the values in the places $`p^*` once its operands are read and those in
  $`q^*` once it is done. No program contains it: elaboration inserts it
  where a value's last use is inside an expression.
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
