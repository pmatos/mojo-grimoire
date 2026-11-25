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
as `main` did (`bridgedToTwin`), from the same state: the body that `main`'s
inference gave (`Program.twin`), with `main`'s checks (`Program.asMain`).
When that check fails too, its error, `main`'s, is reported; otherwise
the first error stands. A condition is bridged with the test that it is
a `Bool` (`checkCond`), and a function, method, initializer or destructor
is checked beside `main`'s twin of the same declaration
(`Program.twinBody`). So wherever `main` rejected a statement or a
condition that part 2 rejects too, it gives `main`'s error. A comparison
whose class part 2 corrects, where `main` gave another, keeps `main`'s
class until #96 part 4. The checks of a declaration as a whole, such as
its parameters, a missing `return` or what it leaves when it ends, are
not bridged.

Both checks, a statement's and its twin's, go through the bridge of #191
to `main`'s earlier order for a struct test (`MojoGrimoire.Check.bridged`),
as `main` checks each statement and condition, so that the twin's error
is `main`'s.

A temporary bridge until #96 part 4 orders the model's errors as the
compiler does.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Runs `check`, the check of a statement or a condition, which `replay`
checks as `main` did, when the statement has a twin. When `check` throws
an error and `replay`, from the same state, throws one too, the statement
gives `replay`'s error, `main`'s; when `replay` passes, the first error
stands. The twin is a thunk, forced only once `check` has failed, so that
a statement that is accepted costs nothing more. -/
def bridgedToTwin {α : Type} (check : CheckM α) (replay : Thunk (Option (CheckM α))) : CheckM α :=
  tryCatch check fun err => do
    let some replay := replay.get | throw err
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

/-- Checks the condition `c` of an `if` or a loop, whose twin is `c'`: it
must be a `Bool`. The check and the test of its type are bridged as one
(`bridgedToTwin`), each, as on `main`, through #191's bridge (`bridged`). -/
def checkCond (prog : Program) (c : Expr) (c' : Thunk (Option Expr)) : CheckM Unit :=
  bridgedToTwin (do expect .bool (← bridged (checkExpr prog c)))
    (c'.map (·.map fun c => do expect .bool (← bridged (checkExpr prog.asMain c))))

mutual
/-- Checks the statement `s` of the function `sig`, whose twin, the
statement that `main`'s inference gave, is `m`, a thunk. A statement that
holds no block is checked by `checkSimple`, through #191's bridge
(`bridged`), as on `main`, and bridged to its twin (`bridgedToTwin`); an
`if` and a loop bridge their conditions, and check their
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
    set { s0 with events := s1.events }
    checkScope prog sig elseBlock (tw.map (·.2.2))
    let s2 ← get
    set { joinStates s1 s2 with events := s2.events }
  | .whileLoop c body => do
    let tw := m.map twinWhile
    checkCond prog c (tw.map (·.1))
    let s0 ← get
    checkScope prog sig body (tw.map (·.2))
    let s1 ← get
    checkLoop s0 s1
    let head := if s1.live then { s0 with vars := List.zipWith joinMay s0.vars s1.vars,
                                          stale := union s0.stale s1.stale,
                                          interior := union s0.interior s1.interior } else s0
    if head != s0 then
      set { head with events := s1.events }
      checkCond prog c (tw.map (·.1))
      checkScope prog sig body (tw.map (·.2))
      let s2 ← get
      set { (if s2.live then { head with vars := List.zipWith joinMay head.vars s2.vars } else head)
            with events := s2.events }
    else set { head with events := s1.events }
  | s => bridgedToTwin (bridged (checkSimple prog sig s))
      (m.map (·.map fun t => bridged (checkSimple prog.asMain sig t)))

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
