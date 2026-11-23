import MojoGrimoire.Check.Stmt

/-!
The checking of blocks, and the bridge to `main`'s order within a
statement (#166).

Part 2 of #166 converts a literal compared with an array or a list to
the other operand's type. Before it, `main` rejected many such
comparisons, with a class that is often the one the compiler gives for
another error of the same statement, which the model reports in another
order than the compiler (#96, #170). A statement in which `main` agreed
with the compiler so may not change its result. So a statement, or the
condition of an `if` or a loop, that the checker rejects is checked again
(`bridged`):

- A probe checks it again from the same state, and lets the error of each
  comparison with a literal operand pass, numbering the comparisons in
  order (`MojoGrimoire.Check.probed`), but for a literal that holds a
  place whose value is not implicitly copyable.
- When the probe finds no other error and lets exactly one comparison's
  error pass, and the same probe of the statement as `main` checked it
  finds no other error either, and lets no error of the same class pass
  at the same comparison, that error is the statement's only one, which
  #166 changed, and it stands, as for the comparison alone. It stands
  too when `main`'s first error is of its class at the same comparison.
- Otherwise the statement is checked as `main` did, from the same state:
  the body that `main`'s inference gave (`Program.twin`), with `main`'s
  checks (`Program.asMain`). Its error, if it has one, is reported, and
  else the first error stands.

A temporary bridge until #96 part 4 orders the model's errors as the
compiler does.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Checks `check` again from the current state as a probe
(`State.probe`), and gives the errors of comparisons with a literal that
it let pass, with their counts (`probed`), when it finds no other error.
The state is left as it was. -/
def probeErrors {α : Type} (check : CheckM α) : CheckM (Option (List (Nat × CheckError))) := do
  let s0 ← get
  set { s0 with probe := true, seen := 0, swallowed := [] }
  let r ← tryCatch (do let _ ← check; pure (some (← get).swallowed)) fun _ => pure none
  set s0
  pure r

/-- Runs `check`, the check of a statement or a condition, which `replay`
checks as `main` did, when the statement has a twin. When `check` throws
an error and the statement has a twin, the statement gives `main`'s
error, which `replay` finds, unless its only error is that of one
comparison with a literal that #166 changed. A probe tells that
(`probeErrors`): it finds no other error and lets exactly one
comparison's error pass, and the same probe of `replay` finds no other
error either, and lets no error of the same class pass at the same
comparison, or lets it pass first, when `main`'s class is the same. The
first error then stands, as it does when `replay` finds no error. The
twin is a thunk, forced only once `check` has failed, so that a
statement that is accepted costs nothing more. -/
def bridged {α : Type} (check : CheckM α) (replay : Thunk (Option (CheckM α))) : CheckM α :=
  tryCatch check fun err => do
    let some replay := replay.get | throw err
    if let some [(n, e)] ← probeErrors check then
      let same := fun ((m, e') : Nat × CheckError) => m == n && e'.ctorIdx == e.ctorIdx
      if let some es ← probeErrors replay then
        if !es.any same || es.head?.any same then throw err
    let replayed ← tryCatch (do let _ ← replay; pure err) pure
    throw replayed

/-- The condition and the blocks of the twin `m` of an `if`, when it is one. -/
def twinIf : Option Stmt → Option Expr × List Stmt × List Stmt
  | some (.ifElse c t e) => (some c, t, e)
  | _ => (none, [], [])

/-- The condition and the body of the twin `m` of a loop, when it is one. -/
def twinWhile : Option Stmt → Option Expr × List Stmt
  | some (.whileLoop c b) => (some c, b)
  | _ => (none, [])

/-- Checks the condition `c` of an `if` or a loop, whose twin is `c'`
(`bridged`). -/
def checkCond (prog : Program) (c : Expr) (c' : Thunk (Option Expr)) : CheckM Unit := do
  expect .bool (← bridged (checkExpr prog c) (c'.map (·.map (checkExpr prog.asMain))))

mutual
/-- Checks the statement `s` of the function `sig`, whose twin, the
statement that `main`'s inference gave, is `m`, a thunk. A statement that
holds no block is checked by `checkSimple`, bridged to `main`'s order
(`bridged`); an `if` and a loop bridge their conditions, and check their
blocks beside their twins. -/
def checkStmt (prog : Program) (sig : FunDecl) (s : Stmt) (m : Thunk (Option Stmt)) :
    CheckM Unit :=
  match s with
  | .ifElse c thenBlock elseBlock => do
    let tw := m.map twinIf
    checkCond prog c (tw.map (·.1))
    let s0 ← get
    checkScope prog sig thenBlock (tw.map (·.2.1))
    let s1 ← get
    set s0
    checkScope prog sig elseBlock (tw.map (·.2.2))
    set (joinStates s1 (← get))
  | .whileLoop c body => do
    let tw := m.map twinWhile
    checkCond prog c (tw.map (·.1))
    let s0 ← get
    checkScope prog sig body (tw.map (·.2))
    let s1 ← get
    checkLoop s0 s1
    let head := if s1.live then { s0 with vars := List.zipWith joinMay s0.vars s1.vars,
                                          stale := union s0.stale s1.stale } else s0
    if head != s0 then
      set head
      checkCond prog c (tw.map (·.1))
      checkScope prog sig body (tw.map (·.2))
      let s2 ← get
      set (if s2.live then { head with vars := List.zipWith joinMay head.vars s2.vars } else head)
    else set head
  | s => bridged (checkSimple prog sig s) (m.map (·.map (checkSimple prog.asMain sig)))

/-- Checks the block `b` as a scope of its own, beside its twin `ms`, a
thunk. -/
def checkScope (prog : Program) (sig : FunDecl) (b : List Stmt) (ms : Thunk (List Stmt)) :
    CheckM Unit := do
  let n := (← get).vars.length
  checkBlock prog sig b ms
  endScope prog n

/-- Checks the statements of a block in order, each beside its twin in
`ms`, the block that `main`'s inference gave, when it has one. -/
def checkBlock (prog : Program) (sig : FunDecl) : List Stmt → Thunk (List Stmt) → CheckM Unit
  | [], _ => pure ()
  | s :: rest, ms => do
    modify fun st => { st with changes := [] }
    checkStmt prog sig s (ms.map (·.head?))
    checkBlock prog sig rest (ms.map (·.tail))
end

end MojoGrimoire.Check
