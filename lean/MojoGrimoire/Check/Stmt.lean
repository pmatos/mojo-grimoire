import MojoGrimoire.Check.Ref

/-!
The checking of statements and blocks.

A block is a scope: the variables it declares end with it. A declaration
may not reuse the name of a variable in scope, so no variable hides
another, though sibling blocks may reuse a name. After an `if`, a part of a variable is
initialized only when both branches leave it initialized, and a branch that
returns does not count. A loop body must leave initialized every part that
was initialized before the loop, or its next iteration would use a moved
value: like Mojo, the checker reports that as a use of an uninitialized
value.

Where a variable ends, at the end of its block or when the function
returns, the parts it still holds are destroyed. The compiler destroys a
struct whole, so a variable may not end with a field moved out and not
assigned again, nor with a part uninitialized below a struct that has a
`__deinit__` of its own. Assigning to a part destroys its old value, so
the same holds for the part. Assigning through a reference, or to an
element, needs the old value initialized, with no field moved out. A loop
body may not leave a field moved out that was not before the loop. The
`self` of `__deinit__` is the exception:
its own fields may stay moved out, since it is being destroyed field by
field. When a function returns, its `mut` parameters and the `self` of
`__init__` must be wholly initialized, since the caller holds them.

Returning a variable that the function owns moves it out, as Mojo does; any
other place is copied, implicitly.

An assignment changes its place as a whole. After an `if`, a reference is
invalidated when either branch invalidates it. A loop whose body can reach
its end and invalidates a reference is checked once more from the state
where it is invalidated, since the next iteration uses it so. The changes
recorded for operands start afresh with each statement.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether a value of type `t` whose uninitialized parts are `us` has an
uninitialized part below a part whose type has a `__deinit__` of its own.
The parts from depth `start` down count: 1 for the `self` of `__deinit__`,
whose own destructor is running, and 0 for any other value. -/
def partlyMovedDeinit (prog : Program) (t : Ty) (us : List Path) (start : Nat) : Bool :=
  us.any fun u => ((List.range u.length).filter (start ≤ ·)).any fun k =>
    hasDeinit prog (partTy prog t (u.take k))

/-- Whether a value of type `t`, whose uninitialized parts are `us` and
whose moved fields are `ms`, may not be destroyed: it has a field moved out
and not assigned again, or an uninitialized part that a destructor of its
own needs whole. Parts from depth `start` down count, as in
`partlyMovedDeinit`. -/
def cannotEnd (prog : Program) (t : Ty) (us ms : List Path) (start : Nat) : Bool :=
  ms.any (start < ·.length) || partlyMovedDeinit prog t us start

/-- Rejects the variable `v` if it may not end as it is. For the `self` of
`__deinit__`, only fields of its fields count. -/
def checkEnd (prog : Program) (v : VarState) : CheckM Unit := do
  let start := if v.access == .dying then 1 else 0
  if cannotEnd prog v.ty v.uninit v.moved start then
    throw (CheckError.partiallyDestroyed v.name)

/-- Rejects the state at a return: every `mut` parameter and the `self` of
`__init__` must be wholly initialized, and every variable must be allowed
to end. -/
def checkExit (prog : Program) : CheckM Unit := do
  for v in (← get).vars do
    if (v.access == .mutable || v.access == .constructing) && !v.uninit.isEmpty then
      throw (CheckError.uninitializedAtExit v.name)
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

/-- The state after two branches that started from the same state: a part
is uninitialized, a field moved out, or a reference invalidated, when either
branch leaves it so. A branch that cannot reach its end does not count. -/
def joinStates (a b : State) : State :=
  if !a.live then b
  else if !b.live then a
  else { a with
         vars := List.zipWith (fun v w =>
             { v with uninit := joinUninit v.uninit w.uninit, moved := union v.moved w.moved })
           a.vars b.vars,
         stale := union a.stale b.stale }

/-- Rejects a loop whose body, from the state `before`, ends in the state
`after` with a part uninitialized that was initialized before, or with a
field moved out that was not moved out before: the next iteration would use
it uninitialized. -/
def checkLoop (before after : State) : CheckM Unit := do
  if after.live then
    for (v, w) in List.zip before.vars after.vars do
      let fresh := w.uninit.filter (fun u => !v.uninit.any (·.isPrefixOf u)) ++
        w.moved.filter (!v.moved.contains ·)
      if let some u := fresh.head? then throw (CheckError.uninitializedUse (partPlace v.name u))

/-- Checks a value printed by `print`: a string literal, an `Int` or a
`Bool`. -/
def checkPrintArg (check : Expr → CheckM Ty) : Expr → CheckM Unit
  | .str _ => pure ()
  | e => do
    let t ← check e
    unless t == .int || t == .bool do throw (CheckError.notPrintable t)

/-- Rejects the assignment of the value `e` to the place `p` inside an
element of a list when `e` is a call that builds its result in `p` and is
passed `mut` that list, or a place that holds it: Mojo reports the result
as aliased with the argument. A call, an initializer included, builds its
result in place unless the result is an `Int`, a `Bool` or a reference; a
generic result, such as the element that a list method gives, always is. -/
def checkConstructed (prog : Program) (p : Place) (e : Expr) : CheckM Unit := do
  let builds (sig : Signature) := sig.origin.isNone && (sig.generic || !sig.result.byValue)
  let changed ← match e with
    | .call f args => match callSig prog f with
      | .ok sig => if builds sig then changedArgs sig.params args else pure []
      | .error _ => pure []
    | .method q m args => match methodSig prog (← placeTy prog q) m args.length with
      | .ok sig => if builds sig then changedArgs sig.allParams (.place q :: args) else pure []
      | .error _ => pure []
    | _ => pure []
  let vars := (← get).vars
  for q in changed do
    for m in resolvePlace vars q do
      let ms ← shapeOf prog m
      for t in resolvePlace vars p do
        if invalidates ms (← shapeOf prog t) then throw (CheckError.argumentExclusivity q)

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
    unless validTy prog t do throw (CheckError.invalidType t)
    let us ← match init with
      | some e => do expect t (← checkExpr prog e); pure []
      | none => pure [[]]
    modify fun s => { s with vars := ⟨x, t, .owned, us, []⟩ :: s.vars }
  | .refDecl x e => do
    if (← get).vars.any (·.name == x) then throw (CheckError.duplicate x)
    let (t, origins, m) ← refTarget prog e
    modify fun s => { s with vars := ⟨x, t, .alias origins m, [], []⟩ :: s.vars }
  | .assign p e => do
    let t ← checkExpr prog e
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
    if cannotEnd prog (partTy prog v.ty path) (below path v.uninit) (below path v.moved) 0 then
      throw (CheckError.partiallyDestroyed x)
    setVar { v with uninit := initPart prog v.uninit v.ty path, moved := v.moved.erase path }
  | .expr e => do let _ ← checkExpr prog e
  | .print args => do
    let ks ← args.attach.mapM fun ⟨e, _⟩ => do checkPrintArg (checkExpr prog) e; mark
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
    let fresh := s1.stale.filter (!s0.stale.contains ·)
    if s1.live && !fresh.isEmpty then
      set { s0 with stale := s0.stale ++ fresh }
      expect .bool (← checkExpr prog c)
      checkScope prog sig body
    set { s0 with stale := if s1.live then union s0.stale fresh else s0.stale }
  | .ret value => do
    match value, sig.origin with
    | none, _ => unless sig.result == .noneType do throw (CheckError.invalidReturn sig.name)
    | some e, none => do
      if sig.result == .noneType then throw (CheckError.invalidReturn sig.name)
      expect sig.result (← checkReturnValue prog e)
    | some e, some os => do
      let (t, origins, _) ← refTarget prog e
      expect sig.result t
      unless origins.all (fun o => os.contains (splitPlace o).1) do
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
