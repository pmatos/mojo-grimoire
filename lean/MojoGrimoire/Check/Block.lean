import MojoGrimoire.Check.Stmt

/-!
The checking of blocks: the statements of a block in order, the conditions
of `if` and loops, and the joins of their branches and iterations.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Checks the condition `c` of an `if` or a loop: it must be a `Bool`. -/
def checkCond (prog : Program) (c : Expr) : CheckM Unit := do
  expect .bool (← checkExpr prog c)

mutual
/-- Checks the statement `s` of the function `sig`. A statement that holds
no block is checked by `checkSimple`; an `if` and a loop check their
conditions and their blocks. -/
def checkStmt (prog : Program) (sig : FunDecl) (s : Stmt) : CheckM Unit :=
  match s with
  | .ifElse c thenBlock elseBlock => do
    checkCond prog c
    let s0 ← get
    checkScope prog sig thenBlock
    let s1 ← get
    restoreKeeping s0
    checkScope prog sig elseBlock
    restoreKeeping (joinStates s1 (← get))
  | .whileLoop c body => do
    checkCond prog c
    let s0 ← get
    checkScope prog sig body
    let s1 ← get
    checkLoop s0 s1
    let head := if s1.live then { s0 with vars := List.zipWith joinMay s0.vars s1.vars,
                                          stale := union s0.stale s1.stale,
                                          interior := union s0.interior s1.interior } else s0
    if head != s0 then
      set head
      checkCond prog c
      checkScope prog sig body
      let s2 ← get
      set (if s2.live then { head with vars := List.zipWith joinMay head.vars s2.vars } else head)
    else set head
    modify fun s => { s with events := s1.events }
  | s => checkSimple prog sig s

/-- Checks the block `b` as a scope of its own. -/
def checkScope (prog : Program) (sig : FunDecl) (b : List Stmt) : CheckM Unit := do
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
