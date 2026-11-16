import MojoGrimoire.Check.Loc

/-!
The checking of expressions and of the arguments of calls.

An expression is checked from left to right, as Mojo evaluates it, and the
state follows: a transfer `p^` leaves `p` uninitialized for what comes after
it. Before a field or a method, `p^` borrows `p`, which must be whole and
could be transferred, and cannot be changed through it; a method whose
`self` is `var` takes it, once the arguments are read. Mojo reads a place
operand only once every operand of its operation is evaluated, so each place
operand must still be initialized then; so it reads a call that returns a
reference, read by value, whose origins must then still be initialized and
not invalidated. A place passed as an argument is
passed by its parameter's convention: `read`, `mut` and `ref` pass the
location, which must be initialized, and `mut` also needs a place the
function may change; `var` passes a value, which is copied implicitly unless
the argument transfers it.
A call that returns a reference and is a located operand
(`MojoGrimoire.Check.locOf`), passed to a `read`, `mut` or `ref` parameter
or to `len`, is passed the same way: it is not copied, it stands for its
origins, and for `mut` it must be mutable.

A `mut` argument may not alias another argument that is passed as a location,
Mojo's argument exclusivity. An `Int` or a `Bool` passed to a `read`
parameter is not passed as a location: Mojo copies it. A `mut` argument of
any type is.

A call records as changed each place it is passed `mut`, or `ref` when the
place may be changed, once its operands are checked; a call that returns a
reference passed so changes its origins. That invalidates the
references into the elements of a list that the place holds: the `ref`
bindings, and the place operands of an enclosing operation that were
located before the call.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Lifts a result of the program's tables into the checker. -/
def lift {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- Rejects unless the type `actual` is the type `expected`. -/
def expect (expected actual : Ty) : CheckM Unit :=
  unless expected == actual do throw (CheckError.typeMismatch expected actual)

/-- Rejects unless the place `p` may be changed: not through `q^`. -/
def requireMutable (p : Place) : CheckM Unit := do
  let v ← lookup (splitPlace p).1
  unless v.access.canChange && !throughTransfer p do throw (CheckError.immutablePlace p)

/-- Reads the place `p` as a value, which copies it implicitly: only an
implicitly copyable value may be. -/
def copyPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  unless copyingOf prog t == .implicit do throw (CheckError.implicitCopy t)
  pure t

/-- Rejects unless the value in the place `p` may be transferred out, and
gives its type. It must be initialized, and the function must own it, or
hold it `mut`: a `read` or `ref` parameter cannot give its value away. An
element of a list or an array cannot be transferred out, since it would be
left with a hole. -/
def requireTransferable (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  if splitPlace.indexed p then throw (CheckError.transferFromElement p)
  let v ← lookup (splitPlace p).1
  unless v.access.canChange do throw (CheckError.transferFromBorrowed p)
  if let .alias _ _ := v.access then throw (CheckError.transferFromBorrowed p)
  pure t

/-- Transfers the value out of the place `p`, Mojo's `p^`, which leaves `p`
uninitialized. A field moved out is recorded as moved. In Mojo, `p^` of an
`Int` or a `Bool` is the place `p`, which inference puts in its stead. -/
def transferPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← requireTransferable prog p
  let (x, path) := splitPlace p
  let v ← lookup x
  setVar { v with uninit := uninitialize v.uninit path,
                  moved := if path.isEmpty then v.moved else path :: v.moved }
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

/-- A location passed to a call: the convention it is passed by, the place
reported when it is aliased, and the places it may be. -/
structure PassedLoc where
  conv : Conv
  place : Place
  places : List Place

/-- The place `p` passed by the convention `c`. A reference counts as every
place it may point into. -/
def passedPlace (c : Conv) (p : Place) : CheckM PassedLoc := do
  pure ⟨c, p, resolvePlace (← get).vars p⟩

/-- The arguments among `args` that are passed as locations: every located
operand whose parameter is `read`, `mut` or `ref`, except an `Int` or a
`Bool` passed `read`, which is copied. A call that returns a reference is
reported by its first origin. -/
def locationArgs (prog : Program) : List Param → List Expr → CheckM (List PassedLoc)
  | prm :: prms, a :: args => do
    let rest ← locationArgs prog prms args
    if passedByValue prm then return rest
    match a, ← locOf prog a with
    | .place p, some _ => pure ((← passedPlace prm.conv p) :: rest)
    | _, some (o :: os, _) => pure (⟨prm.conv, o, o :: os⟩ :: rest)
    | _, _ => pure rest
  | _, _ => pure []

/-- Rejects a `mut` location among `locs` that overlaps another one. -/
def checkExclusive (locs : List PassedLoc) : CheckM Unit :=
  go locs []
where
  /-- Checks each location against those before and after it. -/
  go : List PassedLoc → List PassedLoc → CheckM Unit
    | [], _ => pure ()
    | l :: rest, seen => do
      let clash (o : PassedLoc) := l.places.any fun a => o.places.any (overlaps a)
      if l.conv == .mutable && (seen ++ rest).any clash then
        throw (CheckError.argumentExclusivity l.place)
      go rest (l :: seen)

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

/-- How many changes the state records so far: where an operand checked
now stands among them. -/
def mark : CheckM Nat := do pure (← get).changes.length

/-- Records that the place `p` is changed as a whole, and invalidates every
reference bound with `ref` into an element of a list that `p` holds. -/
def changePlace (prog : Program) (p : Place) : CheckM Unit := do
  for q in resolvePlace (← get).vars p do
    let m ← shapeOf prog q
    let mut stale := []
    for v in (← get).vars do
      if let .alias os _ := v.access then
        for o in os do
          if (splitPlace o).1 == m.1 && invalidates m (← shapeOf prog o) then
            stale := v.name :: stale
    modify fun s => { s with stale := union s.stale stale, changes := s.changes ++ [m] }

/-- The places among the arguments `args` that a call changes: those passed
`mut`, and those passed `ref` that may be changed. A call that returns a
reference changes its origins. -/
def changedArgs (prog : Program) : List Param → List Expr → CheckM (List Place)
  | prm :: prms, a :: args => do
    let rest ← changedArgs prog prms args
    match prm.conv, a with
    | .mutable, .place q => pure (q :: rest)
    | .ref, .place q =>
      if (← lookup (splitPlace q).1).access.canChange then pure (q :: rest) else pure rest
    | .mutable, a | .ref, a =>
      match ← locOf prog a with
      | some (os, m) => pure (if prm.conv == .mutable || m then os ++ rest else rest)
      | none => pure rest
    | _, _ => pure rest
  | _, _ => pure []

/-- Rejects the place `p`, located once `k` changes were recorded, when a
change recorded since then invalidates it. -/
def requireUnchanged (prog : Program) (p : Place) (k : Nat) : CheckM Unit := do
  let s ← get
  let later := s.changes.drop k
  unless later.isEmpty do
    for q in resolvePlace s.vars p do
      let o ← shapeOf prog q
      if later.any (invalidates · o) then throw (CheckError.invalidatedReference p)

/-- Rejects a place among the operands' locations `ls` that a later operand
left uninitialized or invalidated: Mojo reads a place operand only once
every operand of its operation is evaluated, and a reference argument is
used during the call. Each operand gives the places it is read from, with
how many changes were recorded once it was checked. -/
def recheckLocs (prog : Program) (ls : List (List Place × Nat)) : CheckM Unit :=
  ls.forM fun (ps, k) => ps.forM fun p => do
    let _ ← readPlace prog p
    requireUnchanged prog p k

/-- The places that the operand `e` is read from once every operand of its
operation is evaluated: a place itself, or the origins of a call that
returns a reference and is a located operand. Mojo reads such a call's
reference only then. -/
def lateLocs (prog : Program) : Expr → CheckM (List Place)
  | .place p => pure [p]
  | e => do pure (((← locOf prog e).map (·.1)).getD [])

/-- Rechecks the operands among `es`, read from their `lateLocs`, with
`recheckLocs`. `ks` holds, for each operand, how many changes were recorded
once it was checked. -/
def recheckPlaces (prog : Program) (es : List Expr) (ks : List Nat) : CheckM Unit := do
  recheckLocs prog (← (es.zip ks).mapM fun (e, k) => do pure (← lateLocs prog e, k))

/-- The type of a call of signature `sig`. A call that returns a reference,
used as a value, copies the value it points to implicitly, unless `asRef`
holds. -/
def refResult (prog : Program) (asRef : Bool) (sig : Signature) : CheckM Ty := do
  if sig.origin.isSome && !asRef && copyingOf prog sig.result != .implicit then
    throw (CheckError.implicitCopy sig.result)
  pure sig.result

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
    match callSig prog f with
    | .ok sig =>
      let params := sig.params
      checkExclusive (← locationArgs prog params args)
      recheckLocs prog (← checkArgs prog f params args params.length args.length)
      for q in ← changedArgs prog params args do changePlace prog q
      refResult prog asRef sig
    | .error err =>
      match f, args, err with
      | "len", [.place p], .unknownFunction _ => do
        checkIndices prog p
        let t ← readPlace prog p
        let _ ← lift (elemOf t)
        pure .int
      | "len", [e], .unknownFunction _ => do
        let t ← checkExprAs prog (← locOf prog e).isSome e
        let _ ← lift (elemOf t)
        pure .int
      | "len", _, .unknownFunction _ => throw (CheckError.arityMismatch f 1 args.length)
      | _, _, _ => throw err
  | .method p m args => do
    checkIndices prog p
    let t ← placeTy prog p
    let sig ← lift (methodSig prog t m args.length)
    let some self := sig.self | throw (CheckError.invalidSelf m)
    let params := sig.params
    let consumed := consumedReceiver self.conv p
    let recv ← match consumed with
      | some q => do pure [← passedPlace .mutable q]
      | none => if self.conv == .owned then pure [] else do pure [← passedPlace self.conv p]
    checkExclusive (recv ++ (← locationArgs prog params args))
    if consumed.isNone then passPlace prog m self.conv t p
    let k ← mark
    let ks ← checkArgs prog m params args params.length args.length
    recheckLocs prog (([p], k) :: ks)
    if let some q := consumed then let _ ← transferPlace prog q
    for q in ← changedArgs prog sig.allParams (.place p :: args) do changePlace prog q
    refResult prog asRef sig
  | .unary op a => do lift (unaryTy op (← checkExprAs prog false a))
  | .binary op a b => do
    let ta ← checkExprAs prog false a
    let ka ← mark
    let tb ← checkExprAs prog false b
    let kb ← mark
    unless op == .and || op == .or do recheckPlaces prog [a, b] [ka, kb]
    lift (binaryTy op ta tb)
  | .list t es => do
    let .ok u := elemOf t | throw (CheckError.invalidType t)
    unless validTy prog u do throw (CheckError.invalidType t)
    if let .array _ n := t then
      unless n == es.length do throw (CheckError.typeMismatch t (.array u es.length))
    recheckLocs prog
      (← checkArgs prog (typeName t) (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length)
    pure t
  | .withDrops e _ _ => checkExprAs prog asRef e

/-- Checks the index expressions of the place `p`: each is an `Int`, and
one that Mojo computes when it compiles the program may not be negative,
nor, into an array, beyond its last element. Mojo locates `q` in `q[i]`
before it evaluates `i`, so `i` may not invalidate `q`. Each `q^` in `p`
needs `q` whole, and a value that `q^` could transfer. -/
def checkIndices (prog : Program) : Place → CheckM Unit
  | .var _ => pure ()
  | .field p _ => checkIndices prog p
  | .index p i => do
    checkIndices prog p
    let k ← mark
    expect .int (← checkExprAs prog false i)
    requireUnchanged prog p k
    if let some k := constInt i then
      if k < 0 then throw (CheckError.negativeIndex (.index p i))
      if let .array _ n := (← placeTy prog p) then
        if n ≤ k then throw (CheckError.constantIndexOutOfBounds (.index p i))
  | .transferred p => do
    checkIndices prog p
    let _ ← requireTransferable prog p

/-- Checks the arguments `args` of a call of `callee` against its parameters
`params`, in order, and gives, for each, the places it is read from once
every argument is evaluated, with how many changes were recorded once it
was checked. A call that returns a reference, passed by reference, is
passed as a location, uncopied, when it is a located operand, and for
`mut` it must be mutable; the origin it is reported by is its first. One
with a temporary origin argument is checked as a value. `n` and `m` are
the numbers of parameters and arguments, for the error when they differ. -/
def checkArgs (prog : Program) (callee : Name) :
    List Param → List Expr → Nat → Nat → CheckM (List (List Place × Nat))
  | [], [], _, _ => pure []
  | prm :: prms, .place p :: args, n, m => do
    checkIndices prog p
    passPlace prog callee prm.conv prm.ty p
    let k ← mark
    pure (([p], k) :: (← checkArgs prog callee prms args n m))
  | prm :: prms, e :: args, n, m => do
    if prm.conv == .out || prm.conv == .deinit then
      throw (CheckError.invalidConvention callee)
    match ← if passedByValue prm then pure none else locOf prog e with
    | some (os, mq) =>
      expect prm.ty (← checkExprAs prog true e)
      if prm.conv == .mutable && !mq then
        throw (CheckError.immutablePlace (os.headD (.var callee)))
      let k ← mark
      pure ((os, k) :: (← checkArgs prog callee prms args n m))
    | none =>
      if prm.conv == .mutable then throw (CheckError.notAPlace callee)
      expect prm.ty (← checkExprAs prog false e)
      let k ← mark
      pure ((← lateLocs prog e, k) :: (← checkArgs prog callee prms args n m))
  | _, _, n, m => throw (CheckError.arityMismatch callee n m)
end

/-- The type of the expression `e`, used as a value. -/
def checkExpr (prog : Program) (e : Expr) : CheckM Ty := checkExprAs prog false e

end MojoGrimoire.Check
