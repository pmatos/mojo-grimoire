import VersoManual
import MojoGrimoire.Check.Stmt
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Stmt`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Statements and blocks: readable blocks" =>

:::moduleDocs (fingerprint := "3578808387334158703")
:::

:::readable MojoGrimoire.Check.partlyMovedDeinit MojoGrimoire.Check.cannotEnd MojoGrimoire.Check.checkEnd (fingerprint := "9992527159242234863")
*Rule: the end of a variable.* The compiler destroys a struct whole, so a
variable may not end when it still holds a part, in $`H`, and a field is
in $`M`, moved out and not assigned again, or $`\epsilon` is in both
$`M` and $`P`, so that it was moved out whole and then built from its
fields. A variable that holds nothing may end with fields moved out, since
nothing of it is destroyed (#51), unless a field in $`M` is at or below a
touched part in $`T`: a field moved out of a part held whole, or out of
one whose inside was assigned. Nor may a part whose struct has a
destructor of its own, which needs the whole value, end partly built: with
a part below it uninitialized while it may hold a value, or uninitialized
itself while a part below it may hold one. Since $`U` and $`H` hold what
may be so on some path, this also rejects a struct built in only one
branch of an `if`, or in a loop. The `self` of `__deinit__` is destroyed
field by field: its own fields may stay moved out, and its own type does
not count, since its destructor is the one running. Each error is
$`\mathsf{partiallyDestroyed}`.
:::

:::readable MojoGrimoire.Check.checkExit (fingerprint := "15720368628365232594")
*Rule: a return.* When a function returns, each `mut` parameter and the
`self` of `__init__` must be wholly initialized, since the caller holds
them, with no piece in $`P`: otherwise the error is
$`\mathsf{uninitializedAtExit}`, or a use of the variable when it is
itself a piece, as the compiler reports. Every variable must be allowed
to end.
:::

:::readable MojoGrimoire.Check.endScope (fingerprint := "5094446271499096283")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached, and leave the
set of invalidated references.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinStates (fingerprint := "8803546111622442465")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so, and may hold a value when either branch may;
$`M`, $`T` and $`P` are the unions of the branches' sets, and
a reference is invalidated when either branch invalidates it. A branch
that cannot reach its end, because it returned, does not count.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "15906415396099670179")
*Rule: loops.* A loop body that can reach its end must leave initialized
every part that was initialized before the loop, and may not add a field to
$`M`, or its next iteration would use a moved value. As Mojo does, the
checker reports such a part as a use of an uninitialized value.
:::

:::readable MojoGrimoire.Check.printable MojoGrimoire.Check.checkPrintArg (fingerprint := "1986903753210102649")
*Rule: printing.* `print` takes string literals, and values it can write:
those of type $`\mathsf{Int}` or $`\mathsf{Bool}`, and lists and arrays
of values it can write, nested ones included. It reads a place by
reference, after checking its indices, so it copies nothing: a list may be
printed from a `read` parameter or a reference. Any other argument is
checked as an expression, and a call that returns a reference gives the
value it points to, uncopied. Anything else, a struct or a list of
structs, is $`\mathsf{notPrintable}`.
:::

:::readable MojoGrimoire.Check.checkConstructed (fingerprint := "13095619089498858650")
*Rule: building into an element.* $`p = e` is rejected as
$`\mathsf{argumentExclusivity}` when $`p` is inside an element of a list,
and $`e` is a call that builds its result in place and is passed `mut`, or
`ref` when it may change it, the list or a place that holds it, or a call
that returns a reference to one: the change would invalidate $`p`. A call of a function or a method builds its result
in place unless it returns an $`\mathsf{Int}`, a $`\mathsf{Bool}` or a
reference, and so does a struct's `__init__`; a call whose signature has
a generic result, such as a list method that gives an element, always
does.
:::

:::readable MojoGrimoire.Check.checkInitValue (fingerprint := "16605841785613679210")
*Rule: initializing values.* A value that initializes a declared variable,
a place assigned to, or a function's result must have its type. A literal
$`[e^*]_{\mathsf{None}}`, which has no list or array expected, where that
type is neither, such as a struct or a $`\mathsf{Bool}`, is
`noMatchingInit` of that type once its elements are checked on their own:
Mojo calls the type's initializer with the elements and the keyword
`__list_literal__`, which none takes (#46).
:::

:::readable MojoGrimoire.Check.checkReturnValue (fingerprint := "6201929813473914141")
*Rule: returned values.* `return x` moves the variable $`x` out when the
function owns it, as Mojo does; any other returned expression is checked as
an expression, so a place is copied implicitly.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "11972735219964973096")
*Rule: statements.*

* $`\mathsf{var}~x : t~(= e)^?` needs a declarable $`t` and an $`e`
  of type $`t`, by `checkInitValue`, as do an assignment and `return`, and declares $`x`, initialized when $`e` is given; $`x`
  may not be the name of a variable in scope, so no variable hides another;
* $`\mathsf{ref}~x = e` binds $`x` to a reference, as the next section
  says; $`x` may not hide a variable in scope either;
* $`p = e` checks $`e` first, then the indices of $`p`, then needs $`p`
  of $`e`'s type, then that $`e` does not build its result into $`p`
  while changing the list that holds it, then needs a place the function may change; $`p` is changed as a
  whole, its old value ends, and $`p` is initialized. The old value may
  not end, as at the end of a variable, with the parts of $`p` taken as
  the value's own, $`p` itself uninitialized when a part at or above it
  is; so a part in $`M` that was given some of its fields
  may not be assigned whole. Assigning $`p` removes from $`M`, $`T` and
  $`P` the parts at or below $`p`, adds $`p` to $`H`, and adds to $`T`
  the part of $`H` above $`p`, if any. When a part above $`p` is
  uninitialized, the parts from it down to the part above $`p` become
  pieces, except the `self` of `__init__` itself, which is whole once its
  fields are. Assigning a part below a field in $`M` does not remove it.
  Through a reference or to an element, the old value is read first, so
  it must be initialized;
* an expression statement checks its expression;
* `print` checks its arguments as above, then that its place arguments are
  still initialized and not invalidated;
* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized. After the loop, which may have run
  any number of times, the state is the one before it, with $`H`, $`T`
  and $`P` joined with those the body leaves. When the body can reach its end
  and invalidates a reference, the condition and the body are checked once
  more with it invalidated, as the next iteration finds it, and it stays
  invalidated after the loop;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable; a function that returns a reference returns a
  location whose origins are all within its own origin, as the previous
  section says;
* `drop p` transfers $`p` away.

A block checks its statements in order, and the changes recorded for
operands start afresh with each statement.
:::
