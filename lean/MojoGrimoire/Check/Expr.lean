import MojoGrimoire.Check.State

/-!
The checking of expressions and of the arguments of calls.

An expression is checked from left to right, as Mojo evaluates it, and the
state follows: a transfer `p^` leaves `p` uninitialized for what comes after
it. Mojo reads a place operand only once every operand of its operation is
evaluated, so each place operand must still be initialized then. A place passed as an argument is passed by its parameter's convention:
`read`, `mut` and `ref` pass the location, which must be initialized, and
`mut` also needs a place the function may change; `var` passes a value, which
is copied implicitly unless the argument transfers it.

A `mut` argument may not alias another argument that is passed as a location,
Mojo's argument exclusivity. An `Int` or a `Bool` passed to a `read`
parameter is not passed as a location: Mojo copies it. A `mut` argument of
any type is.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Lifts a result of the program's tables into the checker. -/
def lift {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- Rejects unless the type `actual` is the type `expected`. -/
def expect (expected actual : Ty) : CheckM Unit :=
  unless expected == actual do throw (CheckError.typeMismatch expected actual)

/-- Whether a variable held this way may be changed: assigned to, or passed
`mut`. -/
def Access.canChange : Access → Bool
  | .readOnly => false
  | .alias _ m => m
  | _ => true

/-- Rejects unless the place `p` may be changed. -/
def requireMutable (p : Place) : CheckM Unit := do
  let v ← lookup (splitPlace p).1
  unless v.access.canChange do throw (CheckError.immutablePlace p)

/-- Reads the place `p` as a value, which copies it implicitly: only an
implicitly copyable value may be. -/
def copyPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  unless copyingOf prog t == .implicit do throw (CheckError.implicitCopy t)
  pure t

/-- Transfers the value out of the place `p`, Mojo's `p^`, which leaves `p`
uninitialized. The function must own the value, or hold it `mut`: a `read`
or `ref` parameter cannot give its value away. An element of a list or an
array cannot be transferred out, since it would be left with a hole. -/
def transferPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  if splitPlace.indexed p then throw (CheckError.transferFromElement p)
  let (x, path) := splitPlace p
  let v ← lookup x
  unless v.access.canChange do throw (CheckError.transferFromBorrowed p)
  if let .alias _ _ := v.access then throw (CheckError.transferFromBorrowed p)
  setUninit x (uninitialize v.uninit path)
  pure t

/-- The type of the result of the operator `op` on operands of types `a` and
`b`. -/
def binaryTy (op : BinOp) (a b : Ty) : Except CheckError Ty :=
  match op with
  | .add | .sub | .mul | .floorDiv | .mod => do
    unless a == .int do throw (.typeMismatch .int a)
    unless b == .int do throw (.typeMismatch .int b)
    pure .int
  | .lt | .le | .gt | .ge => do
    unless a == .int do throw (.typeMismatch .int a)
    unless b == .int do throw (.typeMismatch .int b)
    pure .bool
  | .eq | .ne => do
    unless a == .int || a == .bool do throw (.typeMismatch .int a)
    unless b == a do throw (.typeMismatch a b)
    pure .bool
  | .and | .or => do
    unless a == .bool do throw (.typeMismatch .bool a)
    unless b == .bool do throw (.typeMismatch .bool b)
    pure .bool

/-- The type of the result of the operator `op` on an operand of type `a`. -/
def unaryTy (op : UnOp) (a : Ty) : Except CheckError Ty :=
  match op with
  | .neg => if a == .int then pure .int else throw (.typeMismatch .int a)
  | .not => if a == .bool then pure .bool else throw (.typeMismatch .bool a)

/-- The value of an index made only of integer literals, negation, `+`, `-`,
`*`, `//` and `%`: Mojo computes it when it compiles the program, with
`BinOp.arith`, as the interpreter does at run time. -/
def constInt : Expr → Option Int
  | .int k => some k
  | .unary .neg a => (constInt a).map (- ·)
  | .binary op a b => do
    let f ← op.arith
    pure (f (← constInt a) (← constInt b))
  | _ => none

/-- Whether two places may be the same location or overlap: one is the other
or a field of it. -/
def overlaps (p q : Place) : Bool :=
  let (x, a) := splitPlace p
  let (y, b) := splitPlace q
  x == y && (a.isPrefixOf b || b.isPrefixOf a)

/-- The places among `args` that are passed as locations, with their
conventions: every place argument whose parameter is `read`, `mut` or
`ref`, except an `Int` or a `Bool` passed `read`, which is copied. -/
def locationArgs : List Param → List Expr → List (Conv × Place)
  | prm :: prms, .place p :: args =>
    if prm.conv == .owned || (prm.conv == .read && (prm.ty == .int || prm.ty == .bool)) then
      locationArgs prms args
    else (prm.conv, p) :: locationArgs prms args
  | _ :: prms, _ :: args => locationArgs prms args
  | _, _ => []

/-- Rejects a `mut` location among `locs` that overlaps another one. A
reference counts as every place it may point into. -/
def checkExclusive (locs : List (Conv × Place)) : CheckM Unit := do
  go (← get).vars locs []
where
  /-- Checks each location against those before and after it. -/
  go (vars : List VarState) : List (Conv × Place) → List (Conv × Place) → CheckM Unit
    | [], _ => pure ()
    | (c, p) :: rest, seen => do
      let others := seen ++ rest
      let clash (q : Place) :=
        (resolvePlace vars p).any fun a => (resolvePlace vars q).any (overlaps a)
      if c == .mutable && others.any (clash ·.2) then
        throw (CheckError.argumentExclusivity p)
      go vars rest ((c, p) :: seen)

/-- Passes the place `p` to a parameter of convention `c` and type `t`. -/
def passPlace (prog : Program) (callee : Name) (c : Conv) (t : Ty) (p : Place) :
    CheckM Unit := do
  match c with
  | .read | .ref => expect t (← readPlace prog p)
  | .mutable => do
    expect t (← readPlace prog p)
    requireMutable p
  | .owned => expect t (← copyPlace prog p)
  | .out | .deinit => throw (CheckError.invalidConvention callee)

/-- Rejects a place among the operands `es` that a later operand left
uninitialized: Mojo reads a place operand only once every operand of its
operation is evaluated, and a reference argument is used during the call. -/
def recheckPlaces (prog : Program) (es : List Expr) : CheckM Unit :=
  es.forM fun
    | .place p => do let _ ← readPlace prog p
    | _ => pure ()

/-- The type of a call of `fd`. A call that returns a reference, used as a
value, copies the value it points to implicitly, unless `asRef` holds. -/
def refResult (prog : Program) (asRef : Bool) (fd : FunDecl) : CheckM Ty := do
  if fd.origin.isSome && !asRef && copyingOf prog fd.result != .implicit then
    throw (CheckError.implicitCopy fd.result)
  pure fd.result

mutual
/-- The type of the expression `e`. A string literal has no type here: it may
only be printed, which `checkPrint` checks. A call that returns a reference
gives the value it points to, which is copied implicitly, unless `asRef`
holds: then the reference itself is bound, by `ref`. -/
def checkExprAs (prog : Program) (asRef : Bool) : Expr → CheckM Ty
  | .int _ => pure .int
  | .bool _ => pure .bool
  | .str _ => throw CheckError.stringOutsidePrint
  | .place p => do checkIndices prog p; copyPlace prog p
  | .transfer p => do checkIndices prog p; transferPlace prog p
  | .copy p => do
    checkIndices prog p
    let t ← readPlace prog p
    if copyingOf prog t == .none then throw (CheckError.notCopyable t)
    pure t
  | .call f args => do
    match findStruct prog f, findFun prog f with
    | some sd, _ =>
      let params ← match sd.init with
        | some fd => pure fd.params.tail
        | none =>
          if sd.fieldwiseInit then pure (sd.fields.map fun (x, t) => ⟨.owned, x, t⟩)
          else throw (CheckError.noInitializer f)
      checkExclusive (locationArgs params args)
      checkArgs prog f params args params.length args.length
      recheckPlaces prog args
      pure (.struct f)
    | none, some fd => do
      checkExclusive (locationArgs fd.params args)
      checkArgs prog f fd.params args fd.params.length args.length
      recheckPlaces prog args
      refResult prog asRef fd
    | none, none =>
      match f, args with
      | "len", [.place p] => do
        checkIndices prog p
        let t ← readPlace prog p
        let _ ← lift (elemOf t)
        pure .int
      | "len", [e] => do
        let t ← checkExprAs prog false e
        let _ ← lift (elemOf t)
        pure .int
      | "len", _ => throw (CheckError.arityMismatch f 1 args.length)
      | _, _ => throw (CheckError.unknownFunction f)
  | .method p m args => do
    checkIndices prog p
    let t ← placeTy prog p
    if let .array .. := t then throw (CheckError.unknownMethod "Array" m)
    if let .list et := t then
      unless m == "append" do throw (CheckError.unknownMethod "List" m)
      let _ ← readPlace prog p
      requireMutable p
      checkArgs prog m [⟨.owned, "value", et⟩] args 1 args.length
      recheckPlaces prog (.place p :: args)
      return .noneType
    let .struct s := t | throw (CheckError.typeMismatch (.struct "") t)
    let some sd := findStruct prog s | throw (CheckError.unknownStruct s)
    let some fd := findMethod sd m | throw (CheckError.unknownMethod s m)
    let some self := fd.params.head? | throw (CheckError.invalidSelf m)
    checkExclusive ((if self.conv == .owned then [] else [(self.conv, p)]) ++
      locationArgs fd.params.tail args)
    passPlace prog m self.conv t p
    let params := fd.params.tail
    checkArgs prog m params args params.length args.length
    recheckPlaces prog (.place p :: args)
    refResult prog asRef fd
  | .unary op a => do lift (unaryTy op (← checkExprAs prog false a))
  | .binary op a b => do
    let ta ← checkExprAs prog false a
    let tb ← checkExprAs prog false b
    unless op == .and || op == .or do recheckPlaces prog [a, b]
    lift (binaryTy op ta tb)
  | .list t es => do
    let .ok u := elemOf t | throw (CheckError.invalidType t)
    unless validTy prog u do throw (CheckError.invalidType t)
    if let .array _ n := t then
      unless n == es.length do throw (CheckError.typeMismatch t (.array u es.length))
    checkArgs prog "List" (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length
    recheckPlaces prog es
    pure t
  | .withDrops e _ _ => checkExprAs prog asRef e

/-- Checks the index expressions of the place `p`: each is an `Int`, and
one that Mojo computes when it compiles the program may not be negative,
nor, into an array, beyond its last element. -/
def checkIndices (prog : Program) : Place → CheckM Unit
  | .var _ => pure ()
  | .field p _ => checkIndices prog p
  | .index p i => do
    checkIndices prog p
    expect .int (← checkExprAs prog false i)
    if let some k := constInt i then
      if k < 0 then throw (CheckError.negativeIndex (.index p i))
      if let .array _ n := (← placeTy prog p) then
        if n ≤ k then throw (CheckError.constantIndexOutOfBounds (.index p i))

/-- Checks the arguments `args` of a call of `callee` against its parameters
`params`, in order. `n` and `m` are the numbers of parameters and arguments,
for the error when they differ. -/
def checkArgs (prog : Program) (callee : Name) :
    List Param → List Expr → Nat → Nat → CheckM Unit
  | [], [], _, _ => pure ()
  | prm :: prms, .place p :: args, n, m => do
    checkIndices prog p
    passPlace prog callee prm.conv prm.ty p
    checkArgs prog callee prms args n m
  | prm :: prms, e :: args, n, m => do
    if prm.conv == .mutable then throw (CheckError.notAPlace callee)
    if prm.conv == .out || prm.conv == .deinit then
      throw (CheckError.invalidConvention callee)
    expect prm.ty (← checkExprAs prog false e)
    checkArgs prog callee prms args n m
  | _, _, n, m => throw (CheckError.arityMismatch callee n m)
end

/-- The type of the expression `e`, used as a value. -/
def checkExpr (prog : Program) (e : Expr) : CheckM Ty := checkExprAs prog false e

end MojoGrimoire.Check
