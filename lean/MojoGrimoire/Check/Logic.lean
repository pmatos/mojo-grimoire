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

A struct test also bridges an order of `main`'s, until #96 part 4
types a function before it checks its flow, as the compiler does.
`main` rejected every struct test as `typeMismatch` once its operands
were checked, so any error that the compiler reports in its later pass
and that the checker finds after a struct test, in the same statement,
was `main`'s `typeMismatch`, which is also the compiler's first error
whenever that statement has a type error. Such an error is reported as
`main`'s still (`bridged`, `State.mainTests`): `typeMismatch`, or the
misfit of an operator on the test's `Bool`, which `main` rejected once
it had typed the operands (`mainOperator`). An error before the test is
reported as it is, as on `main`. #96 part 4 removes the bridge.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Rejects a struct test, as `main` did, when the state replays `main`'s
order (`State.mainTests`): `typeMismatch` of a `Bool` and the struct `s`. -/
def mainTest (s : Name) : CheckM Unit := do
  if (← get).mainTests then throw (CheckError.typeMismatch .bool (.struct s))

/-- Checks the operand `a` of `not` by `check`, then rejects a test of a
struct there as `main` did, when the state replays `main`'s order
(`mainTest`). -/
def notOperand (a : Expr) (check : CheckM Ty) : CheckM Ty := do
  let t ← check
  if let some (s, _) := boolTest a then mainTest s
  pure t

/-- Follows `main`'s order, when the state replays it, at the call of the
operator method `f` of a struct that inference made from an operator
whose left operand, or whose one operand for `-`, is `and` or `or` of
two operands of that struct, with the operands `args`, which `typing`
types (`typeArgs`). `main` typed that operand as a `Bool`. When the
operator fits no `Bool` (`binaryMisfit`, `unaryMisfit`), it typed the
operands in `State.typing` before it read
them, and then rejected the misfit (`MojoGrimoire.Check.rejectAfter`).
Typing an operand stops at an error of a later pass, which it leaves
out (`typeArg`), and at a struct test, which the replay rejects as `main`
did (`mainTest`): so a test reached first is `typeMismatch`, and else the
misfit itself, such as `missingMethod` for `+` on a `Bool`. -/
def mainOperator (prog : Program) (f : Name) (args : List Expr) (typing : CheckM Unit) :
    CheckM Unit := do
  unless (← get).mainTests do return
  let (some (_, m, false), .binary lop _ _ :: rest) := (calleeMethod f, args) | return
  unless lop == .and || lop == .or do return
  let misfit ← match rest with
    | [] => pure (if m == "__neg__" then unaryMisfit prog .neg (some .bool) else none)
    | [r] => do
      let ops := [BinOp.add, .sub, .mul, .floorDiv, .mod, .lt, .le, .gt, .ge, .eq, .ne]
      match ops.find? (binaryMethod · == m) with
      | some op => pure (binaryMisfit prog op (some .bool) (← operandTy prog r))
      | none => pure none
    | _ => pure none
  if let some err := misfit then rejectAfter typing err

/-- Runs `check`, the check of one statement or of a condition. When it
throws an error of the compiler's later pass (`CheckError.late`), it is
run again from the same state replaying `main`'s order
(`State.mainTests`), which differs only where `main` rejected a struct
test (`mainTest`, `mainOperator`): when the replay ends in an error that
is not of the later pass, it is `main`'s and is reported, and else the
error stands. A temporary bridge until #96 part 4. -/
def bridged {α : Type} (check : CheckM α) : CheckM α :=
  tryCatch check fun err => do
    unless err.late do throw err
    modify fun st => { st with mainTests := true }
    let replayed ← tryCatch (do let _ ← check; pure err) pure
    throw (if replayed.late then err else replayed)

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
(#84). Once both operands are checked, where `main` rejected a struct
test, it is rejected so again when the state replays `main`'s order
(`mainTest`). -/
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
  if let some (s, _, _, _) := (left ++ right).head? then mainTest s
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
