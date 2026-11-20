import MojoGrimoire.Check.Pass
import MojoGrimoire.Check.Operators

/-!
The methods that operators and calls need, and the two errors found from
the types of their operands alone (#88, #176).

Mojo's operators are methods of their operand's type: `a + b` calls
`a.__add__(b)`, `-a` calls `a.__neg__()`, and `not a`, `a and b` and
`a or b` call `__bool__` on each operand. A type that lacks the method
is the compiler's error "'T' does not implement the '__X__' method",
`missingMethod`: a `Bool` has no arithmetic and no negation, a list no
`-`, `//`, `%`, ordering or negation, an array no arithmetic, negation
or `__bool__`, a struct only the methods it declares, and `None` none.
A variable that is called is such a value too: its type lacks
`__call__`. Inside its scope a variable, or a parameter, hides a function,
`len`, `range` or a struct of the same name.

An integer literal, and an expression made only of them and of
arithmetic (`constInt`), has the type `IntLiteral`, whose operators have
several overloads: a right operand that is no `Int` fits none, and the
compiler reports only that, `noMatchingMethod`. So does an index of a
list or an array that is no `Int`, and any misfit of a list's `pop`,
whose overloads also differ. An index of an `Int` has one overload, and
its misfit stays a type mismatch.

The compiler types every operand before it looks up the method, and
reads them only in a later pass. So the checker finds these errors from
the operands' types (`operandTy`) before it reads them; the operands are
then typed, so that an error inside one comes first (`rejectAfter`).
The checker finds them again once the operands are read, from their
checked types, when their form did not give one.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The method that the binary operator `op` calls: on its left operand,
or `__bool__` on each operand of `and` and `or`. -/
def binaryMethod : BinOp → Name
  | .add => "__add__"
  | .sub => "__sub__"
  | .mul => "__mul__"
  | .floorDiv => "__floordiv__"
  | .mod => "__mod__"
  | .lt => "__lt__"
  | .le => "__le__"
  | .gt => "__gt__"
  | .ge => "__ge__"
  | .eq => "__eq__"
  | .ne => "__ne__"
  | .and | .or => "__bool__"

/-- The method that the unary operator `op` calls on its operand. -/
def unaryMethod : UnOp → Name
  | .neg => "__neg__"
  | .not => "__bool__"

/-- Whether a value of type `t` has the method `m`, of those that the
model's operators and calls need. A string literal is only printed: the
model claims nothing of its methods. -/
def hasMethod (prog : Program) (t : Ty) (m : Name) : Bool :=
  match t with
  | .int => m != "__call__"
  | .bool => ["__lt__", "__le__", "__gt__", "__ge__", "__eq__", "__ne__", "__bool__"].contains m
  | .list _ => ["__add__", "__mul__", "__eq__", "__ne__", "__bool__"].contains m
  | .array .. => ["__lt__", "__le__", "__gt__", "__ge__", "__eq__", "__ne__"].contains m
  | .struct s => (findStruct prog s).any fun sd => (findMethod sd m).isSome
  | .noneType => false
  | .str => true

/-- Whether the method `m` of a value of type `t` has several overloads,
of the methods that the model calls: a list's `pop`. -/
def overloaded (t : Ty) (m : Name) : Bool :=
  t matches .list _ && m == "pop"

/-- How an index of a place of type `base` reports a misfit: an index of
a list or an array has several overloads, and one of an `Int` one. A
`base` that is not known reports it as an ordinary call does. -/
def indexFit : Option Ty → Fit
  | some (.list _) | some (.array ..) => .overload "__getitem__"
  | _ => .call

/-- The type of the operand `e`, found from its form and from the types
of the places it names, without checking or reading it; `none` when that
does not give it, or fails. -/
def operandTy (prog : Program) (e : Expr) : CheckM (Option Ty) :=
  tryCatch (formTy e) fun _ => pure none
where
  /-- The type of `e` found from its form. -/
  formTy : Expr → CheckM (Option Ty)
    | .int _ => pure (some .int)
    | .bool _ => pure (some .bool)
    | .str _ => pure (some .str)
    | .place p | .copy p | .transfer p => do pure (some (← placeTy prog p))
    | .call f _ => do
      if (← get).vars.any (·.name == f) then pure none
      else pure ((callSig prog f).toOption.map (·.result))
    | .method p m args => do
      pure ((methodSig prog (← placeTy prog p) m args.length).toOption.map (·.result))
    | .unary op _ => pure (some (if op == .neg then .int else .bool))
    | .binary op _ _ => pure (some (binaryResult op))
    | .list .noneType (e :: es) => do pure ((← formTy e).map (.array · (es.length + 1)))
    | .list .int [_] => pure (some .int)
    | .list t@(.list _) _ | .list t@(.array ..) _ => pure (some t)
    | .listInit u _ => pure (some (.list u))
    | .withDrops e _ _ => formTy e
    | _ => pure none

/-- The error of the operator `op` that the types `ta` and `tb` of its
operands give, when they are known: the method that the left operand's
type lacks, or, for `and` and `or`, `__bool__` that the right one's
lacks. -/
def binaryMisfit (prog : Program) (op : BinOp) (ta tb : Option Ty) : Option CheckError :=
  let lacks : Option Ty → Option CheckError
    | some t => if hasMethod prog t (binaryMethod op) then none
      else some (.missingMethod t (binaryMethod op))
    | none => none
  lacks ta <|> if op == .and || op == .or then lacks tb else none

/-- The error of the operator `op` that the type `ta` of its operand
gives, when it is known: the method that the type lacks. -/
def unaryMisfit (prog : Program) (op : UnOp) : Option Ty → Option CheckError
  | some t => if hasMethod prog t (unaryMethod op) then none else some (.missingMethod t (unaryMethod op))
  | none => none

/-- Checks the call of the method `m`, of signature `sig`, on the place `p`
of type `t`, whose indices are checked, with the arguments `args`, which
`check` checks against `sig`'s parameters as a call of the fit it is
given does: a method with several overloads reports every misfit as
`noMatchingMethod`. The receiver is passed by its convention, but when
it is `q^` and `self` is `var`: then `q` is consumed once the arguments
are read. -/
def methodCall (prog : Program) (asRef : Bool) (p : Place) (t : Ty) (m : Name) (args : List Expr)
    (sig : Signature) (check : Fit → CheckM (List (List Place × Nat))) : CheckM Ty := do
  let some self := sig.self | throw (CheckError.invalidSelf m)
  let consumed := consumedReceiver self.conv p
  let recv ← match consumed with
    | some q => do pure [← passedPlace .mutable q]
    | none => if self.conv == .owned then pure [] else do pure [← passedPlace self.conv p]
  checkExclusive (recv ++ (← locationArgs prog sig.params args))
  if consumed.isNone then passPlace prog .call m self.conv t p
  let k ← mark
  let ks ← check (if overloaded t m then .overload m else .call)
  recheckLocs prog (([p], k) :: ks)
  if let some q := consumed then let _ ← transferPlace prog q
  for q in ← changedArgs prog sig.allParams (.place p :: args) do changePlace prog q
  refResult prog asRef sig

/-- The type of the result of the operator `op` on operands of types `ta`
and `tb`: a method that a type lacks first, then `binaryTy`. -/
def methodBinaryTy (prog : Program) (op : BinOp) (ta tb : Ty) : Except CheckError Ty :=
  match binaryMisfit prog op (some ta) (some tb) with
  | some err => throw err
  | none => binaryTy op ta tb

/-- The type of the result of the operator `op` on an operand of type `ta`:
a method that the type lacks first, then `unaryTy`. -/
def methodUnaryTy (prog : Program) (op : UnOp) (ta : Ty) : Except CheckError Ty :=
  match unaryMisfit prog op (some ta) with
  | some err => throw err
  | none => unaryTy op ta

/-- Rejects with `err`, found from the types of operands, once `typing`
has typed them in `State.typing`: an error inside an operand, which the
compiler finds as it types it, comes first. -/
def rejectAfter {α : Type} (typing : CheckM Unit) (err : CheckError) : CheckM α := do
  modify State.typing
  typing
  throw err

/-- Rejects with the error `misfit`, when there is one, as `rejectAfter`
does. -/
def rejectMisfit (misfit : Option CheckError) (typing : CheckM Unit) : CheckM Unit :=
  match misfit with
  | some err => rejectAfter typing err
  | none => pure ()

/-- Rejects a call of `f` when a variable in scope of that name hides the
function, `len`, `range` or the struct `f`, and its type has no
`__call__`, once `typing` has typed the call's arguments: the compiler
types them first (#176). -/
def rejectCalledVar (prog : Program) (f : Name) (typing : CheckM Unit) : CheckM Unit := do
  if let some v := (← get).vars.find? (·.name == f) then
    unless hasMethod prog v.ty "__call__" do rejectAfter typing (.missingMethod v.ty "__call__")

end MojoGrimoire.Check
