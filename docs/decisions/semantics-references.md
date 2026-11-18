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
  origins are those of their own origin arguments (#69). A temporary is
  rejected (`notAPlace`), where the compiler accepts it (#80).
- A use of a reference needs every origin initialized, so a value moved
  away cannot be used through a reference to it. A value cannot be
  transferred out through a reference: `t^`, `t.f^`, `t^.f` and
  `t^.m(…)` on a reference `t` are rejected as `transferFromElement`, as
  the compiler does ("expression does not designate a value with an
  origin"), whether `t` is bound to a place or to a call that returns a
  reference, whether it may be changed or not, even when its origins are
  moved away or invalidated, and when `t^` is passed to a `mut` parameter,
  of a function or an initializer: the compiler rejects the transfer
  before it looks at the origins or matches the argument, though after it
  finds an index of a type other than `Int`. A `ref` or a `read` parameter
  stays `transferFromBorrowed`, also passed to a `mut` parameter (#85).
  `t^` of type `Int` or `Bool` is the place `t` (#50).
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
  its elements in place. Any other change to an origin while a reference to it
  is live is not rejected.
- A place operand that goes through a list element is located before the
  operands after it are evaluated, and read once they all are. A later
  operand that changes the list invalidates it, and the model rejects the
  operation, as the compiler does: `print(xs[0], xs.pop())`.
- An assignment through a reference into a list element is rejected
  (`invalidatedReference`) when its own value invalidates the reference:
  `ref e = xs[0]; e = grow(xs)`. The compiler accepts that and stores into
  a stale element, as it does for `xs[0] = grow(xs)`; the human ruled on
  2026-11-16 that this is a compiler bug (#57,
  [D-0002](../conformance/decision-log.md)). The model evaluates the value
  of `xs[0] = grow(xs)` first, then stores into the grown list. It keeps
  rejecting the `ref` form, since running it could leave the interpreter
  stuck when the call shrinks the list.
- An assignment into a list element is rejected (`argumentExclusivity`)
  when the value is a call that builds its result in place and is passed
  `mut` the list, or a place that holds it: `xs[0] = xs.pop()`. A call
  builds its result in place unless it returns an `Int`, a `Bool` or a
  reference. `pop` always does, since its result has a generic type.
- A call that returns a reference, used as a value, copies the value
  implicitly. Printed, an operand of a binary operator other than `and`
  and `or`, an argument passed by value or an element of a list or an
  array literal, it is read only once every operand of the operation is
  evaluated, as the compiler does (#76). Its origins must then still be
  initialized (`uninitializedUse`), and not invalidated by a later operand
  (`invalidatedReference`): `print(pick(xs[0], b, True), xs.pop())` is
  rejected. An origin argument that is a temporary is left out, and the
  others are checked: `print(pick([1], b, False), eat(b^))` is rejected.
  The interpreter destroys such a temporary when the inner call returns,
  where the compiler keeps it until the reference is read (#98). The
  operand of a unary operator, `and` or `or` is read at once. Passed to
  `len`, or to a `read`, `mut` or `ref` parameter, it is a location when it is a located operand, as the compiler does
  (#69): it is not copied, it
  overlaps what its origins overlap for argument exclusivity (`n(first(xs),
  xs)` is rejected when `n` takes its second argument `mut`), it must be
  mutable for `mut` (`immutablePlace`), and the call changes its origins
  as it would a place. Its origins must still be initialized, and not
  invalidated, once the call's later arguments are evaluated. An `Int` or
  a `Bool` passed `read` is copied, and a `var` parameter copies it
  implicitly. One with a temporary origin argument is checked as a value
  (#80). The interpreter still passes the reference, so the temporary is
  destroyed once, when the inner call returns, which matches the
  compiler's output for `show(id(P(1)))` with an implicitly copyable `P`.
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
