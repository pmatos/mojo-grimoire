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
so that the passes report in the compiler's order (#121). What a call
types before it reads its first argument is in `typeFirst`.
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

/-- The type of a call of signature `sig`, with the arguments `args`. A
call that returns a reference, used as a value, copies the value it points
to implicitly, unless `asRef` holds. An argument through the element of an
`Int`, passed to a parameter that the origin names, is `notAList`, as
before #127: the element has no memory origin, and the model passes `k`
itself (#222). -/
def refResult (prog : Program) (asRef : Bool) (sig : Signature) (args : List Expr) :
    CheckM Ty := do
  if let some os := sig.origin then
    for (prm, a) in sig.params.zip args do
      if let .place p := a then
        if os.contains prm.name && (← intIndexed prog p) then throw (CheckError.notAList .int)
  if sig.origin.isSome && !asRef && copyingOf prog sig.result != .implicit then
    throw (CheckError.implicitCopy sig.result)
  pure sig.result

/-- Rejects the place `p` through the element of an `Int` as `notAList`,
as before #127, where the model cannot yet give the compiler's result. The
indices are checked first by `check`, as before, but for a constant out of
an `Int`'s range, which comes after. -/
def rejectIntElem (prog : Program) (p : Place) (check : CheckM Unit) : CheckM Unit := do
  unless ← intIndexed prog p do return
  tryCatch check fun e => do
    if let .constantIndexOutOfBounds (.index q _) := e then
      if (← placeTy prog q) == .int then throw (CheckError.notAList .int)
    throw e
  throw (CheckError.notAList .int)

/-- Rejects the place `p` through the element of an `Int` passed to a
`mut` or `ref` parameter (`rejectIntElem`): the compiler passes it as a
temporary, which the model does not model yet (#222). -/
def rejectIntElemArg (prog : Program) (c : Conv) (p : Place) (check : CheckM Unit) :
    CheckM Unit := do
  if c == .mutable || c == .ref then rejectIntElem prog p check

/-- Whether every index in the place `p` is an integer constant or a
variable, which evaluating twice cannot change. -/
def plainIndices : Place → Bool
  | .var _ => true
  | .field p _ | .transferred p => plainIndices p
  | .index p i => plainIndices p && ((constInt i).isSome || i matches .place (.var _))

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

/-- What the compiler types of a call of `f` before it reads its first
argument, a place: `recv` types that place, and `rest` the other
arguments. The receiver of an in-place method that inference made is
typed first, its indices included. A subscript `p[i]` of a struct, which
inference makes the call `S.__getitem__(p, i)`, has its index typed
against the getter's parameter first, as any subscript's is
(`checkIndex`), so that an unknown name or a type that does not fit in it
is reported before a use of `p` moved or uninitialized (#191); errors
that the compiler reports after the types do not count there, nor an
index with no type here, such as a literal of `Int`s of the wrong length,
which the call reports later. The state is left as it was. -/
def typeFirst (prog : Program) (f : Name) (recv : CheckM Unit) (rest : List (CheckM Ty)) :
    CheckM Unit := do
  let s0 ← get
  if inPlaceCallee f then recv
  else if let (some (_, "__getitem__", false), .ok sig) := (calleeMethod f, callSig prog f) then
    modify State.typing
    try
      for (prm, t) in sig.params.drop 1 |>.zip rest do
        let ty ← t
        unless ty == .unknown do expect prm.ty ty
    catch err => unless err.late || err matches .implicitCopy _ | .noMatchingInit .int do throw err
  set s0

end MojoGrimoire.Check
