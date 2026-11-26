import MojoGrimoire.Check.Compare

/-!
The test of a struct operand of `and` and `or` (#191). The compiler tests
such an operand with its struct's `__bool__`, and converts what that
returns with `__mlir_bool__`, which only a `Bool` implements. Inference
makes the test a call of `S.__bool__` when the operands have different
types (`MojoGrimoire.Parse.toBool`), which the checker checks as any
call. When both have the struct type `S`, the operator gives the operand
that decides, and the test of the left one is no call of its own: it is
checked here as that call would be, its operand passed to `self` as an
argument (`MojoGrimoire.Check.checkArg`), without being checked again
(`passLeft`).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Passes the left operand `a` of a same-type test, of type `t`, to the
parameter `self` of `callee`, without checking it again. It mirrors
`checkArg` (`MojoGrimoire.Check.checkArg`) once that has checked its
argument: a change to how `checkArg` passes an argument must be made here
too. The check that `checkArg` would make again repeats the first one: it
starts from the same state, `before`, and checks `a` as a value, as `and`
and `or` do (`byRef`), or, for a located operand, by reference, which
only leaves out the copy of the reference a call returns (`refResult`)
and fits wherever the value did. So a place is passed from the state
`after` the first check, which reading the place leaves as checking its
indices left it, and any other operand from `before`. `checkArg`'s
`notAList` for a place through the element of an `Int` cannot arise, as
such a place has no struct type, and a literal is passed as any other
value is. Checking `a` again would cost twice the check of `a`, at each
level of a nested left operand. -/
def passLeft (prog : Program) (self : Param) (callee : Name) (a : Expr) (t : Ty)
    (before after : State) : CheckM Unit := do
  match a with
  | .place p =>
    set after
    passPlace prog .call callee self.conv self.ty p
  | e =>
    set before
    if self.conv == .out || self.conv == .deinit then
      throw (CheckError.invalidConvention callee)
    match ← if passedByValue self then pure none else locOf prog e with
    | some (os, mq) =>
      expectArg .call self.ty t
      if self.conv == .mutable && !mq then
        throw (Fit.call.misfit (CheckError.immutablePlace (os.headD (.var callee))))
    | none =>
      if self.conv == .mutable then
        if let .transfer p := e then
          unless ← placeMutable p do throw (CheckError.transferFromBorrowed p)
        throw (Fit.call.misfit (CheckError.notAPlace callee))
      expectArg .call self.ty t

/-- The type of the binary operation `a op b`, of operand types `ta` and `tb`
(`methodBinaryTy`), once both operands are checked, the places among
them read late (`recheckPlaces`, from the marks `ka` and `kb`), and, once
the operation is typed, what a literal operand reads late
(`recheckLiterals`, #282), but those of `and` and `or`, which are read
when tested. A test of a struct
operand of `and` or `or` whose `__bool__` returns no `Bool` lacks
`__mlir_bool__` (`missingMethod`): a call of it that inference made, and
the left operand when both have the same struct type. That operand is
also passed to `self` as a call's argument (`passLeft`), from the state
`before` it was checked and the state `afterLeft` once it was, without
being checked again; the state is then left as the operands left it. The
compiler gives a `var self` a copy of what the left test reads, a
temporary or a transfer too, since the left operand may be the result:
a struct that is not `ImplicitlyCopyable` is then `implicitCopy`. The
model still moves `p^` out of `p` there, where the compiler, on the left
of a mixed `and` or `or`, only borrows it and leaves `p` initialized
(#84). -/
def checkedBinaryTy (prog : Program) (op : BinOp) (a b : Expr) (ta tb : Ty) (ka kb : Nat)
    (before afterLeft : State) : CheckM Ty := do
  unless op == .and || op == .or do
    recheckPlaces prog [a, b] [ka, kb]
    let t ← lift (methodBinaryTy prog op ta tb)
    recheckLiterals prog [a, b] [ka, kb]
    return t
  let left := match boolTest a, ta, tb with
    | some (s, e), _, _ => [(s, e, true, false)]
    | none, .struct s, .struct s' => if s == s' then [(s, a, true, true)] else []
    | none, _, _ => []
  let right := (boolTest b).toList.map fun (s, e) => (s, e, false, false)
  for (s, e, isLeft, same) in left ++ right do
    let some fd := (findStruct prog s).bind (findMethod · "__bool__") | continue
    if let some self := fd.params.head? then
      if same then
        let after ← get
        passLeft prog self (methodCallee s "__bool__") a ta before afterLeft
        set after
      if isLeft && self.conv == .owned && !(e matches .place _) &&
          copyingOf prog (.struct s) != .implicit then
        throw (CheckError.implicitCopy (.struct s))
    unless fd.result == .bool do throw (CheckError.missingMethod fd.result "__mlir_bool__")
  lift (methodBinaryTy prog op ta tb)

/-- Whether the comparison `op` of `a` and `b` has, on the left, a literal
that holds an inner literal of another length than one where an `Int` is
expected, that keeps no checks from before #166 but for that inner literal
(`keepsBefore`), and that fits the type of `b`, no literal, once that
inner literal is typed as the compiler types it: as off the left
(`literalFits`). The compiler fails SIMD's constraint only when it
instantiates the call, so the type phase finds no error in such a
comparison but those of its operands (#96). -/
def typedSimdLeft (prog : Program) (op : BinOp) (a b : Expr) : CheckM Bool := do
  unless a matches .list .. && !(b matches .list ..) && compares op do return false
  if ← keepsBefore prog op a b then return false
  let some t ← operandTy prog b | return false
  unless (← operandFit prog op a (some t) true) == some none do return false
  pure ((← literalFits (operandTy prog) false t a) == some true)

/-- How the comparison `op` builds its left operand `a`, a literal that
holds a place whose value is not implicitly copyable (`heldCopy`), when
that does not wait for #338: `true` when it is converted to the type of
`b`, no literal, that it fits (`operandFit`), and `false` when it is
built on its own, beside a literal `b` or a known type of `b` that it is
not converted to or does not fit. The compiler types the operands' own
expressions first, then builds the literal, and reports its copies
before the comparison's misfit. -/
def heldLeft (prog : Program) (op : BinOp) (a b : Expr) : CheckM (Option Bool) := do
  unless compares op do return none
  unless ← heldCopy prog a do return none
  if b matches .list .. then return if emptyList b then none else some false
  let some t ← operandTy prog b | return none
  pure (match ← operandFit prog op a (some t) true with
    | some (some true) => some true
    | some none => none
    | _ => some false)

end MojoGrimoire.Check
