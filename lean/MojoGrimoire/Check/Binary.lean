import MojoGrimoire.Check.Logic

/-!
The checking of a binary operation, for `MojoGrimoire.Check.checkExprAs`,
which passes the checks of its operands (#338).

A binary operation's misfit, found from its operands' forms, is reported
before they are read (`operandMisfit`), once they are typed; then its left
operand is checked, and its right one, as an argument of the operator's
method when it is one (`rightParamOf`), each read by reference where a
comparison takes it so (`byRef`), and the operation is typed
(`checkedBinaryTy`). The left operand of `and` and `or` is converted
with `__bool__` before the right operand is looked at, as the compiler
converts it (#357): a type that lacks `__bool__`, found from the left
operand's form once it is typed, and then its test (`leftTest`). When
both operands have the same struct type, the operator gives the one that
decides, and the left one, unless its `__bool__` takes a `var` or
`deinit` `self`, is read by reference, uncopied, and copied once the
right one is checked, after the right one's own errors (`copiedLate`). In the type
phase, a comparison that only that phase converts types its operands
alone (`typedSimdLeft`). A literal on the left
of a comparison that holds a place whose value is not implicitly copyable
is built once both operands' own expressions are typed, as the compiler
builds it (`heldLeft`): one that the comparison does not convert, or that
does not fit, is checked in full before the misfit, so that its own
errors, its copies among them, come first.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

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

/-- Checks the binary operation `op` of the operands `a` and `b`, given the
checks that `checkExprAs` makes of them: `typeA` and `typeB` type each
(`typeArg`), `checkA` and `checkB` check each, by reference when they are
passed `true`, `ownA` types the own expressions of the elements of `a`
when it is a literal (`ownArgs`), and `argB` checks `b` as an argument of
the operator's method (`checkArg`). -/
def checkBinary (prog : Program) (op : BinOp) (a b : Expr) (typeA typeB : CheckM Ty)
    (checkA checkB : Bool → CheckM Ty) (ownA : CheckM Unit) (argB : Fit → Param → CheckM Unit) :
    CheckM Ty := do
  if (← get).phase == .type then
    if ← typedSimdLeft prog op a b then
      let _ ← typeA
      let _ ← checkB true
      return .bool
  let held ← heldLeft prog op a b
  let typing : CheckM Unit := if held.isSome then do ownA; let _ ← typeB else pure ()
  typedFirst typing do
    rejectMisfit (← leftLacks prog op a) (discard typeA)
    rejectMisfit (← operandMisfit prog op a b)
      (do
        let _ ← (if held == some false then checkA false else typeA)
        let _ ← typeB)
    let right ← rightParamOf prog op a b
    let same ← sameTest prog op a b
    let late ← copiedLate prog same a
    let s ← get
    let ta ← checkA (late || (← byRef prog op a b))
    let sa ← get
    leftTest prog op a ta same s sa
    let ka ← mark
    let tb ← match right ta with
      | some (fit, prm) => do argB fit prm; pure prm.ty
      | none => checkB (← byRef prog op b a true)
    if late && (← copiedValue prog a) then requireImplicitCopy prog ta
    checkedBinaryTy prog op a b ta tb ka (← mark) s sa same

end MojoGrimoire.Check
