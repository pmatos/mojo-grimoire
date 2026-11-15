import MojoGrimoire.Check.Expr

/-!
The checking of statements and blocks.

A block is a scope: the variables it declares end with it, and a name is
declared at most once in a block, though an inner block may declare a name
of an outer one, which it hides. After an `if`, a part of a variable is
initialized only when both branches leave it initialized, and a branch that
returns does not count. A loop body must leave initialized every part that
was initialized before the loop, or its next iteration would use a moved
value.

Where a variable ends, at the end of its block or when the function
returns, the parts it still holds are destroyed. A variable may end with
parts moved out, and the rest is destroyed field by field, unless a part
with fields moved out has a `__deinit__` of its own, which needs the whole
value. The `self` of `__deinit__` is the exception: its fields may be moved
out, since it is being destroyed. When a function returns, its `mut`
parameters and the `self` of `__init__` must be wholly initialized, since
the caller holds them.

Returning a variable that the function owns moves it out, as Mojo does; any
other place is copied, implicitly.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether a variable of type `t` whose uninitialized parts are `us` has a
part with fields moved out whose type has a `__deinit__` of its own. The
parts from depth `from` down count: 1 for the `self` of `__deinit__`, whose
own destructor is running, and 0 for any other variable. -/
def partlyMovedDeinit (prog : Program) (t : Ty) (us : List Path) (start : Nat) : Bool :=
  us.any fun u => ((List.range u.length).filter (start ≤ ·)).any fun k =>
    hasDeinit prog (partTy prog t (u.take k))

/-- Rejects the variable `v` if it may not end as it is: with a part
moved out that a destructor of its own needs whole. -/
def checkEnd (prog : Program) (v : VarState) : CheckM Unit := do
  let start := if v.access == .dying then 1 else 0
  if partlyMovedDeinit prog v.ty v.uninit start then
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
  set { s with vars := s.vars.drop (s.vars.length - n) }

/-- The uninitialized parts after two branches: those of either. -/
def joinUninit (a b : List Path) : List Path :=
  b.foldl uninitialize a

/-- The state after two branches that started from the same state. A branch
that cannot reach its end does not count. -/
def joinStates (a b : State) : State :=
  if !a.live then b
  else if !b.live then a
  else { vars := List.zipWith (fun v w => { v with uninit := joinUninit v.uninit w.uninit })
           a.vars b.vars,
         live := true }

/-- Rejects a loop whose body, from the state `before`, ends in the state
`after` with a part uninitialized that was initialized before. -/
def checkLoop (before after : State) : CheckM Unit := do
  if after.live then
    for (v, w) in List.zip before.vars after.vars do
      unless w.uninit.all (fun u => v.uninit.any (·.isPrefixOf u)) do
        throw (CheckError.movedInLoop v.name)

/-- Checks a value printed by `print`: a string literal, an `Int` or a
`Bool`. -/
def checkPrintArg (check : Expr → CheckM Ty) : Expr → CheckM Unit
  | .str _ => pure ()
  | e => do
    let t ← check e
    unless t == .int || t == .bool do throw (CheckError.notPrintable t)

/-- The type of the value of `return e`: a variable that the function owns
is moved out, and any other expression is checked as usual. -/
def checkReturnValue (prog : Program) : Expr → CheckM Ty
  | .place (.var x) => do
    let v ← lookup x
    if v.access == .owned then transferPlace prog (.var x) else copyPlace prog (.var x)
  | e => checkExpr prog e

mutual
/-- Checks the statement `s` of the function `fn`, whose result type is
`result`. -/
def checkStmt (prog : Program) (fn : Name) (result : Ty) : Stmt → CheckM Unit
  | .pass => pure ()
  | .decl x t init => do
    unless validTy prog t do throw (CheckError.invalidType t)
    let us ← match init with
      | some e => do expect t (← checkExpr prog e); pure []
      | none => pure [[]]
    modify fun s => { s with vars := ⟨x, t, .owned, us⟩ :: s.vars }
  | .assign p e => do
    let t ← checkExpr prog e
    expect (← placeTy prog p) t
    requireMutable p
    let (x, path) := splitPlace p
    let v ← lookup x
    let below := (v.uninit.filter fun u => path.isPrefixOf u && u != path).map (·.drop path.length)
    if partlyMovedDeinit prog (partTy prog v.ty path) below 0 then
      throw (CheckError.partiallyDestroyed x)
    setUninit x (initPart prog v.uninit v.ty path)
  | .expr e => do let _ ← checkExpr prog e
  | .print args => args.attach.forM fun ⟨e, _⟩ => checkPrintArg (checkExpr prog) e
  | .ifElse c thenBlock elseBlock => do
    expect .bool (← checkExpr prog c)
    let s0 ← get
    checkScope prog fn result thenBlock
    let s1 ← get
    set s0
    checkScope prog fn result elseBlock
    set (joinStates s1 (← get))
  | .whileLoop c body => do
    expect .bool (← checkExpr prog c)
    let s0 ← get
    checkScope prog fn result body
    checkLoop s0 (← get)
    set s0
  | .ret value => do
    match value with
    | none => unless result == .noneType do throw (CheckError.invalidReturn fn)
    | some e => do
      if result == .noneType then throw (CheckError.invalidReturn fn)
      expect result (← checkReturnValue prog e)
    checkExit prog
    modify fun s => { s with live := false }
  | .drop p => do
    let _ ← transferPlace prog p

/-- Checks the block `b` as a scope of its own. -/
def checkScope (prog : Program) (fn : Name) (result : Ty) (b : List Stmt) :
    CheckM Unit := do
  let n := (← get).vars.length
  checkBlock prog fn result [] b
  endScope prog n

/-- Checks the statements of a block in order. `declared` holds the names
the block has declared so far, which it may not declare again. -/
def checkBlock (prog : Program) (fn : Name) (result : Ty) (declared : List Name) :
    List Stmt → CheckM Unit
  | [] => pure ()
  | s :: rest => do
    let declared ← match s with
      | .decl x _ _ => do
        if declared.contains x then throw (CheckError.duplicate x)
        pure (x :: declared)
      | _ => pure declared
    checkStmt prog fn result s
    checkBlock prog fn result declared rest
end

end MojoGrimoire.Check
