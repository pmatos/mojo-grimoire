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
The methods that a trait such as `Equatable` supplies are not yet
modelled (#194). A variable that is called is such a value too: its type
lacks `__call__`. Inside its scope a variable, or a parameter, hides a
function, `len`, `range`, `print` or a struct of the same name in a call,
but not yet in a type position (#193). An operator, a subscript or a
call whose operand is a struct that declares the method is a call of the
method, which inference makes (`MojoGrimoire.Parse.Dispatch`, #191): it
reaches the checker as any other call, a method that a struct lacks only
for `p += e`. Such a call of `__iadd__` needs a receiver that may change
(`requireInPlace`), and a subscript of a struct with a getter and no
setter may not be assigned (`valueSubscript`).

An integer literal, and an expression made only of them and of
arithmetic (`intLiteral`), has the type `IntLiteral`, whose operators have
several overloads: a right operand that is no `Int` fits none, and the
compiler reports only that, `noMatchingMethod`. So does an index of a
list or an array that is no `Int`, and any misfit of a list's `pop`,
whose overloads also differ. An index of an `Int` has one overload, and
its misfit stays a type mismatch.

The compiler types every operand before it looks up the method, and
reads them only in a later pass. So the checker finds a missing method
from the operands' types (`operandTy`) before it reads them; the operands
are then typed, so that an error inside one comes first (`rejectAfter`).
It finds it again once the operands are read, from their checked types,
when their form did not give one. A misfit of an overload set is found as
an ordinary call finds its misfit, once its argument is read, so an
uninitialized argument of the wrong type is still `uninitializedUse`
first, where the compiler reports `noMatchingMethod`: that order across
the compiler's passes is left to #96.
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
model's operators and calls need. A struct has those it declares; the
defaults of its traits are not yet modelled (#194). A string literal is
only printed: the model claims nothing of its methods. -/
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
of the methods that the model calls: a list's `pop`, and `__getitem__`
of a list or an array, which an index calls. -/
def overloaded (t : Ty) (m : Name) : Bool :=
  t matches .list _ && m == "pop" || t matches .list _ | .array .. && m == "__getitem__"

/-- Whether the expression `e` is an integer literal, or is made only of
them, negation and arithmetic (`constInt`): its type is `IntLiteral`,
whose operators have several overloads. -/
def intLiteral : Expr → Bool
  | .int _ => true
  | .unary .neg a => intLiteral a
  | .binary op a b => op.arith.isSome && intLiteral a && intLiteral b
  | _ => false

/-- The type of the operand `e`, found from its form and from the types
of the places it names, without checking or reading it; `none` when that
does not give it, or fails. A call of the built-in `len`, which nothing
hides, gives an `Int`. A literal with no type expected has one only when
every element's form gives the same type: one whose elements differ, or
whose element's type its form does not give, is left to checking, which
reports their mismatch first. -/
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
      if (← findVar f).isSome then pure none
      else pure (match callSig prog f with
        | .ok sig => some sig.result
        | .error _ => if f == "len" then some .int else none)
    | .method p m args => do
      pure ((methodSig prog (← placeTy prog p) m args.length).toOption.map (·.result))
    | .unary op _ => pure (some (if op == .neg then .int else .bool))
    | .binary op a b => do
      if op == .and || op == .or then
        let tb ← formTy b
        if !(tb matches some (.struct _)) then return some .bool
        pure (if (← formTy a) == tb then tb else some .bool)
      else pure (some (binaryResult op))
    | .list .noneType (e :: es) => do
      let u ← formTy e
      pure (if ← sameTy u es then u.map (.array · (es.length + 1)) else none)
    | .list .int [_] => pure (some .int)
    | .list t@(.list _) _ | .list t@(.array ..) _ => pure (some t)
    | .listInit u _ => pure (some (.list u))
    | .withDrops e _ _ => formTy e
    | _ => pure none
  /-- Whether the form of each of `es` gives the type `u`. -/
  sameTy (u : Option Ty) : List Expr → CheckM Bool
    | [] => pure true
    | e :: es => do pure ((← formTy e) == u && (← sameTy u es))

/-- `missingMethod` of the type `t` and the method `m`, when `t` is known
and lacks `m`. -/
def lacks (prog : Program) (m : Name) : Option Ty → Option CheckError
  | some t => if hasMethod prog t m then none else some (.missingMethod t m)
  | none => none

/-- The error of the operator `op` that the types `ta` and `tb` of its
operands give, when they are known: the method that the left operand's
type lacks, or, for `and` and `or`, `__bool__` that the right one's
lacks. -/
def binaryMisfit (prog : Program) (op : BinOp) (ta tb : Option Ty) : Option CheckError :=
  lacks prog (binaryMethod op) ta <|>
    if op == .and || op == .or then lacks prog (binaryMethod op) tb else none

/-- The error of the operator `op` that the type `ta` of its operand
gives, when it is known: the method that the type lacks. -/
def unaryMisfit (prog : Program) (op : UnOp) (ta : Option Ty) : Option CheckError :=
  lacks prog (unaryMethod op) ta

/-- Rejects with `err`, found from the types of operands, once `typing`
has typed them in `State.typing`: an error inside an operand, which the
compiler finds as it types it, comes first. -/
def rejectAfter {α : Type} (typing : CheckM Unit) (err : CheckError) : CheckM α := do
  modify State.typing
  typing
  throw err

/-- Checks the call of the method `m`, of signature `sig`, on the place `p`
of type `t`, whose indices are checked, with the arguments `args`, which
`check` checks against `sig`'s parameters as a call of the fit it is
given does: a method with several overloads reports every misfit as
`noMatchingMethod`, of its receiver too, such as a list that may not
change for `pop`. When such a method's receiver cannot be passed, its
arguments are typed first, by `typing`, so that an error inside one comes
before the receiver's misfit, as the compiler types them before it looks
for an overload that fits (`rejectAfter`). A method with one overload
passes its receiver first (#89). The receiver is passed by its convention, but when
it is `q^` and `self` is `var`: then `q` is consumed once the arguments
are read. -/
def methodCall (prog : Program) (asRef : Bool) (p : Place) (t : Ty) (m : Name) (args : List Expr)
    (sig : Signature) (typing : CheckM Unit) (check : Fit → CheckM (List (List Place × Nat))) :
    CheckM Ty := do
  let some self := sig.self | throw (CheckError.invalidSelf m)
  let fit := if overloaded t m then Fit.overload m else .call
  let consumed := consumedReceiver self.conv p
  let recv ← match consumed with
    | some q => do pure [← passedPlace .mutable q]
    | none => if self.conv == .owned then pure [] else do pure [← passedPlace self.conv p]
  checkExclusive (recv ++ (← locationArgs prog sig.params args))
  if consumed.isNone then
    let pass := passPlace prog fit m self.conv t p
    if fit matches .overload _ then tryCatch pass (rejectAfter typing) else pass
  let k ← mark
  let ks ← check fit
  recheckLocs prog (([p], k) :: ks)
  if let some q := consumed then let _ ← transferPlace prog q
  for q in ← changedArgs prog sig.allParams (.place p :: args) do changePlace prog q
  refResult prog asRef sig

/-- The type of the result of the operator `op` on operands of types `ta`
and `tb`: a method that a type lacks first, then `binaryTy`. `and` and
`or` on operands of the same struct type, which has `__bool__`, give the
operand that decides, of that type (#191). -/
def methodBinaryTy (prog : Program) (op : BinOp) (ta tb : Ty) : Except CheckError Ty :=
  match binaryMisfit prog op (some ta) (some tb) with
  | some err => throw err
  | none =>
    if (op == .and || op == .or) && ta == tb && ta matches .struct _ then pure ta
    else binaryTy op ta tb

/-- The type of the result of the operator `op` on an operand of type `ta`:
a method that the type lacks first, then `unaryTy`. -/
def methodUnaryTy (prog : Program) (op : UnOp) (ta : Ty) : Except CheckError Ty :=
  match unaryMisfit prog op (some ta) with
  | some err => throw err
  | none => unaryTy op ta

/-- Rejects with the error `misfit`, when there is one, as `rejectAfter`
does. -/
def rejectMisfit (misfit : Option CheckError) (typing : CheckM Unit) : CheckM Unit :=
  match misfit with
  | some err => rejectAfter typing err
  | none => pure ()

/-- Rejects the call of the in-place method `f` of a struct, `p += e`
(`MojoGrimoire.Core.inPlaceCallee`), whose receiver `p` may not change,
once its indices are checked, before the method is looked up or its
arguments checked: the compiler requires a destination that may change
then, whatever the convention of the method's `self` (#191). -/
def requireInPlace (f : Name) (args : List Expr) : CheckM Unit := do
  if let (true, .place p :: _) := (inPlaceCallee f, args) then requireMutable p

/-- Rejects the subscript read late `a` on the left of `and` or `or` when
its getter takes a `var` struct that its argument, a temporary or a
transfer, gives: the compiler calls the getter twice, the second time with
what the first consumed, and reports that use (#191). -/
def rejectReadTwice (prog : Program) (op : BinOp) (a : Expr) : CheckM Unit := do
  let .call g args := a | pure ()
  unless (op == .and || op == .or) && lateGetter prog g do return
  let .ok sig := callSig prog g | pure ()
  for (prm, arg) in sig.params.zip args do
    if prm.conv == .owned && prm.ty matches .struct _ && !(arg matches .place _) then
      throw (CheckError.uninitializedUse (match arg with
        | .transfer p => p
        | _ => .var "(expression temporary)"))

/-- The call of the getter that the subscript `p` reads, when `p` is one of
a struct that declares `__getitem__` but not `__setitem__`. The subscript
is the value that the getter gives, which may not change: the compiler
rejects an assignment to it once it has checked the call, before the
value assigned (#191). -/
def valueSubscript (prog : Program) (p : Place) : CheckM (Option Expr) := do
  if let .index q i := p then
    if let .struct s ← placeTy prog q then
      if (findStruct prog s).any fun sd =>
          (findMethod sd "__getitem__").isSome && (findMethod sd "__setitem__").isNone then
        return some (.call (methodCallee s "__getitem__") [.place q, i])
  pure none

/-- Rejects a call of `f` when a variable in scope of that name hides the
function, `len`, `range`, `print` or the struct `f`, and its type has no
`__call__`, once `typing` has typed the call's arguments: the compiler
types them first (#176). A variable whose struct type declares `__call__`
never reaches it: inference makes the call one of the method (#191). -/
def rejectCalledVar (prog : Program) (f : Name) (typing : CheckM Unit) : CheckM Unit := do
  rejectMisfit (lacks prog "__call__" ((← findVar f).map (·.ty))) typing

end MojoGrimoire.Check
