# Current decisions: semantics, references

This page continues [semantics.md](semantics.md) with the static checker's
decisions on references.

## References

`ref x = e` bindings and functions that return `ref [a, b] T` follow these
choices (#18):

- A reference's origins are the places it may point into: the place it is
  bound to, or the arguments passed to the parameters a returned
  reference's origin names. For a `ref` binding, those arguments must be
  located operands: places, or calls that return a reference, whose
  origins are those of their own origin arguments (#69). An origin
  argument may be a temporary, as the compiler allows (#80): `ref r =
  same(T(1))`, `ref r = first([1, 2])`. It is left out of the origins, and
  the reference may not be changed through it: `r.v = 7` is
  `immutablePlace`, as the compiler reports it ("expression must be
  mutable in assignment"). The temporary lives until the reference's last
  use, as the last bullet says. A `return` of a reference that may
  point into a temporary, `return r` after `ref r = pick(T(1), x, True)`
  or `return same(r)`, is `escapingReference`, as the compiler reports it
  ("cannot return reference with incompatible origin"): the binding
  remembers that it may (`MojoGrimoire.Check.tempOrigin`). A `return` of
  the call itself, `return same(T(1))`, is still rejected as
  `notAPlace`, where the compiler reports `escapingReference` (#366).
- A use of a reference needs every origin initialized, so a value moved
  away cannot be used through a reference to it. A value cannot be
  transferred out through a reference: `t^`, `t.f^`, `t^.f` and
  `t^.m(…)` on a reference `t` are rejected as `transferFromElement`, as
  the compiler does ("expression does not designate a value with an
  origin"), whether `t` is bound to a place or to a call that returns a
  reference, whether it may be changed or not, even when its origins are
  moved away or invalidated, and when `t^` is passed to a `mut` parameter,
  of a function or an initializer: the compiler rejects the transfer
  before it looks at the origins or matches the argument. A `ref` or a
  `read` parameter stays `transferFromBorrowed`, also passed to a `mut`
  parameter (#85). `t^` of type `Int`, `Bool` or
  `None` is the place `t` (#50, #131).
- A reference may be changed when every origin allows it: a `mut`
  parameter does, a `ref` parameter as its argument does, a `read`
  parameter does not. A place reached through `p^` passed to a `ref`
  parameter or a `ref self` receiver does not, as the compiler does (#91):
  it borrows such a place as a value that cannot be changed, so after
  `ref r = a^.me()` or `ref r = pick(a^.k)` a change through `r` is
  rejected (`immutablePlace`), and the call changes nothing. A `ref`
  binding to the place itself, `ref r = a^.k`, may still change it.
- An origin names only `read`, `mut` or `ref` parameters, and a returned
  reference must stay within the function's origin (`escapingReference`).
  A field or a list element has an origin of its own and may not be
  returned, as the compiler does (#56, #67): `return p.a`, or `return
  xs[0]` for a list `xs`. An element of an array may be returned.
- A reference overlaps what its origins overlap, for argument
  exclusivity. A reference through another reference points into the same
  place of each of the other's origins.
- A reference into an element of a list is invalidated when the list, or a
  place that holds it, changes as a whole. That means it is assigned,
  passed `mut`, which includes `append` and `pop`, or passed `ref` from a
  place that may be changed and is not reached through `p^`. Using the reference afterwards, on any path
  or on a later iteration of a loop, is rejected (`invalidatedReference`),
  as the compiler does (#55). Changing one element, reading the list,
  or assigning a whole array does not invalidate it, since an array holds
  its elements in place, but a subscript of an array that holds the list
  does, as the next bullet says. Any other change to an origin while a
  reference to it is live is not rejected.
- A subscript of an array that may change, `v[i]`, changes the array too,
  for the references into an element of a list inside it (#282): the
  compiler passes the array to `__getitem__` as a mutable `self`, and
  rejects a later use of such a reference as "use of invalidated interior
  reference" (`invalidatedReference`). With `v: Array[List[Int], 1]`,
  `print(v[0][0], v[0])`, `two(v[0][0], v[0])` and `ref r = v[0][0]`
  followed by `print(len(v[0]))` and `print(r)` are rejected. So is
  `u[0][0].append(u[0][0][0])`, whose receiver is located first. An array
  may change when it is a local variable, a `var`, `mut` or `ref`
  parameter or `self`, or a reference into one that may change. A `ref`
  parameter counts, since the compiler does not know its mutability, and
  so does `ref e = v` with `v` one. A reference that a call returns
  through a `read` parameter does not. A `read` parameter, a
  place reached through `p^` and a subscript of a list do not:
  `print(v[0][0], v[0])` runs in a function that takes `v` `read`, and so
  does `print(z[0][0][0], z[0])` with `z` a list of such arrays. Reading
  the array whole, `print(v[0][0], v)`, does not invalidate either. Neither
  does a subscript after an operand that is read at once,
  `print(v[0][0] + 1, v[0])`. A reference to the array's element itself,
  `ref e = v[0]`, stays valid. A store through a reference that an earlier
  statement invalidated so is rejected. When the store's own value
  invalidates it, as in `r = v[0][0] + 1`, the compiler locates `r` before
  the value and accepts the store, and so does the model. Only a later
  read of `r` is rejected.
- A place operand that goes through a list element is located before the
  operands after it are evaluated, and read once they all are. A later
  operand that changes the list invalidates it, and the model rejects the
  operation, as the compiler does: `print(xs[0], xs.pop())`. A literal
  operand is built from its elements only once every operand of its
  operation is evaluated, so its element places are read then too:
  `print([xs[0]], xs.pop())` and `[xs[0]] == [xs.pop()]` are rejected
  (#282). A literal passed to `len` is built, and read, at once. A later
  operand that transfers a place gives it up only once the literal is
  built: `print([b[0]], b^)` runs, but `print([b[0]], take(b^))` is a use
  of `b` after its move, as the call takes `b` before. A literal
  nested in a literal operand is built in its turn, before its later
  siblings: `print(r > [[b[0]], b^])` runs. That it reads its places after
  the operation's later operands, as in `print([[v[0][0]]], v[0])`, which
  the compiler rejects, is not modelled yet (#308): the model runs it, as
  `main` did.
- An assignment through a reference into a list element is rejected
  (`invalidatedReference`) when its own value invalidates the reference:
  `ref e = xs[0]; e = grow(xs)`. The compiler accepts that and stores into
  a stale element, as it does for `xs[0] = grow(xs)`; the human ruled on
  2026-11-16 that this is a compiler bug (#57,
  [D-0002](../conformance/decision-log.md)). The model checks the index
  of `xs[0] = grow(xs)` against the list before the call, as the
  compiler does, then locates the element again once the value is
  evaluated, and stores into the grown list. It keeps
  rejecting the `ref` form, since running it could leave the interpreter
  stuck when the call shrinks the list.
- An assignment into a list element is rejected (`argumentExclusivity`)
  when the value is a call that builds its result in place and is passed
  `mut` the list, or a place that holds it: `xs[0] = xs.pop()`. A call
  builds its result in place unless it returns an `Int`, a `Bool`,
  `None` or a reference. `pop` always does, since its result has a generic type.
- A call that returns a reference, used as a value, copies the value
  implicitly, but as an operand of a comparison of two arrays or two
  lists, which reads it by reference
  ([semantics-comparisons.md](semantics-comparisons.md#comparisons-of-arrays-and-lists)).
  Printed, an operand of a binary operator other than `and`
  and `or`, an argument passed by value or an element of a list or an
  array literal, it is read only once every operand of the operation is
  evaluated, as the compiler does (#76). Its origins must then still be
  initialized (`uninitializedUse`), and not invalidated by a later operand
  (`invalidatedReference`): `print(pick(xs[0], b, True), xs.pop())` is
  rejected. An origin argument that is a temporary is left out, and the
  others are checked: `print(pick([1], b, False), eat(b^))` is rejected.
  The temporary lives until the reference is read, as the last bullet
  says (#98). The
  operand of a unary operator, `and` or `or` is read at once. Passed to
  `len`, or to a `read`, `mut` or `ref` parameter, it is a location when it is a located operand, as the compiler does
  (#69): it is not copied, it
  overlaps what its origins overlap for argument exclusivity (`n(first(xs),
  xs)` is rejected when `n` takes its second argument `mut`), it must be
  mutable for `mut` (`immutablePlace`), and the call changes its origins
  as it would a place. Its origins must still be initialized, and not
  invalidated, once the call's later arguments are evaluated. An `Int` or
  a `Bool` passed `read` is copied, and a `var` parameter copies it
  implicitly. One with a temporary origin argument is passed so too, the
  temporary left out of its origins, as the compiler accepts
  `pz(same(T(1)))` for a `T` that cannot be copied (#80); passed `mut`,
  it is `immutablePlace`. The temporary dies once the call it is passed to
  is done.
- Elaboration counts each use of a reference as a use of its origins, so
  their values live until the reference's last use. A call that returns a
  reference, passed by reference, keeps its origins alive until the
  operation it is passed to is done: `len(first(xs))` destroys `xs` right
  after `len`, as the compiler does. Read by value, it keeps them alive
  until the operation's operands are read, and those that die then are
  destroyed the last declared first, in the order the operands are read
  (#76). Before #76 they were destroyed when the inner call returned, so
  the interpreter read a destroyed value (#94). The value of a `return`
  reads it first, then destroys them in the same order: the parameters
  first, then the local variables, each the last declared first.
- A temporary origin argument whose value is dropped, a struct or a list
  or an array of them, lives as an unnamed local variable declared where
  it is made, as the compiler keeps it (#80): until the last use of the
  reference that points into it, and it dies then with the values that
  die there, as the one declared last. `print(vv(same(P(1))), f(2))`
  destroys it right after `vv`, `same(mk(1)) + same(mk(2))` destroys
  both after `__add__`, the second first, and `ref r = same(T(1))` keeps
  it until `r`'s last use. Elaboration gives it a hidden variable,
  declared with no value right before its statement, in the same block
  (`MojoGrimoire.Elab.tempBlock`); in a `while` condition, each run of
  the condition makes and destroys it. A temporary of another type is
  destroyed when its call returns, as before, since nothing shows when.
  So are two kinds that the model does not name yet: a temporary in the
  index of a place, as `xs[vv(same(T(1)))]`, since elaboration does not
  look inside indices (#377), and a subscript that Mojo reads late
  (#191), as `same(s[1])`, which is read only once its call's arguments
  are evaluated (#378).
- The checker accepts a temporary origin argument only where elaboration
  keeps it alive. So it keeps these rejected as before #80, where the
  compiler accepts them, until the issue named:
  - a temporary in a place's index, as `print(xs[pz(same(mk(1)))])`, is
    `implicitCopy` for a `T` that cannot be copied (#377). The checker
    accepts it at first, so that a program with a later error gets the
    compiler's class, as #356's programs do. A program that it then
    accepts is checked again, rejecting it
    (`MojoGrimoire.Check.checkProgram`);
  - a late subscript as an origin argument of a `ref` binding, as
    `ref r = rpick(s[1], P(5), True)`, is `notAPlace` (#378);
  - an expression statement that returns a reference through one bound
    to a temporary, as `psame(r)` after `ref r = psame(pmk(1))`, is
    `notAPlace` (#379).

  A mutable location passed to a `ref` parameter that aliases another
  argument is `argumentExclusivity`, as the compiler reports it, when
  either may point into a temporary: `vv(pick(r, y, False))` after
  `ref r = pick(y, T(1), True)`. The compiler rejects the case with no
  temporary too, which the model still runs (#381).
