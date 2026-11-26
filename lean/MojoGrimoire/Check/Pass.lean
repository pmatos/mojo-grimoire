import MojoGrimoire.Check.Fit
import MojoGrimoire.Check.Transfer

/-!
Helpers for the checking of expressions (`MojoGrimoire.Check.Expr`):
lifting the program's tables into the checker, comparing types, the
result of a call that returns a reference, and passing a place to a parameter, which reads it by its convention: `read`
and `ref` pass the location, which must be initialized, `mut` also needs a
place the function may change, and `var` copies it implicitly
(`MojoGrimoire.Check.Transfer`). A misfit is reported as the call's fit
says (`MojoGrimoire.Check.Fit`). Each error has its phase
(`CheckError.phase`). An error of the instantiation phase, in an argument
of `range`, may be recorded instead of thrown (`lateErrors`), so that the
errors report in the compiler's order of passes (#121). What a call types before it reads its first argument is in
`typeFirst`. A module outside the mutual block of the checker of
expressions is given the checks of the expressions inside the ones it
checks as `Below` says.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Lifts a result of the program's tables into the checker. -/
def lift {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- A check of each value of type `β` no larger than the expressions `r`,
giving an `α`. A module outside the mutual block of
`MojoGrimoire.Check.Expr` is given so the checks of the expressions and
places inside the expressions `r` that it checks, so that the recursion
still ends (#96). -/
abbrev Below (β α : Type) [SizeOf β] (r : List Expr) : Type :=
  (x : β) → sizeOf x ≤ sizeOf r → CheckM α

/-- Proves that a part of a value whose size the hypothesis `h` bounds,
such as an element of a list or the elements of a literal in it, is no
larger than that bound, for a check of `Below`. -/
macro "below_bound " h:ident : tactic => `(tactic| (subst_vars; simp at $h:ident ⊢; omega))

/-- Rejects unless the type `actual` is the type `expected`. -/
def expect (expected actual : Ty) : CheckM Unit :=
  unless expected == actual do throw (CheckError.typeMismatch expected actual)

/-- Rejects unless the place `p` may be changed: not through `q^`. It
reports the error that `fit` gives when `p` is an argument. -/
def requireMutable (p : Place) (fit : Fit := .call) : CheckM Unit := do
  let v ← lookup (splitPlace p).1
  unless v.access.canChange && !throughTransfer p do
    throw (fit.misfit (CheckError.immutablePlace p))

/-- The position of the phase `ph` in the order of phases. -/
def Phase.rank : Phase → Nat
  | .type => 0
  | .flow => 1
  | .inst => 2

/-- The phase that reports the error `e`: a constant index's is
instantiation's, a use of an uninitialized or invalidated value the flow
phase's, and any other the type phase's, but where the call site's phase
says otherwise, as for a literal of `Int`s of the wrong length
(`instThrow`). -/
def CheckError.phase : CheckError → Phase
  | .negativeIndex _ | .constantIndexOutOfBounds _ => .inst
  | .uninitializedUse _ | .invalidatedReference _ => .flow
  | _ => .type

/-- Runs `x`, and records an error of the instantiation phase that it
throws (`CheckError.phase`), or a nested literal's failed SIMD constraint,
`noMatchingInit` of `Int`, instead of throwing it. -/
def lateErrors (x : CheckM RangeArgs) : CheckM RangeArgs :=
  tryCatch x fun err =>
    if err.phase == .inst then pure { index := some err }
    else if err == .noMatchingInit .int then pure { literal := true }
    else throw err

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
  if sig.origin.isSome && !asRef then requireImplicitCopy prog sig.result
  pure sig.result

/-- Checks the value `e`, given `check`, which checks it as a value
(`false`) or by reference, uncopied (`true`), and then that its type is
`t`, else the misfit that `fit` reports (`expectArg`). The compiler reports the implicit copy of the value that
a call returns a reference to (`refResult`) only once the type fits, so
when the check of a call or a method call as a value reports that copy,
`e` is checked again from the same state by reference, and a type that
does not fit comes first. Any other value's copy, such as of a place or
of a literal's element, comes after its misfit too (`copyLast`, #96
part 11). -/
def misfitFirst (e : Expr) (fit : Fit) (t : Ty) (check : Bool → CheckM Ty) :
    CheckM Unit :=
  copyLast do
    expectArg fit t (← tryCatch (check false) fun err => do
      if err matches .implicitCopy _ && e matches .call .. | .method .. then
        expectArg fit t (← tryCatch (check true) fun _ => throw err)
      throw err)

/-- Rejects the place `p` through the element of an `Int` as `notAList`,
as before #127, where the model cannot yet give the compiler's result. The
indices are checked first by `check`, with every check on (`allChecks`),
as before, but for a constant out of an `Int`'s range, which comes after.
An index's error of a later phase (`CheckError.phase`) is left to the
phase that reports it, unless an outer check has every check on. -/
def rejectIntElem (prog : Program) (p : Place) (check : CheckM Unit) : CheckM Unit := do
  unless ← intIndexed prog p do return
  let s0 ← get
  let later ← tryCatch (do modify ({ · with allChecks := true }); check; pure false) fun e => do
    if let .constantIndexOutOfBounds (.index q _) := e then
      if (← placeTy prog q) == .int then throw (CheckError.notAList .int)
    if !s0.allChecks && s0.phase.rank < e.phase.rank then pure true else throw e
  modify ({ · with allChecks := s0.allChecks })
  unless later do throw (CheckError.notAList .int)

/-- The body that a call of `f` instantiates, if it has one: the function
`f`, the `__init__` that the struct `f` declares, or the method that
`f` names (`methodCallee`). -/
def calleeBody (prog : Program) (f : Name) : Option Name :=
  if (findFun prog f).isSome then some f
  else if let some sd := findStruct prog f then sd.init.map fun _ => methodCallee f "__init__"
  else (calleeMethod f).map fun (s, m, _) => methodCallee s m

/-- Records the call of the body `f` instantiates (`calleeBody`), in the
instantiation phase. -/
def instCall (prog : Program) (f : Name) : CheckM Unit := do
  unless (← get).phase == .inst do return
  if let some b := calleeBody prog f then instRecord (.call b)

/-- The destructor that destroying a value of type `t` calls: the
`__deinit__` that its struct declares, or else the one that the compiler
synthesizes, `__del__`, which destroys its fields; for a list or an array,
its elements'. -/
def destructorOf (prog : Program) : Ty → Option Name
  | .struct s => some (methodCallee s
      (if ((findStruct prog s).bind (·.deinit)).isSome then "__deinit__" else "__del__"))
  | .list u | .array u _ => destructorOf prog u
  | _ => none

/-- Records the call of the destructor that destroying the value in `p`
makes (`destructorOf`), in the instantiation phase. -/
def dropCall (prog : Program) (p : Place) : CheckM Unit := do
  unless (← get).phase == .inst do return
  if let some d := destructorOf prog (← placeTy prog p) then instRecord (.call d)

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
is reported before a use of `p` moved or uninitialized (#191), and so is
an implicit copy in the index, or of a place it passes to a `var`
parameter, which the compiler reports after the types; errors of a later
pass do not count there, nor an index with no type here, such as a
literal of `Int`s of the wrong length, which the call reports later. The
state is left as it was. -/
def typeFirst (prog : Program) (f : Name) (recv : CheckM Unit) (rest : List (Expr × CheckM Ty)) :
    CheckM Unit := do
  let s0 ← get
  if inPlaceCallee f then inTypePhase recv
  else if let (some (_, "__getitem__", false), .ok sig) := (calleeMethod f, callSig prog f) then
    try inTypePhase do
      for (prm, a, t) in sig.params.drop 1 |>.zip rest do
        let ty ← t
        unless ty == .unknown do
          expect prm.ty ty
          if prm.conv == .owned && a matches .place _ && copyingOf prog ty != .implicit then
            throw (CheckError.implicitCopy ty)
    catch err => unless err matches .noMatchingInit .int do throw err
  set s0

end MojoGrimoire.Check
