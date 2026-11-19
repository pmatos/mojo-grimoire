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

:::moduleDocs (fingerprint := "3094323374432754575")
:::

:::readable MojoGrimoire.Check.holdsAll (fingerprint := "14941134587914973476")
*Definition: holding a part whole.* The parts $`H` hold all of the part
$`q` when one of them is at or above $`q`, or $`q` is a struct and they
hold each of its fields. A part held whole whose field was moved out and
assigned again is recorded as its fields, which hold all of it.
:::

:::readable MojoGrimoire.Check.partlyBuilt MojoGrimoire.Check.cannotEnd MojoGrimoire.Check.checkEnd (fingerprint := "9136026478662908329")
*Rule: the end of a variable.* The compiler destroys a struct whole, so a
variable may not end when it still holds a part, in $`H`, and a field is
in $`M`, moved out and not assigned again, or $`\epsilon` is in both
$`M` and $`P`, so that it was moved out whole and then built from its
fields. A variable that holds nothing may end with fields moved out, since
nothing of it is destroyed (#51), unless a field in $`M` is at or below a
touched part in $`T`: a field moved out of a part held whole, or out of
one whose inside was assigned. Nor may it end partly built, however it got
there, which is the human's ruling R on D-0003, provisional until it is
discussed with Modular. It is partly built when a part $`u` in $`U` and a
different part $`h` in $`H` meet: disjoint, or $`h` above $`u`, or
$`u` above $`h` while $`H` does not hold all of $`u`; or when a piece
in $`P` with a part of $`U` at or above it has a part of $`H` at,
above or below it. Since $`U`, $`H` and $`P` hold what may be so on
some path, a field uninitialized on one path and held on another counts,
as the compiler counts a field moved out on one path only. A part held
whole on every path that holds it does not, as for a variable assigned
whole in only one branch; a part built from its fields is a piece, which
counts even when the join of $`H` folded its fields into it. This
rejects a struct built in only one branch of an `if`, even wholly, or in
a loop, and a struct whose fields are all `Int`s too. The `self` of
`__deinit__` is destroyed field by field: each of its fields is a value
of its own, which may stay moved out. Each error is
$`\mathsf{partiallyDestroyed}`.
:::

:::readable MojoGrimoire.Check.checkExit (fingerprint := "16285919438882412919")
*Rule: a return.* When a function returns, each `mut` parameter and the
`self` of `__init__` must be wholly initialized, since the caller holds
them, with no piece in $`P`: otherwise the error is
$`\mathsf{uninitializedAtExit}`, or a use of the variable when it is
itself the only piece and nothing of it is uninitialized, as the compiler
reports. Every variable must then be allowed to end; the parameters are
checked first, since the compiler reports a parameter left uninitialized
before a variable that may not end.
:::

:::readable MojoGrimoire.Check.endScope (fingerprint := "5094446271499096283")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached, and leave the
set of invalidated references.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinMay MojoGrimoire.Check.joinStates (fingerprint := "3993288572809658863")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so, and may hold a value when either branch may;
$`M`, $`T` and $`P` are the unions of the branches' sets, and
a reference is invalidated when either branch invalidates it. A branch
that cannot reach its end, because it returned, does not count. A loop
joins $`M`, $`H`, $`T` and $`P` the same way, as described below.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "6169669695796580470")
*Rule: loops.* A loop body that can reach its end must leave initialized
every part that was initialized before the loop, and may not add to $`M` a
part that was initialized before it, or its next iteration would use a
moved value. A part uninitialized before the loop may be assigned and
moved out in each iteration. As Mojo does, the
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

:::readable MojoGrimoire.Check.checkConstructed (fingerprint := "5308049381047874511")
*Rule: building into an element.* $`p = e` is rejected as
$`\mathsf{argumentExclusivity}` when $`p` is inside an element of a list,
and $`e` is a call that builds its result in place and is passed `mut`, or
`ref` when it may change it, the list or a place that holds it, or a call
that returns a reference to one: the change would invalidate $`p`. A call of a function or a method builds its result
in place unless it returns an $`\mathsf{Int}`, a $`\mathsf{Bool}` or a
reference, and so does a struct's `__init__`; a call whose signature has
a generic result, such as a list method that gives an element, always
does. $`\mathsf{List}[u](e)` builds its result in place, and passes $`e`
by `ref` (#103).
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

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "3797012120997196750")
*Rule: statements.*

* $`\mathsf{var}~x : t~(= e)^?` needs a declarable $`t` and an $`e`
  of type $`t`, by `checkInitValue`, as do an assignment and `return`, and declares $`x`, initialized when $`e` is given; $`x`
  may not be the name of a variable in scope, so no variable hides another.
  When inference left $`t` as $`\mathsf{None}`, $`e` is checked first, so
  that its own error, such as an unknown field, is reported, as the
  compiler does (#123);
* $`\mathsf{ref}~x = e` binds $`x` to a reference, as the next section
  says; $`x` may not hide a variable in scope either;
* $`p = e` checks $`e` first, then the indices of $`p`, then needs $`p`
  of $`e`'s type, then that $`e` does not build its result into $`p`
  while changing the list that holds it, then needs a place the function may change; $`p` is changed as a
  whole, its old value ends, and $`p` is initialized. The old value may
  not end, as at the end of a variable, with the parts of $`p` taken as
  the value's own, $`p` itself uninitialized when a part at or above it
  is; so a part partly built, or a part in $`M` that was given some of
  its fields, may not be assigned whole, and a field moved out of a part of $`T`
  above $`p` counts as moved out of a touched part. Assigning $`p` removes from $`M`, $`T` and
  $`P` the parts at or below $`p`, adds $`p` to $`H`, and adds to $`T`
  the part of $`H` above $`p`, if any. When a part above $`p` is
  uninitialized, the parts from it down to the part above $`p` become
  pieces, except the `self` of `__init__` itself, which is whole once its
  fields are, unless it was moved out whole first. Assigning a part below a field in $`M` does not remove it.
  Through a reference or to an element, the old value is read first, so
  it must be initialized;
* an expression statement checks its expression;
* `print` checks its arguments as above, then that its place arguments are
  still initialized and not invalidated;
* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized. When the body can reach its end,
  the next iteration starts from the state before the loop with $`M`,
  $`H`, $`T`, $`P` and the invalidated references joined with those the
  body leaves; when that adds anything, the condition and the body are
  checked once more from it. After the loop, which may have run any number
  of times, the state is that one, with $`M`, $`H`, $`T` and $`P` of the
  second check joined in too;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable; a function that returns a reference returns a
  location whose origins are all within its own origin, as the previous
  section says;
* `drop p` transfers $`p` away.

A block checks its statements in order, and the changes recorded for
operands start afresh with each statement.
:::
