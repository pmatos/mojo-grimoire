import MojoGrimoire.Check.Ref

/-!
The checking of statements and blocks.

A block is a scope: the variables it declares end with it. A declaration
may not reuse the name of a variable in scope, so no variable hides
another, though sibling blocks may reuse a name. When inference could not
find a declaration's type, the checker checks its initializer before it
rejects the declaration, so that the initializer's own error is reported,
as the compiler does (#123).
After an `if`, a part of a variable is
initialized only when both branches leave it initialized, and a branch that
returns does not count. A loop body that can reach its end must leave
initialized every part that was initialized before the loop, or its next
iteration would use a moved value: like Mojo, the checker reports that as
a use of an uninitialized value. What the body may leave moved out,
holding a value, touched or built from its fields counts after the loop
too.

Where a variable ends, at the end of its block or when the function
returns, the parts it still holds are destroyed. The compiler destroys a
struct whole, so a variable may not end with a field moved out and not
assigned again while it still holds a part, nor partly built on some path,
with a field never assigned while it holds another, as the human ruled
(R, D-0003). A variable that holds nothing may end, unless a field was
moved out of a part held whole (#51).
Assigning to a part destroys its old value, so the same holds for the
part, and a part moved out may not be assigned whole once some of its
fields were assigned. Assigning through a reference, or to an
element, needs the old value initialized, with no field moved out. A loop
body may not leave a field moved out that was initialized before the loop
and not moved out. The
`self` of `__deinit__` is the exception:
its own fields may stay moved out, since it is being destroyed field by
field. When a function returns, its `mut` parameters and the `self` of
`__init__` must be wholly initialized, since the caller holds them.

Returning a variable that the function owns moves it out, as Mojo does; any
other place is copied, implicitly. A literal with no list or array expected
that initializes a declared variable, a place assigned to or a function's
result fits no initializer of its type (#46). A function that returns a reference
returns a location within its own origin, as `withinOrigin` decides.

An assignment changes its place as a whole. After an `if`, a reference is
invalidated when either branch invalidates it. A loop whose body can reach
its end and leaves a part moved out, a part that may hold a value, a
touched part, a piece or an invalidated reference that the state before
the loop lacks is checked once more from the state before it with those
added, since the next iteration starts so; the state after the loop has
them too. The changes recorded for operands start afresh with each
statement.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether the parts `hs` of a value of type `t` hold all of its part
`q`: one of them is at or above `q`, or `q` is a struct and they hold each
of its fields. A part held whole and then given a field again is recorded
as its fields, which hold it all. -/
def holdsAll (prog : Program) (t : Ty) (hs : List Path) (q : Path) : Bool :=
  go (hs.foldl (fun n h => max n h.length) 0) q
where
  /-- `holdsAll` with fuel `n`, at least the depth of the parts in `hs`. -/
  go : Nat → Path → Bool
    | 0, q => hs.any (·.isPrefixOf q)
    | n + 1, q => hs.any (·.isPrefixOf q) ||
      let fs := fieldNames prog (partTy prog t q)
      !fs.isEmpty && fs.all fun f => go n (q ++ [f])

/-- Whether a value of type `t` may be destroyed partly built, given its
uninitialized parts `us`, its parts that may hold a value `hs` and its
pieces `ps`: a part may be uninitialized while another part of it may
hold a value, unless the parts of `hs` below it hold all of it, or a part
may be held whole and another part of it uninitialized, or two disjoint
parts may be one uninitialized and the other held; or a piece may be
uninitialized while a part near it may hold one. The compiler destroys a
struct whole, and rejects a value with a field moved out; the human ruled
that a field never assigned counts the same (R, D-0003). Since `us`, `hs`
and `ps` hold what may be so on some path, a part uninitialized on one
path and held on another counts, as the compiler counts a field moved out
on one path only, unless it is held whole on every path that holds it, as
a variable assigned whole in one branch. A part built from its fields is
a piece, and the join of `hs` may fold its fields into it, so the last
condition finds it. The parts from depth `start` down are values of their
own: 1 for the `self` of `__deinit__`, destroyed field by field, and 0 for
any other value. -/
def partlyBuilt (prog : Program) (t : Ty) (us hs ps : List Path) (start : Nat) : Bool :=
  us.any (fun u => start ≤ u.length && hs.any fun h =>
      let (u', h') := (u.drop start, h.drop start)
      !initialized [u.take start] (h.take start) && u' != h' &&
        !(u'.isPrefixOf h' && holdsAll prog t hs u)) ||
    ps.any fun p => start ≤ p.length && us.any (·.isPrefixOf p) && !initialized hs p

/-- Whether a value of type `t` may not be destroyed, given its uninitialized parts
`us`, its parts moved out `ms`, its parts that may hold a value `hs`, its
touched parts `ts` and its pieces `ps`. It may not when it still holds a
part and a field was moved out of it, or it was moved out whole and then
built from its fields; when a field was moved out of a touched part; or
when it may be partly built. Parts from depth `start` down count, as in
`partlyBuilt`. -/
def cannotEnd (prog : Program) (t : Ty) (us ms hs ts ps : List Path) (start : Nat) : Bool :=
  let ms := ms.filter fun m => start == 0 || start < m.length
  let fields := ms.filter (!·.isEmpty)
  ((!fields.isEmpty || (ms.contains [] && ps.contains [])) && !hs.isEmpty) ||
    ts.any (fun c => fields.any (c.isPrefixOf ·)) ||
    partlyBuilt prog t us hs ps start

/-- Rejects the variable `v` if it may not end as it is. For the `self` of
`__deinit__`, only fields of its fields count. -/
def checkEnd (prog : Program) (v : VarState) : CheckM Unit := do
  let start := if v.access == .dying then 1 else 0
  if cannotEnd prog v.ty v.uninit v.moved v.held v.touched v.pieces start then
    throw (CheckError.partiallyDestroyed v.name)

/-- Rejects the state at a return: every `mut` parameter and the `self` of
`__init__` must be wholly initialized, with no part built from its fields,
and every variable must be allowed to end, checked after, as the compiler
reports a parameter left uninitialized first. The caller uses a `mut`
parameter whole, so the compiler reports one that is itself built field by
field as a use of it. -/
def checkExit (prog : Program) : CheckM Unit := do
  let vars := (← get).vars
  for v in vars do
    if v.access == .mutable || v.access == .constructing then
      if v.uninit.isEmpty && v.pieces == [[]] then
        throw (CheckError.uninitializedUse (.var v.name))
      if !v.uninit.isEmpty || !v.pieces.isEmpty then
        throw (CheckError.uninitializedAtExit v.name)
  for v in vars do
    if v.access != .readOnly then checkEnd prog v

/-- Ends the variables declared since the scope had `n` variables: checks
that each may end, if the end of the scope is reached, and removes them. -/
def endScope (prog : Program) (n : Nat) : CheckM Unit := do
  let s ← get
  let ended := s.vars.take (s.vars.length - n)
  if s.live then
    for v in ended do checkEnd prog v
  set { s with vars := s.vars.drop (s.vars.length - n),
               stale := s.stale.filter fun x => !ended.any (·.name == x) }

/-- The uninitialized parts after two branches: those of either. -/
def joinUninit (a b : List Path) : List Path :=
  b.foldl uninitialize a

/-- The variable `v` with the parts moved out, the parts that may hold a
value, the touched parts and the pieces of `w` added: what either of two
paths may leave. -/
def joinMay (v w : VarState) : VarState :=
  { v with moved := union v.moved w.moved, held := joinUninit v.held w.held,
           touched := union v.touched w.touched, pieces := union v.pieces w.pieces }

/-- The state after two branches that started from the same state: a part
is uninitialized, a field moved out, or a reference invalidated, when either
branch leaves it so. A branch that cannot reach its end does not count. -/
def joinStates (a b : State) : State :=
  if !a.live then b
  else if !b.live then a
  else { a with
         vars := List.zipWith (fun v w =>
             { joinMay v w with uninit := joinUninit v.uninit w.uninit })
           a.vars b.vars,
         stale := union a.stale b.stale }

/-- Rejects a loop whose body, from the state `before`, ends in the state
`after` with a part uninitialized that was initialized before, or with a
part moved out that was initialized and not moved out before: the next
iteration would use it uninitialized. A part uninitialized before the loop
may be assigned and moved out in each iteration. -/
def checkLoop (before after : State) : CheckM Unit := do
  if after.live then
    for (v, w) in List.zip before.vars after.vars do
      let fresh := w.uninit.filter (fun u => !v.uninit.any (·.isPrefixOf u)) ++
        w.moved.filter fun m => !v.moved.contains m && !v.uninit.any (·.isPrefixOf m)
      if let some u := fresh.head? then throw (CheckError.uninitializedUse (partPlace v.name u))

/-- Whether `print` can write a value of type `t`: an `Int`, a `Bool`, or a
list or an array of values it can write. -/
def printable : Ty → Bool
  | .int | .bool => true
  | .list t | .array t _ => printable t
  | _ => false

/-- Checks a value printed by `print`: a string literal, or a value that
`print` can write. `print` reads a place by reference, so it copies
nothing, and a call that returns a reference gives the value it points
to, uncopied. -/
def checkPrintArg (prog : Program) : Expr → CheckM Unit
  | .str _ => pure ()
  | e => do
    let t ← match e with
      | .place p => do checkIndices prog p; readPlace prog p
      | e => checkExprAs prog true e
    unless printable t do throw (CheckError.notPrintable t)

/-- Rejects the assignment of the value `e` to the place `p` inside an
element of a list when `e` is a call that builds its result in `p` and is
passed `mut` that list, or a place that holds it: Mojo reports the result
as aliased with the argument. A call, an initializer included, builds its
result in place unless the result is an `Int`, a `Bool` or a reference; a
generic result, such as the element that a list method gives, always is.
`List[u](e)` builds its result in place too, and passes `e` by `ref`
(#103). -/
def checkConstructed (prog : Program) (p : Place) (e : Expr) : CheckM Unit := do
  let builds (sig : Signature) := sig.origin.isNone && (sig.generic || !sig.result.byValue)
  let changed ← match e with
    | .call f args => match callSig prog f with
      | .ok sig => if builds sig then changedArgs prog sig.params args else pure []
      | .error _ => pure []
    | .method q m args => match methodSig prog (← placeTy prog q) m args.length with
      | .ok sig => if builds sig then changedArgs prog sig.allParams (.place q :: args) else pure []
      | .error _ => pure []
    | .listInit u [a] => changedArgs prog [⟨.ref, "iterable", .list u⟩] [a]
    | _ => pure []
  let vars := (← get).vars
  for q in changed do
    for m in resolvePlace vars q do
      let ms ← shapeOf prog m
      for t in resolvePlace vars p do
        if invalidates ms (← shapeOf prog t) then throw (CheckError.argumentExclusivity q)

/-- Checks the value `e` that initializes a value of the type `t`, given
`value`, which checks it and gives its type. A literal with no type expected,
where `t` is not a list or an array, fits no initializer of `t`: Mojo calls
`t`'s initializer with the elements, which none takes (#46). -/
def checkInitValue (prog : Program) (t : Ty) (e : Expr) (value : CheckM Ty) : CheckM Unit := do
  if let .list .noneType es := e then
    unless t matches .list _ | .array .. do
      checkOperands prog es
      throw (CheckError.noMatchingInit t)
  expect t (← value)

/-- The type of the value of `return e`: a variable that the function owns
is moved out, and any other expression is checked as usual. -/
def checkReturnValue (prog : Program) : Expr → CheckM Ty
  | .place (.var x) => do
    let v ← lookup x
    if v.access == .owned then transferPlace prog (.var x) else copyPlace prog (.var x)
  | e => checkExpr prog e

mutual
/-- Checks the statement `s` of the function `sig`, whose name, result type
and origin a `return` is checked against. -/
def checkStmt (prog : Program) (sig : FunDecl) : Stmt → CheckM Unit
  | .pass => pure ()
  | .decl x t init => do
    if (← get).vars.any (·.name == x) then throw (CheckError.duplicate x)
    unless validTy prog t do
      if let (.noneType, some e) := (t, init) then let _ ← checkExpr prog e
      throw (CheckError.invalidType t)
    let us ← match init with
      | some e => do checkInitValue prog t e (checkExpr prog e); pure []
      | none => pure [[]]
    let hs := if us.isEmpty then [[]] else []
    modify fun s => { s with vars := ⟨x, t, .owned, us, [], hs, [], []⟩ :: s.vars }
  | .refDecl x e => do
    if (← get).vars.any (·.name == x) then throw (CheckError.duplicate x)
    let (t, origins, m) ← refTarget prog e
    modify fun s => { s with vars := ⟨x, t, .alias origins m, [], [], [], [], []⟩ :: s.vars }
  | .assign p e => do
    let t ← match e with
      | .list .noneType _ => do
        let u ← placeTy prog p
        checkInitValue prog u e (checkExpr prog e)
        pure u
      | _ => checkExpr prog e
    checkIndices prog p
    expect (← placeTy prog p) t
    checkConstructed prog p e
    requireMutable p
    changePlace prog p
    let (x, path) := splitPlace p
    let v ← lookup x
    if splitPlace.indexed p || v.access matches .alias .. then
      let _ ← readPlace prog p
      return
    let ts := (if (above path v.touched).isEmpty then [] else [[]]) ++ atOrBelow path v.touched
    if cannotEnd prog (partTy prog v.ty path) (partsWithin path v.uninit) (atOrBelow path v.moved)
        (partsWithin path v.held) ts (atOrBelow path v.pieces) 0 then
      throw (CheckError.partiallyDestroyed x)
    let built := (above path v.uninit).flatMap (piecesTo · path)
    let built := if v.access == .constructing && !v.moved.contains [] then built.filter (!·.isEmpty)
      else built
    let outside (us : List Path) := us.filter (!path.isPrefixOf ·)
    setVar { v with uninit := initPart prog v.uninit v.ty path, moved := outside v.moved,
                    held := uninitialize v.held path,
                    touched := union (outside v.touched) (above path v.held),
                    pieces := union (outside v.pieces) built }
  | .expr e => do let _ ← checkExpr prog e
  | .print args => do
    let ks ← args.attach.mapM fun ⟨e, _⟩ => do checkPrintArg prog e; mark
    recheckPlaces prog args ks
  | .ifElse c thenBlock elseBlock => do
    expect .bool (← checkExpr prog c)
    let s0 ← get
    checkScope prog sig thenBlock
    let s1 ← get
    set s0
    checkScope prog sig elseBlock
    set (joinStates s1 (← get))
  | .whileLoop c body => do
    expect .bool (← checkExpr prog c)
    let s0 ← get
    checkScope prog sig body
    let s1 ← get
    checkLoop s0 s1
    let head := if s1.live then { s0 with vars := List.zipWith joinMay s0.vars s1.vars,
                                          stale := union s0.stale s1.stale } else s0
    if head != s0 then
      set head
      expect .bool (← checkExpr prog c)
      checkScope prog sig body
      let s2 ← get
      set (if s2.live then { head with vars := List.zipWith joinMay head.vars s2.vars } else head)
    else set head
  | .ret value => do
    match value, sig.origin with
    | none, _ => unless sig.result == .noneType do throw (CheckError.invalidReturn sig.name)
    | some e, none => do
      if sig.result == .noneType then throw (CheckError.invalidReturn sig.name)
      checkInitValue prog sig.result e (checkReturnValue prog e)
    | some e, some os => do
      let (t, origins, _) ← refTarget prog e
      expect sig.result t
      unless ← origins.allM (withinOrigin prog os) do
        throw (CheckError.escapingReference sig.name)
    checkExit prog
    modify fun s => { s with live := false }
  | .drop p => do
    let _ ← transferPlace prog p

/-- Checks the block `b` as a scope of its own. -/
def checkScope (prog : Program) (sig : FunDecl) (b : List Stmt) :
    CheckM Unit := do
  let n := (← get).vars.length
  checkBlock prog sig b
  endScope prog n

/-- Checks the statements of a block in order. -/
def checkBlock (prog : Program) (sig : FunDecl) : List Stmt → CheckM Unit
  | [] => pure ()
  | s :: rest => do
    modify fun st => { st with changes := [] }
    checkStmt prog sig s
    checkBlock prog sig rest
end

end MojoGrimoire.Check
