import MojoGrimoire.Check.Fit
import MojoGrimoire.Check.Change

/-!
Reading, copying, transferring and passing a place, for the checking of
expressions (`MojoGrimoire.Check.Expr`).

A place read as a value is copied implicitly, and only an implicitly
copyable value may be. A transfer `p^` needs a value with an origin of its
own, not an element or one through a reference bound with `ref`, that is
initialized and that the function owns or holds `mut`; it leaves `p`
uninitialized. A place passed to a parameter is passed by its convention:
`read` and `ref` pass the location, which must be initialized, `mut` also
needs a place the function may change, and `var` copies it implicitly.
A misfit is reported as the call's fit says (`MojoGrimoire.Check.Fit`).
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

/-- Reads the place `p` as a value, which copies it implicitly: only an
implicitly copyable value may be. -/
def copyPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  unless copyingOf prog t == .implicit do throw (CheckError.implicitCopy t)
  pure t

/-- Whether the value in the place `p` has no origin of its own, so that
`p^` cannot transfer it out: `p` goes through an element of a list or an
array, which would be left with a hole, or is reached through a reference
bound with `ref`, mutable or not. -/
def noOwnOrigin (p : Place) : CheckM Bool := do
  pure (splitPlace.indexed p || (← lookup (splitPlace p).1).access matches .alias ..)

/-- Whether the compiler reports the error `e` in a later pass than a
transfer with no origin of its own: a use of an uninitialized or
invalidated value, and a constant index out of range (#119). -/
def CheckError.late : CheckError → Bool
  | .uninitializedUse _ | .invalidatedReference _ | .negativeIndex _
  | .constantIndexOutOfBounds _ => true
  | _ => false

/-- Runs `x`, and records an error of a later pass than typing that it
throws (`CheckError.late`) instead of throwing it. -/
def lateErrors (x : CheckM RangeArgs) : CheckM RangeArgs :=
  tryCatch x fun err => if err.late then pure (RangeArgs.ofLate err) else throw err

/-- Rejects unless the value in the place `p` may be transferred out, and
gives its type. It must have an origin of its own (`noOwnOrigin`), checked
before anything else, be initialized, and the function must own it, or
hold it `mut`: a `read` or `ref` parameter cannot give its value away. -/
def requireTransferable (prog : Program) (p : Place) : CheckM Ty := do
  let _ ← placeTy prog p
  if ← noOwnOrigin p then throw (CheckError.transferFromElement p)
  let t ← readPlace prog p
  unless (← lookup (splitPlace p).1).access.canChange do
    throw (CheckError.transferFromBorrowed p)
  pure t

/-- Transfers the value out of the place `p`, Mojo's `p^`, which leaves `p`
uninitialized and holding nothing, with no pieces. It is recorded as moved,
and a part held whole above it as touched. In Mojo, `p^` of an `Int` or a
`Bool` is the place `p`, which inference puts in its stead. -/
def transferPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← requireTransferable prog p
  let (x, path) := splitPlace p
  let v ← lookup x
  setVar { v with uninit := uninitialize v.uninit path, moved := path :: v.moved,
                  held := initPart prog v.held v.ty path,
                  touched := union (v.touched.filter fun c =>
                      (c == path && !path.isEmpty) || !path.isPrefixOf c) (above path v.held),
                  pieces := v.pieces.filter (!path.isPrefixOf ·) }
  pure t

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
