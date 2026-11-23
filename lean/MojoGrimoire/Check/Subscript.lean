import MojoGrimoire.Check.Ref

/-!
The assignment of a subscript of a struct (#191). Inference makes
`q[i] = v` a call of the struct's `__setitem__` when it declares one,
which the checker checks as any call, after what the compiler checks
first (`checkSetter`). A subscript of a struct that declares
`__getitem__` but not `__setitem__` is the value that the getter gives,
and may not be assigned (`valueSubscript`).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The call of the getter that the subscript `p` reads, when `p` is one of
a struct that declares `__getitem__` but not `__setitem__`. The subscript
is the value that the getter gives, which may not change: the compiler
rejects an assignment to it once it has checked the call, before the
value assigned (#191). -/
def valueSubscript (prog : Program) (p : Place) : CheckM (Option Expr) := do
  if let .index q i := p then
    if let .struct s ← placeTy prog q then
      if (findStruct prog s).any fun sd =>
          (findMethod sd "__getitem__").isSome && (findMethod sd "__setitem__").isNone then
        return some (.call (methodCallee s "__getitem__") [.place q, i])
  pure none

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
