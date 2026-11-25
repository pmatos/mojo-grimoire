import MojoGrimoire.Check.Ref

/-!
The assignment of a subscript of a struct (#191). Inference makes
`q[i] = v` a call of the struct's `__setitem__` when it declares one,
which the checker checks as any call, after what the compiler checks
first (`checkSetter`). A subscript of a struct that declares
`__getitem__` but not `__setitem__` is what the getter gives, and is
assigned only through a reference that may be changed through
(`valueSubscript`, `assignGetter`).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The call of the getter that the subscript `p` reads, when `p` is one of
a struct that declares `__getitem__` but not `__setitem__`: the subscript
is what the getter gives, and its assignment is checked through it
(`assignGetter`, #191). -/
def valueSubscript (prog : Program) (p : Place) : CheckM (Option Expr) := do
  if let .index q i := p then
    if let .struct s ← placeTy prog q then
      if (findStruct prog s).any fun sd =>
          (findMethod sd "__getitem__").isSome && (findMethod sd "__setitem__").isNone then
        return some (.call (methodCallee s "__getitem__") [.place q, i])
  pure none

/-- Checks `q[i] = e`, an assignment of the subscript `p` of a struct that
declares `__getitem__` but not `__setitem__`, given `g`, the call of its
getter (`valueSubscript`), and `value`, which checks `e` against a type.
The compiler first types the call, by reference: its type errors and its
implicit copies come first, but not a later pass's errors, such as a read
of a moved receiver. A getter that returns a value, or a reference that
may not be changed through, gives a place that may not change:
`immutablePlace`, before those later errors and before `e` is checked.
Through a
reference that may be changed, `e` is checked against the type it points
to, and the assignment is then `notAList`, as main reports it, as for any
subscript of a struct used as a place beyond reading it and assigning it
through a setter: its write through the reference is not yet modelled
(#198). -/
def assignGetter (prog : Program) (p : Place) (g : Expr) (value : Ty → CheckM Unit) :
    CheckM Unit := do
  let s0 ← get
  modify State.typing
  try let _ ← checkExprAs prog true g
  catch err => unless err.late do throw err
  set s0
  unless (← locOf prog g) matches some (_, true) do throw (CheckError.immutablePlace p)
  let t ← checkExprAs prog true g
  if let (some (_, true), .index q _) := (← locOf prog g, p) then
    value t
    throw (CheckError.notAList (← placeTy prog q))
  throw (CheckError.immutablePlace p)

/-- Checks what the compiler checks of `q[i] = v` before it calls the
setter, when `e` is the call `S.__setitem__(q, i, v)` that inference makes
of it (#191): the types of the call of the getter `q[i]`, which is not
made, so neither its implicit copies nor a later pass's errors count, then
the type of `v` against what the getter gives (`typeArg`). A literal of
`Int`s of the wrong length fails later, after the setter's receiver. The
state is left as it was. -/
def checkSetter (prog : Program) (e : Expr) : CheckM Unit := do
  let .call f (.place q :: args) := e | pure ()
  let some (s, "__setitem__", false) := calleeMethod f | pure ()
  let some v := args.getLast? | pure ()
  let g := methodCallee s "__getitem__"
  let s0 ← get
  modify State.typing
  try let _ ← checkExprAs prog false (.call g (.place q :: args.dropLast))
  catch err => unless err.late || err matches .implicitCopy _ | .noMatchingInit .int do throw err
  if let (.ok sig, false) :=
      (callSig prog g, v matches .list .unknown _ || (wrongIntLiteral v).isSome) then
    expect sig.result (← typeArg prog v)
  set s0

end MojoGrimoire.Check
