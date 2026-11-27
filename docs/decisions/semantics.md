# Current decisions: semantics

This page says what holds today for what Mojo means in this project and what
the model takes as its reference.
[semantics-references.md](semantics-references.md) continues it with
references, [semantics-lists.md](semantics-lists.md) with lists and
arrays, [semantics-int-index.md](semantics-int-index.md) with an index of
an `Int`, [semantics-operators.md](semantics-operators.md) with operators
and calls on structs,
[semantics-comparisons.md](semantics-comparisons.md) with comparisons of
arrays and lists, [semantics-parser.md](semantics-parser.md) with the
parser and the driver,
[semantics-error-order.md](semantics-error-order.md) with the order of
errors, and [semantics-interpreter.md](semantics-interpreter.md) with
elaboration and the interpreter.

## The reference

The open-source Mojo compiler at a pinned version is the reference
(ADR-2026-11-15-1907). The pin is the nightly `1.3.0.dev2026111905`,
`MojoGrimoire.referenceMojo`, which reports
`Mojo 1.3.0.dev2026111905 (a549e6a6)`. `scripts/install-mojo.sh` installs
its wheel from Modular's nightly index and refuses it unless the wheels of
the driver, the compiler and the standard library have their pinned sha256.
That build's own commit is not public; the source is read at the nearest
public commit of `modular/modular`, `10c54f6f5b`, "[Release] Pin lockfiles
to Mojo 1.3.0.dev2026111905". The pin moves forward to newer nightlies, one
PR per move, by the steps of
[conformance.md](conformance.md#moving-the-pin). The human chose the
1.2 release line on 2026-11-15, and on 2026-11-19 moved the pin to the
latest nightly, as a wheel (#160). The model follows the compiler,
and [the decision log](../conformance/decision-log.md) records each place
where it departs, each a compiler bug
([conformance.md](conformance.md#the-decision-log)).

Rejected: testing against the compiler's tip, where expected results would go
stale with no change on our side. Also rejected: building the nightly from
source at a public commit, as the pin on 1.2.0 did, which gives a compiler
other than the one Modular ships, in about 25 minutes.

## Independence

The model is independent of the Isabelle formalisation `utting/mojo-semantics`
(ADR-2026-11-15-1908). It guides the Lean model: its definitions and the
statements of its theorems, such as its soundness theorem, may be used as
targets, which we state in our own terms and prove in Lean. Nothing here
calls, imports, vendors or mechanically translates it, and its test suite is
not copied. The compiler, not the Isabelle model, is the oracle. The human
ruled this on 2026-11-15.

Rejected: porting the Isabelle model and its suite, which would tie the
project to another codebase and to a suite with no licence.

## Scope of v1

v1 covers ownership and value semantics, structs, methods, lists, control
flow, integer and SIMD arithmetic, the static checker and the run-time
semantics, and a soundness theorem: accepted programs never fail with an
ownership or type error. Compile-time parameters and `comptime` evaluation,
Python interop, async, GPU kernels and codegen correctness are out of v1.

## The static checker

The checker, `MojoGrimoire.Check`, accepts a program of the core calculus
or rejects it with a class of error, `CheckError`. The conformance suite
compares these classes with the compiler's diagnostics, not their wording.
Each choice below was made from Mojo's manual at the pin, and checked
against the compiler when the suite recorded its results (#25): where the
two disagree, the model follows the compiler.

- Initialization is tracked per part of a variable: a field may be moved
  out and initialized again. The compiler destroys a struct whole, so a
  field moved out with `^` must be assigned again, at exactly its path,
  before the struct ends or a part above the field is assigned, unless
  nothing of the struct is left to destroy (see the bullet on structs
  built field by field below). Using the
  struct's other fields in between is allowed. Otherwise the program is
  rejected as `partiallyDestroyed`, which covers both of the compiler's
  messages: "destroyed out of the middle of a value" and "cannot be
  consumed, because ... is used later". The checker cannot tell which one
  the compiler gives, since that depends on what follows (#39). Nor may
  any struct end partly built, on some path, with a field never assigned
  while it holds another (D-0003, see below). Inside `__deinit__`, `self`'s own fields may
  stay moved out, but not fields of its fields.
- Until a field moved out is assigned again at its path, the compiler
  reports a use of it, or of a part above it, as `uninitializedUse`, even
  after each of its sub-fields was assigned. The same holds for a loop
  body that leaves such a field moved out, and for overwriting the struct
  through a reference.
- `p^` of type `Int`, `Bool` or `None` (#131) is the place `p`: the
  compiler warns that the transfer has no effect, and uses `p` as if `^`
  were not there. So `p`
  keeps its value, may be a `read` parameter, a field of one, a
  reference, an element of a list or an array, or a field of an element,
  is read when other places are, and may be passed to a `mut` parameter.
  Inference rewrites `p^` to `p`, so the core calculus's transfer always
  moves (#50, #43). Any other element, or a field of one, is rejected as
  `transferFromElement`, as the compiler does, even an element of an
  implicitly copyable or copyable struct type, or one that is itself a
  list (#105). The compiler rejects it once it has typed the place, its
  variable, fields and indices, whose own type errors, implicit copies,
  transfers and exclusivity come first: before it looks at what is
  initialized or invalidated, the list or an index, at a constant index
  out of range, and at the `mut` parameter it may be passed to, also
  through a reference. The model does the same (#119), in the order of
  [semantics-error-order.md](semantics-error-order.md#transfers-of-an-element). Any
  other place is typed in the same order from its variable outward
  ([semantics-error-order.md](semantics-error-order.md#the-order-inside-a-place)).
- `p^` followed by a field or a method, `p^.f` or `p^.m(…)`, is the place
  `transferred p` (#66). The compiler warns that the transfer has no
  effect, and borrows `p`: `p^.f` is the field `p.f`, read, copied or
  passed as that place is, and `p^.m(…)` calls `m` on `p`. `p` must be
  whole (`uninitializedUse`) and a value that `p^` could transfer: not a
  `read` or `ref` parameter (`transferFromBorrowed`), nor an element
  (`transferFromElement`), nor a reference bound with `ref`
  (`transferFromElement`, reported before whether its origins are whole,
  [semantics-references.md](semantics-references.md#references)).
  Nothing may change through it:
  assigning to `p^.f`, `p^.f += 1`, passing it `mut`, and a `mut self`
  method are `immutablePlace`. A method that takes `var self` consumes
  `p`, once the arguments are read, and the receiver counts as passed
  `mut` for argument exclusivity; on `p^.f` it copies the field, which
  must be implicitly copyable. `p^.f^` moves the field `p.f`. The
  compiler lets `ref r = p^.f` change `p.f` through `r`, and so does the
  model. `p^.f` passed to a `ref` parameter, and `p^` as the receiver
  of a `ref self` method, pass on an immutable reference, and the call
  changes nothing
  (#91, [semantics-references.md](semantics-references.md#references)).
- A struct variable declared without a value may be built field by field
  (#51). Mojo never counts such a struct, or a part built so, as
  initialized whole, even once every field is assigned: using it whole is
  `uninitializedUse`, as the compiler reports "used with all fields
  manually initialized". The `self` of `__init__` is the exception. A
  variable that holds nothing may end with fields moved out, since
  nothing of it is destroyed; one that still holds a part may not. A
  field moved out of a part that was held whole, or whose inside was
  assigned while it was held whole, must still be assigned again before
  the variable ends, and so must a variable moved out whole and then
  given some of its fields. A part moved out and then given some of its
  fields may not be assigned whole. The checker tracks this with the
  parts that may hold a value, the touched parts and the pieces of
  `MojoGrimoire.Check.VarState`. A variable, or a part assigned whole,
  may not end partly built, with a field never assigned while it holds
  another, however it got there: built in one branch of an `if` only,
  even wholly, or in a loop, and with fields that are all `Int`s too. The
  compiler accepts these and destroys the fields never assigned, a
  compiler bug; the human ruled on 2026-11-19 that the fixed compiler
  rejects them, as it rejects a field moved out (R,
  [D-0003](../conformance/decision-log.md)), provisionally, until the
  human has discussed it with Modular. The `self` of `__init__` built
  wholly in one branch only is whole, and may be assigned whole after it,
  as the compiler accepts with clean output. A variable held whole whose
  field was moved out and assigned again is whole too. A field moved out after another
  field's last use (#144) and a field moved out in one branch while the
  other builds another field (#137) are such shapes. Each other rule
  follows the compiler on the probes recorded on #51, except a part moved
  out whole, refilled and emptied, then assigned whole, which the model
  rejects and the compiler accepts (#145). At a return, a `mut` parameter or a part of the `self` of
  `__init__` built field by field is not initialized; a `mut` parameter
  that is itself built so is `uninitializedUse`, as the compiler reports
  it.
- A place operand, of a call, an operator, a list literal or `print`, must
  still be initialized once every operand is evaluated, since the
  compiler reads it then: `f(a.id, g(a^))` uses `a.id` after its move.
  So must the origins of an operand that is a call returning a reference,
  which the compiler also reads then (#76; see
  [semantics-references.md](semantics-references.md)).
- `print` takes string literals and values it can write: `Int`, `Bool`,
  and lists and arrays of them, nested ones included (#41); other
  strings are outside the subset (#180). It reads a place by reference,
  so it copies nothing: a list may be printed from a `read` parameter or a
  `ref` binding. A struct, or a list or an array of
  structs, is rejected as `notPrintable`, as the compiler rejects a value
  that does not conform to `Writable`.
- `return x` moves a variable the function owns. Any other returned place
  is copied implicitly, so it must be implicitly copyable.
- At every return, explicit or implicit, a `mut` parameter and the `self`
  of `__init__` must be wholly initialized. Otherwise the program is
  rejected as `uninitializedAtExit`, the class of the compiler's "is
  uninitialized at (the implicit) return from this function" (#52).
- Argument exclusivity rejects a `mut` argument that overlaps another
  argument passed as a location. The manual exempts `Int` and `Bool`, but
  the compiler rejects two aliasing `mut` arguments of any type. An `Int`
  or a `Bool` passed to a `read` parameter is copied, so it is not a
  location and never clashes.
- After an `if`, a part counts as initialized only when both branches leave
  it initialized. A loop body must leave initialized every part that was
  initialized before the loop; as the compiler does, the checker reports
  a body that does not as `uninitializedUse`. A part uninitialized before
  the loop may be assigned and moved out in each iteration. What the body
  moves out still counts in the next iteration, which the checker checks
  again from that state, and after the loop (#51).
- Only a struct has fields, and only a struct or a list has methods. A
  field or a method that the type of its receiver lacks, whatever that
  type, is one class, `unknownAttribute`, named with the type's name: the
  compiler reports both as "has no attribute" (#42,
  [conformance-classes.md](conformance-classes.md#unknown-fields-and-methods)).
- An initialization whose arguments fit no initializer is one class,
  `noMatchingInit`, however they misfit: a construction `S(…)` with a
  wrong number of arguments, a wrong one, or a value passed to a `mut`
  parameter that is not a place or cannot change; a literal that does not
  fit the list or array it initializes, or that initializes a struct or a
  `Bool`; and `List[T](e1, …, en)`, unless it has one argument that is a
  list or an array of `T` that can be copied (#103). The
  compiler reports each as "no matching function in initialization" (#46,
  [conformance-classes.md](conformance-classes.md#initializations-that-fit-no-initializer)),
  or, when the one argument has the type it initializes, as "cannot
  construct ... with itself".
- A call of a method or an operator with several overloads, none of which
  its arguments fit, a wrong number of them included, is one class,
  `noMatchingMethod`: an operator whose left operand is an integer
  literal, or an expression made only of them, an index of a list or an
  array, and a list's `pop` (#88, #169). A method that a type lacks is
  `missingMethod`: an operator's on its operand's type, such as `+` on a
  `Bool`, a struct or an array, and `__call__` on a variable that is
  called. Within its scope a variable or a parameter hides, in a call, a
  function, `len`, `range`, `print` or a struct of its name, also before
  it is initialized (#176), and calls the struct's `__call__` when it
  declares one. In a type, it hides a type of its name: `valueAsType`
  (#193). An operator or a
  call on a struct calls the method it declares
  ([semantics-operators.md](semantics-operators.md), #191); operator
  methods that a trait supplies are not yet modelled (#194). The checker finds a missing method from the
  operands' types before it reads them, as the compiler does
  ([conformance-classes.md](conformance-classes.md#calls-that-fit-no-overload-and-methods-a-type-lacks),
  [semantics-error-order.md](semantics-error-order.md#calls-and-initializers)).
- A struct may not lie on a cycle of fields with no field that holds the
  next struct through a list, such as a struct that holds itself directly
  or through arrays: the compiler rejects it, and so does the model
  (`recursiveStruct`). A cycle with a field through a list is accepted,
  through any number of structs and arrays, whatever its other fields,
  whether or not its structs have a `__deinit__`, and whether or not
  `@fieldwise_init` builds the initializers. The compiler rejects some
  of these cycles, depending on which of their structs have a `__deinit__`
  (D-0006, #136), and some `@fieldwise_init` forms (D-0004, #47), both
  compiler bugs ([conformance-classes.md](conformance-classes.md#cycles-of-structs)). The
  ruling on #136 is provisional until the human has discussed it with
  Modular.
- A struct that declares `Copyable`, or `ImplicitlyCopyable`, is
  rejected when a field cannot be copied so, `uncopyableField`. Where it
  comes among the compiler's errors is in
  [semantics-error-order.md](semantics-error-order.md#the-order-of-the-type-phase)
  (#164).
- A declaration may not reuse the name of a variable in scope, a
  parameter included, so no variable hides another. Sibling blocks may
  reuse a name. ASAP elaboration relies on this, since it tracks
  variables by name.

### Lists and arrays

The choices for lists and arrays are on
[semantics-lists.md](semantics-lists.md).

### References

The decisions on `ref` bindings and functions that return a reference are
on [semantics-references.md](semantics-references.md).
