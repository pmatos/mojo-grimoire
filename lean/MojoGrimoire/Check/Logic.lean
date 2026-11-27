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
(`passLeft`). The left operand's test comes before the right operand is
checked, as the compiler converts the left operand first (`leftTest`,
#357).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Passes the left operand `a` of a same-type test, of type `t`, to the
parameter `self` of `callee`, without checking it again. It mirrors
`checkArg` (`MojoGrimoire.Check.checkArg`) once that has checked its
argument: a change to how `checkArg` passes an argument must be made here
too. The check that `checkArg` would make again repeats the first one: it
starts from the same state, `before`, and checks `a` by reference, as
`checkBinary` checks the left operand of a same-type test, which only
leaves out the copy of the value (`refResult`, `copiedValue`) and fits
wherever the value did. So a place is passed from the state
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
        throw (Fit.call.misfit (temporaryPassedMut callee))
      expectArg .call self.ty t

/-- Checks the test of the struct operand `e` of `and` or `or`, of the
struct `s`, with its `__bool__`: what that returns must be a `Bool`, which
the compiler converts with `__mlir_bool__`, or the operator is
`missingMethod`. When `same` holds, both operands have the type `s`, and
the left one, `a`, of type `t`, is passed to `self` as a call's argument
(`passLeft`), from the state `before` it was checked and the state
`afterLeft` once it was, without being checked again; the state is then
left as it was. The compiler gives a `var self` a copy of what the left
test reads, a temporary or a transfer too, since the left operand may be
the result: a struct that is not `ImplicitlyCopyable` is then
`implicitCopy`. The model still moves `p^` out of `p` there, where the
compiler, on the left of a mixed `and` or `or`, only borrows it and leaves
`p` initialized (#84). A `deinit self` takes that copy too, which the pin
reports before anything else of the test, though the model then rejects
the convention. The receiver's misfit comes before the result's, as the
pin reports them. -/
def testOperand (prog : Program) (s : Name) (e : Expr) (isLeft same : Bool) (a : Expr) (t : Ty)
    (before afterLeft : State) : CheckM Unit := do
  let some fd := (findStruct prog s).bind (findMethod · "__bool__") | return
  if let some self := fd.params.head? then
    if isLeft && (self.conv == .owned || self.conv == .deinit) && !(e matches .place _) &&
        copyingOf prog (.struct s) != .implicit then
      throw (CheckError.implicitCopy (.struct s))
    if same then
      let after ← get
      passLeft prog self (methodCallee s "__bool__") a t before afterLeft
      set after
  unless fd.result == .bool do throw (CheckError.missingMethod fd.result "__mlir_bool__")

/-- Whether the operator `op` is `and` or `or` on operands `a` and `b` of the
same struct type, found from their forms (`operandTy`) before they are
checked: then the operator gives the operand that decides, and inference
converted neither with `__bool__` (`MojoGrimoire.Parse.toBool`). -/
def sameTest (prog : Program) (op : BinOp) (a b : Expr) : CheckM Bool := do
  unless op == .and || op == .or do return false
  unless (boolTest a).isNone && (boolTest b).isNone do return false
  let ta ← operandTy prog a
  pure (ta matches some (.struct _) && ta == (← operandTy prog b))

/-- The missing `__bool__` of the left operand `a` of `and` or `or`, found
from its form (`lackingTy`) before it is read: the compiler converts the
left operand before it looks at the right one (#357). An integer literal
is left to checking, as `binaryMisfit` leaves it. -/
def leftLacks (prog : Program) (op : BinOp) (a : Expr) : CheckM (Option CheckError) := do
  unless op == .and || op == .or do return none
  if intLiteral a then return none
  pure (lacks prog "__bool__" (← lackingTy prog (operandTy prog) a))

/-- Checks the test of the left operand `a` of `and` or `or`, of type `ta`,
once it is checked and before the right operand is (#357), as the
compiler converts it first: the call of `__bool__` that inference made,
or, when both operands have the same struct type (`same`), the test that
`testOperand` checks, then the method that `ta` lacks. -/
def leftTest (prog : Program) (op : BinOp) (a : Expr) (ta : Ty) (same : Bool)
    (before afterLeft : State) : CheckM Unit := do
  unless op == .and || op == .or do return
  match boolTest a, ta with
  | some (s, e), _ => testOperand prog s e true false a ta before afterLeft
  | none, .struct s => if same then testOperand prog s a true true a ta before afterLeft
  | none, _ => pure ()
  if let some err := lacks prog (binaryMethod op) (some ta) then throw err

/-- Whether the left operand `a` of a same-type test (`same`) is read by
reference, uncopied, and copied only once the right operand is checked,
after its own errors, as the pin reports them: when its struct's
`__bool__` borrows `self`. A `var` or `deinit` `self` takes a copy as the
operand is tested, which comes first. -/
def copiedLate (prog : Program) (same : Bool) (a : Expr) : CheckM Bool := do
  unless same do return false
  let some (.struct s) ← operandTy prog a | return false
  let some fd := (findStruct prog s).bind (findMethod · "__bool__") | return false
  pure (fd.params.head?.all fun p => p.conv != .owned && p.conv != .deinit)

/-- Whether checking the operand `e` as a value copies what it gives: a
place, and a call that returns a reference (`refResult`). -/
def copiedValue (prog : Program) : Expr → CheckM Bool
  | .place _ => pure true
  | .call f _ => do
    if (← findVar f).isSome then return false
    pure ((callSig prog f).toOption.any (·.origin.isSome))
  | .method p m args => tryCatch (do
      pure ((methodSig prog (← placeTy prog p) m args.length).toOption.any (·.origin.isSome)))
      fun _ => pure false
  | .withDrops e _ _ => copiedValue prog e
  | _ => pure false

/-- The type of the binary operation `a op b`, of operand types `ta` and `tb`
(`methodBinaryTy`), once both operands are checked, the places among
them read late (`recheckPlaces`, from the marks `ka` and `kb`), and, once
the operation is typed, what a literal operand reads late
(`recheckLiterals`, #282), but those of `and` and `or`, which are read
when tested. The left operand of `and` and `or` is tested before the
right one is checked (`leftTest`), when `tested` holds; the test of a
struct operand on the right whose `__bool__` returns no `Bool` lacks
`__mlir_bool__` (`testOperand`). When both have the same struct type,
which their forms did not show, the left one is tested here, from the
state `before` it was checked and the state `afterLeft` once it was; the
state is then left as the operands left it. -/
def checkedBinaryTy (prog : Program) (op : BinOp) (a b : Expr) (ta tb : Ty) (ka kb : Nat)
    (before afterLeft : State) (tested : Bool) : CheckM Ty := do
  unless op == .and || op == .or do
    recheckPlaces prog [a, b] [ka, kb]
    let t ← lift (methodBinaryTy prog op ta tb)
    recheckLiterals prog [a, b] [ka, kb]
    return t
  if !tested && (boolTest a).isNone && ta == tb then
    if let .struct s := ta then testOperand prog s a true true a ta before afterLeft
  if let some (s, e) := boolTest b then testOperand prog s e false false a ta before afterLeft
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

end MojoGrimoire.Check
