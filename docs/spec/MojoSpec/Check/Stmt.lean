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

#doc (Manual) "Statements: readable blocks" =>

:::moduleDocs (fingerprint := "9546923958468338961")
:::

:::readable MojoGrimoire.Check.checkExpr (fingerprint := "17693701935998565066")
*Definition: an expression's type.* An expression used as a value is
checked by `checkExprAs`, not as a reference, and has the type it gives.
:::

:::readable MojoGrimoire.Check.printable MojoGrimoire.Check.checkPrintArg (fingerprint := "6868542877883536562")
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
in place unless it returns an $`\mathsf{Int}`, a $`\mathsf{Bool}`, a
$`\mathsf{None}` or a reference, and so does a struct's `__init__`; a call whose signature has
a generic result, such as a list method that gives an element, always
does. $`\mathsf{List}[u](e)` builds its result in place, and passes $`e`
by `ref` (#103).
:::

:::readable MojoGrimoire.Check.checkInitValue (fingerprint := "16340445673896537548")
*Rule: initializing values.* A value that initializes a declared variable,
a place assigned to, or a function's result must have its type. A literal
$`[e^*]_{?}`, which has no list or array expected, where that
type is neither, such as a struct or a $`\mathsf{Bool}`, is
`noMatchingInit` of that type once its elements are checked on their own:
Mojo calls the type's initializer with the elements and the keyword
`__list_literal__`, which none takes (#46). A call that returns a
reference to a value that is not implicitly copyable reports a type that
does not fit before its copy (`misfitFirst`). A literal
$`[e^*]_{\mathsf{Int}}` of any length but 1 initializes an
$`\mathsf{Int}`, and is rejected by `rejectIntLiteral` as an initializer
of the type reports it (#153, #154). An assignment of either literal
types its place first.
In the type phase, which skips that literal's failure, it initializes the
value with no other check.
:::

:::readable MojoGrimoire.Check.checkReturnValue (fingerprint := "6201929813473914141")
*Rule: returned values.* `return x` moves the variable $`x` out when the
function owns it, as Mojo does; any other returned expression is checked as
an expression, so a place is copied implicitly.
:::

:::readable MojoGrimoire.Check.checkSimple (fingerprint := "16244557658264588356")
*Rule: statements.* A statement that holds no block is checked so; an
`if` and a loop are checked by the rule of blocks, in the next section.

* $`\mathsf{var}~x : t~(= e)^?` needs a $`t` in which no variable hides
  a name, before anything else (`rejectHidden`, #193), a $`t` a variable may have
  (`declarableTy`) and an $`e`
  of type $`t`, by `checkInitValue`, as do an assignment and `return`, and declares $`x`, initialized when $`e` is given; $`x`
  may not be the name of a variable in scope, so no variable hides another.
  When inference left $`t` as $`?`, $`e` is checked first, so
  that its own error, such as an unknown field, is reported, as the
  compiler does (#123);
* $`\mathsf{ref}~x = e` binds $`x` to a reference, as the next section
  says; $`x` may not hide a variable in scope either;
* $`p = e` where $`p` holds a subscript of a struct that has a setter
  and no getter is $`\mathsf{missingMethod}`, before anything else
  but the errors of the subscript's receiver (`rejectSetterOnly`, #296);
  on a subscript of a struct that has a getter and no setter it
  is checked through the getter (`assignGetter`, #191); else it checks
  the indices of $`p` first, as the compiler does, so that $`e` sees
  what they move out or change. It then needs a place the function may
  change (#174) and checks $`e`. When $`e` is a call or a method call
  that would be copied implicitly, its type, read by reference, must first
  fit $`p`, or the assignment is a type mismatch, as the compiler reports
  it before the copy. It then needs $`p` of $`e`'s type, and that $`e`
  does not build its result into $`p` while changing the list that holds
  it. An error of a later pass than typing in an index comes in its own
  phase, after these (#280, #96 part 7). $`p` is changed as a
  whole, its old value ends, and $`p` is initialized. The old value may
  not end, as at the end of a variable, with the parts of $`p` taken as
  the value's own, $`p` itself uninitialized when a part at or above it
  is; so a part partly built, or a part in $`M` that was given some of
  its fields, may not be assigned whole, and a field moved out of a part of $`T`
  above $`p` counts as moved out of a touched part. Assigning $`p` removes from $`M`, $`T` and
  $`P` the parts at or below $`p`, adds $`p` to $`H`, and adds to $`T`
  the part of $`H` above $`p`, if any. When a part above $`p` is
  uninitialized, the parts from it down to the part above $`p` become
  pieces. The `self` of `__init__` itself stops being a piece once its
  fields are all assigned, since it is then whole, unless it was moved out
  whole first. Assigning a part below a field in $`M` does not remove it.
  Through a reference or to an element, the old value is read first, so
  it must be initialized, and the reference not invalidated, but by a
  subscript of an array in $`e`, which the compiler makes after it
  locates the reference (#282). Into the element of an $`\mathsf{Int}`, the
  $`\mathsf{Int}` is located before the value is evaluated, so a change
  the value makes may not invalidate it, and the index, an argument of
  `__setitem__`, is read once the value is evaluated, so the value may not
  invalidate a place it is read from (#127). As $`p \mathbin{op}= e`
  is read as $`p = p \mathbin{op} e`, which evaluates the indices of $`p`
  twice where the compiler evaluates them once (#198), such an assignment
  into the element of an $`\mathsf{Int}` is $`\mathsf{notAList}`, as before
  #127, unless every index of $`p` is plain;
* an expression statement checks its expression, once `checkSetter` has
  checked what a setter call needs;
* `print`, unless a variable in scope named `print` hides it, which
  `rejectCalledVar` rejects once the arguments are typed (#176), checks
  its arguments as above, then that its place arguments, and what its
  literal arguments read late, are still initialized and not invalidated;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable; a function that returns a reference returns a
  location whose origins are all within its own origin, as the previous
  section says;
* `drop p` transfers $`p` away, and calls the destructor of its struct
  when it declares one (`dropCall`).
That the old value may not end is a check of the flow phase's last
stage, `ends`.
:::
