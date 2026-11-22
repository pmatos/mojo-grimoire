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
argument (`MojoGrimoire.Check.checkArg`).

The compiler finds that a binary operator rejects its operands' types as
it types them, before the later pass that finds a use of an uninitialized
value; the checker finds it from their forms then (`binaryOperands`).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Checks the operands `a` and `b` of the binary operator `op` by `check`.
When `check` throws `uninitializedUse`, and the forms of `a` and `b`,
neither of them a literal, give types (`operandTy`) that `op` rejects,
as in `k + ((t(0) and x^) or x.f)` with `k` an `Int`, that error is
reported instead: the compiler finds it as it types the operands, before
the later pass that finds the uninitialized use. A right operand passed
as an argument (`rightParam`) misfits as the argument does (`expectArg`),
and any other operation as `methodBinaryTy` says. -/
def binaryOperands {α : Type} (prog : Program) (op : BinOp) (a b : Expr) (check : CheckM α) :
    CheckM α :=
  tryCatch check fun err => do
    if err matches .uninitializedUse _ && !(a matches .list ..) && !(b matches .list ..) then
      if let (some ta, some tb) := (← operandTy prog a, ← operandTy prog b) then
        match rightParam op a b ta with
        | some (fit, prm) => expectArg fit prm.ty tb
        | none => if let .error e := methodBinaryTy prog op ta tb then throw e
    throw err

/-- The type of the binary operation `a op b`, of operand types `ta` and `tb`
(`methodBinaryTy`), once both operands are checked, the places among
them read late (`recheckPlaces`, from the marks `ka` and `kb`), but those
of `and` and `or`, which are read when tested. A test of a struct
operand of `and` or `or` whose `__bool__` returns no `Bool` lacks
`__mlir_bool__` (`missingMethod`): a call of it that inference made, and
the left operand when both have the same struct type. That operand is
also passed to `self` as a call's argument, by `passSelf`, from the state
`before` it was checked, which is then left as the operands left it. The
compiler gives a `var self` a copy of what the left test reads, a
temporary or a transfer too, since the left operand may be the result:
a struct that is not `ImplicitlyCopyable` is then `implicitCopy`. The
model still moves `p^` out of `p` there, where the compiler, on the left
of a mixed `and` or `or`, only borrows it and leaves `p` initialized
(#84). -/
def checkedBinaryTy (prog : Program) (op : BinOp) (a b : Expr) (ta tb : Ty) (ka kb : Nat)
    (before : State) (passSelf : Param → Name → CheckM Unit) : CheckM Ty := do
  unless op == .and || op == .or do
    recheckPlaces prog [a, b] [ka, kb]
    return ← lift (methodBinaryTy prog op ta tb)
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
        set before
        passSelf self (methodCallee s "__bool__")
        set after
      if isLeft && self.conv == .owned && !(e matches .place _) &&
          copyingOf prog (.struct s) != .implicit then
        throw (CheckError.implicitCopy (.struct s))
    unless fd.result == .bool do throw (CheckError.missingMethod fd.result "__mlir_bool__")
  lift (methodBinaryTy prog op ta tb)

end MojoGrimoire.Check
