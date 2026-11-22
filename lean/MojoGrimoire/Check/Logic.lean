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
were checked, so an error that the checker finds after a struct test, in
the same statement, was `main`'s `typeMismatch`, or an error that
`main` found first, in an order of its own. Such a statement is checked
again replaying `main`'s order (`bridged`, `State.mainTests`), and
`main`'s error is reported, unless it is of the compiler's later pass:
then the first error stands. An error of the test itself, such as a
`__bool__` that returns no `Bool`, stays only when the statement holds
no other error; else `main`'s `typeMismatch` came first, and stands
(`State.ownChecks`). #96 part 4 removes the bridge.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Rejects a struct test, as `main` did, when the state replays `main`'s
order (`State.mainTests`): `typeMismatch` of a `Bool` and the struct `s`. -/
def mainTest (s : Name) : CheckM Unit := do
  if (← get).mainTests then throw (CheckError.typeMismatch .bool (.struct s))

/-- Reads, as `main` did when the state replays its order, the operand of
the test of a struct that the operand `a` of `and`, `or` or `not` is
once `check` has checked it as a call of `__bool__` (`boolTest`). `main`
read that operand as a value, which copies a place: a struct that is not
`ImplicitlyCopyable` is then `implicitCopy`. -/
def mainRead (prog : Program) (a : Expr) (check : CheckM Ty) : CheckM Ty := do
  let t ← check
  if let some (s, .place _) := boolTest a then
    if (← get).mainTests && copyingOf prog (.struct s) != .implicit then
      throw (CheckError.implicitCopy (.struct s))
  pure t

/-- Checks the operand `a` of `not` by `check` (`mainRead`), then rejects
a test of a struct there as `main` did, when the state replays `main`'s
order (`mainTest`). -/
def notOperand (prog : Program) (a : Expr) (check : CheckM Ty) : CheckM Ty := do
  let t ← mainRead prog a check
  if let some (s, _) := boolTest a then mainTest s
  pure t

/-- Whether the expression `e` is `and` or `or` of two operands of the
same struct type, which it has (`operandTy`): a same-type test, which
`main` typed as a `Bool`. -/
def sameTest (prog : Program) (e : Expr) : CheckM Bool :=
  match e with
  | .binary op _ _ => do
    pure ((op == .and || op == .or) && (← operandTy prog e) matches some (.struct _))
  | _ => pure false

/-- The type of the operand `e` found from its form (`operandTy`), but,
when the state replays `main`'s order, with `and` and `or` typed as a
`Bool` at any depth, as `main` typed them: a same-type test (`sameTest`)
too, and one inside a literal, `[x or y]` an array of `Bool`. -/
def mainFormTy (prog : Program) (e : Expr) : CheckM (Option Ty) := do
  operandTy prog e (← get).mainTests

/-- The binary operator whose method, or whose reflected method when
`reflected` holds, is `m`. -/
def methodOperator (m : Name) (reflected : Bool) : Option BinOp :=
  [BinOp.add, .sub, .mul, .floorDiv, .mod, .lt, .le, .gt, .ge, .eq, .ne].find? fun op =>
    (if reflected then reflectedMethod op else binaryMethod op) == m

/-- The method that `main`'s inference called for the operator `op` on
operands it typed as `ta` and `tb`, one of them a same-type test that it
typed as a `Bool` (`MojoGrimoire.Parse.chooseBinary`): the method of the
left operand's struct, whether or not the right one fits it, else the
reflected method of the right operand's struct, when it takes the left
operand's type, not as `mut`, and its `self` takes the right operand
(`canB`, for a `mut self`); `none` leaves the operator as it is. -/
def mainCallee (prog : Program) (op : BinOp) (ta tb : Option Ty) (canB : Bool) :
    Option Name :=
  let declared (t : Option Ty) (m : Name) : Option (Name × FunDecl) := match t with
    | some (.struct s) => ((findStruct prog s).bind (findMethod · m)).map (s, ·)
    | _ => none
  match declared ta (binaryMethod op), declared tb (reflectedMethod op) with
  | some (s, _), _ => some (methodCallee s (binaryMethod op))
  | none, some (s, fd) =>
    match fd.params with
    | [self, prm] =>
      if ta == some prm.ty && prm.conv != .mutable && (self.conv != .mutable || canB) then
        some (methodCallee s (reflectedMethod op) true)
      else none
    | _ => none
  | none, none => none

/-- Follows `main`'s order, when the state replays it, at the call `f` of
an operator's method of a struct that inference made, with the operands
`args`, which `typing` types (`typeArgs`), when an operand is a same-type
test (`sameTest`). `main` typed that operand as a `Bool` (`mainFormTy`),
and its inference chose the operator's method from those types
(`mainCallee`): when it chose a method, the call is checked as a call of
it, and that method is given; when none, `main` rejected the operator's
misfit on those types (`operandMisfit`, `unaryMisfit` for `-`) once it
had typed the operands in `State.typing`
(`MojoGrimoire.Check.rejectAfter`), and else read them in order, as the
call does. Typing an operand stops at an error of a later pass, which it
leaves out (`typeArg`), and at a struct test, which the replay rejects as
`main` did (`mainTest`): so a test reached first is `typeMismatch`, and
else the misfit itself, such as `missingMethod` for `+` on a `Bool`. -/
def mainOperator (prog : Program) (f : Name) (args : List Expr) (typing : CheckM Unit) :
    CheckM Name := do
  unless (← get).mainTests do return f
  let some (_, m, reflected) := calleeMethod f | return f
  match args with
  | [a] =>
    if m == "__neg__" && !reflected && (← sameTest prog a) then
      rejectMisfit (unaryMisfit prog .neg (some .bool)) typing
    return f
  | [a, b] =>
    let some op := methodOperator m reflected | return f
    unless (← sameTest prog a) || (← sameTest prog b) do return f
    let canB ← match b with
      | .place p => passedMutable p
      | _ => pure false
    if let some g := mainCallee prog op (← mainFormTy prog a) (← mainFormTy prog b) canB then
      return g
    rejectMisfit (← operandMisfit prog op a b (mainFormTy prog)) typing
    return f
  | _ => return f

/-- Runs `check`, the check of one statement or of a condition. When it
throws an error, it is run again from the same state replaying `main`'s
order (`State.mainTests`), which differs only where a struct test is
involved (`mainTest`, `mainRead`, `mainOperator`), first with the checks
of a struct test itself before `main`'s rejection of it, then without
them (`State.ownChecks`), as `main` had none. When the two replays end
differently, a test's own check failed first: its error stands only when
the statement holds no other error, which a third run, in this PR's order
without those checks, shows; else `main` reported the test's
`typeMismatch`, and the second replay's error is `main`'s. A replay's
error that is not of the compiler's later pass (`CheckError.late`) is
reported, and else the first error stands. A temporary bridge until #96
part 4. -/
def bridged {α : Type} (check : CheckM α) : CheckM α :=
  tryCatch check fun err => do
    let start ← get
    let run (main own : Bool) : CheckM (Option CheckError) := do
      set { start with mainTests := main, ownChecks := own }
      tryCatch (do let _ ← check; pure none) (fun e => pure (some e))
    let withOwn ← run true true
    let asMain ← run true false
    let replayed ← if withOwn == asMain then pure withOwn
      else if (← run false false).isSome then pure asMain else pure withOwn
    match replayed with
    | some e => throw (if e.late then err else e)
    | none => throw err

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
(#84). When the state replays `main`'s order, a struct test is then
rejected as `main` rejected it once both operands were checked
(`mainTest`), after those checks of the test itself, whose errors `main`
could not report. When the state leaves those checks out
(`State.ownChecks`), the test is rejected so, or passes with no check
of its own, a tested call taken as a `Bool`. -/
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
  unless (← get).ownChecks do
    if let some (s, _, _, _) := (left ++ right).head? then mainTest s
    let mixed := left.any (!·.2.2.2)
    return ← lift (methodBinaryTy prog op (if mixed then .bool else ta)
      (if right.isEmpty then tb else .bool))
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
  if let some (s, _, _, _) := (left ++ right).head? then mainTest s
  lift (methodBinaryTy prog op ta tb)

end MojoGrimoire.Check
