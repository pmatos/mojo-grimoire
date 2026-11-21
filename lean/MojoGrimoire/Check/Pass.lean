import MojoGrimoire.Check.Fit
import MojoGrimoire.Check.Transfer

/-!
Helpers for the checking of expressions (`MojoGrimoire.Check.Expr`):
lifting the program's tables into the checker, comparing types, the
result of a call that returns a reference, and passing a place to a parameter, which reads it by its convention: `read`
and `ref` pass the location, which must be initialized, `mut` also needs a
place the function may change, and `var` copies it implicitly
(`MojoGrimoire.Check.Transfer`). A misfit is reported as the call's fit
says (`MojoGrimoire.Check.Fit`). An error of a later pass than typing, in
an argument of `range`, may be recorded instead of thrown (`lateErrors`),
so that the passes report in the compiler's order (#121).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Lifts a result of the program's tables into the checker. -/
def lift {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- Rejects unless the type `actual` is the type `expected`. -/
def expect (expected actual : Ty) : CheckM Unit :=
  unless expected == actual do throw (CheckError.typeMismatch expected actual)

/-- Rejects unless the place `p` may be changed: not through `q^`. It
reports the error that `fit` gives when `p` is an argument. -/
def requireMutable (p : Place) (fit : Fit := .call) : CheckM Unit := do
  let v ← lookup (splitPlace p).1
  unless v.access.canChange && !throughTransfer p do
    throw (fit.misfit (CheckError.immutablePlace p))

/-- Runs `x`, and records an error of a later pass than typing that it
throws (`CheckError.late`), or a nested literal's failed SIMD constraint,
`noMatchingInit` of `Int`, instead of throwing it. -/
def lateErrors (x : CheckM RangeArgs) : CheckM RangeArgs :=
  tryCatch x fun err =>
    if err.late || err == .noMatchingInit .int then pure (RangeArgs.ofLate err) else throw err

/-- The type of a call of signature `sig`. A call that returns a reference,
used as a value, copies the value it points to implicitly, unless `asRef`
holds. -/
def refResult (prog : Program) (asRef : Bool) (sig : Signature) : CheckM Ty := do
  if sig.origin.isSome && !asRef && copyingOf prog sig.result != .implicit then
    throw (CheckError.implicitCopy sig.result)
  pure sig.result

/-- Rejects the place `p` through the element of an `Int`, passed to a
`mut` or `ref` parameter, as `notAList`, as before #127: the compiler
passes it as a temporary, which the model does not model yet (#222). The
indices are checked first by `check`, as before, but for a constant out of
an `Int`'s range, which comes after. -/
def rejectIntElemArg (prog : Program) (c : Conv) (p : Place) (check : CheckM Unit) :
    CheckM Unit := do
  unless (c == .mutable || c == .ref) && (← intIndexed prog p) do return
  tryCatch check fun e => do
    if let .constantIndexOutOfBounds (.index q _) := e then
      if (← placeTy prog q) == .int then throw (CheckError.notAList .int)
    throw e
  throw (CheckError.notAList .int)

/-- Passes the place `p` to a parameter of convention `c` and type `t`, of
a call of fit `fit`. -/
def passPlace (prog : Program) (fit : Fit) (callee : Name) (c : Conv) (t : Ty) (p : Place) :
    CheckM Unit := do
  match c with
  | .read | .ref => expectArg fit t (← readPlace prog p)
  | .mutable => do
    expectArg fit t (← readPlace prog p)
    requireMutable p fit
  | .owned => expectArg fit t (← copyPlace prog p)
  | .out | .deinit => throw (CheckError.invalidConvention callee)

end MojoGrimoire.Check
