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
  comparison with a literal that does not keep `main`'s checks pass,
  counting them (`MojoGrimoire.Check.probed`), but for a literal that
  holds a place whose value is not implicitly copyable. When the probe finds no
  other error and let one pass, the statement's only error is that
  comparison's own, and it stands, as for the comparison alone.
- Otherwise the statement is checked as `main` did, from the same state:
  the body that `main`'s inference gave (`Program.twin`), with `main`'s
  checks (`Program.asMain`). Its error, if it has one, is reported, and
  else the first error stands, as it does when it is found as the
  program is typed and `main`'s is one of ownership, which the compiler
  reports later (#96), or is found as the program is typed too.

A temporary bridge until #96 part 4 orders the model's errors as the
compiler does.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether the compiler finds the error `e` as it types the program: a
type mismatch, a method that a type lacks, or a name it does not know. -/
def CheckError.typed : CheckError → Bool
  | .typeMismatch .. | .missingMethod .. | .unknownVariable _ | .unknownFunction _
  | .unknownAttribute .. => true
  | _ => false

/-- Whether the error `e` is one of ownership: an implicit copy, or the use
of an uninitialized value. -/
def CheckError.owned : CheckError → Bool
  | .implicitCopy _ | .uninitializedUse _ => true
  | _ => false

/-- Runs `check`, the check of a statement or a condition, which `replay`
checks as `main` did, when the statement has a twin. When `check` throws
an error, a probe runs it again from the same state (`State.probe`): when
it finds no error and lets exactly one comparison's error pass
(`probed`), the first error stands. Otherwise `replay` runs from that
state, and its error, if it has one, is reported; else the first error
stands. The first error stands too when it is found as the program is
typed, and `replay`'s is one of ownership, which the compiler reports
later (#96), or is found as the program is typed too. -/
def bridged {α : Type} (check : CheckM α) (replay : Option (CheckM α)) : CheckM α :=
  match replay with
  | none => check
  | some replay =>
    tryCatch check fun err => do
      let s0 ← get
      set { s0 with probe := true, swallowed := 0 }
      let probe ← tryCatch (do let _ ← check; pure (some (← get).swallowed)) fun _ => pure none
      set s0
      if probe == some 1 then throw err
      let replayed ← tryCatch (do let _ ← replay; pure err) pure
      throw (if err.typed && (replayed.owned || replayed.typed) then err else replayed)

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
def checkCond (prog : Program) (c : Expr) (c' : Option Expr) : CheckM Unit := do
  expect .bool (← bridged (checkExpr prog c) (c'.map (checkExpr prog.asMain)))

mutual
/-- Checks the statement `s` of the function `sig`, whose twin, the
statement that `main`'s inference gave, is `m`. A statement that holds no
block is checked by `checkSimple`, bridged to `main`'s order
(`bridged`); an `if` and a loop bridge their conditions, and check their
blocks beside their twins. -/
def checkStmt (prog : Program) (sig : FunDecl) (s : Stmt) (m : Option Stmt) : CheckM Unit :=
  match s with
  | .ifElse c thenBlock elseBlock => do
    let (c', t', e') := twinIf m
    checkCond prog c c'
    let s0 ← get
    checkScope prog sig thenBlock t'
    let s1 ← get
    set s0
    checkScope prog sig elseBlock e'
    set (joinStates s1 (← get))
  | .whileLoop c body => do
    let (c', b') := twinWhile m
    checkCond prog c c'
    let s0 ← get
    checkScope prog sig body b'
    let s1 ← get
    checkLoop s0 s1
    let head := if s1.live then { s0 with vars := List.zipWith joinMay s0.vars s1.vars,
                                          stale := union s0.stale s1.stale } else s0
    if head != s0 then
      set head
      checkCond prog c c'
      checkScope prog sig body b'
      let s2 ← get
      set (if s2.live then { head with vars := List.zipWith joinMay head.vars s2.vars } else head)
    else set head
  | s => bridged (checkSimple prog sig s) (m.map (checkSimple prog.asMain sig))

/-- Checks the block `b` as a scope of its own, beside its twin `ms`. -/
def checkScope (prog : Program) (sig : FunDecl) (b ms : List Stmt) :
    CheckM Unit := do
  let n := (← get).vars.length
  checkBlock prog sig b ms
  endScope prog n

/-- Checks the statements of a block in order, each beside its twin in
`ms`, the block that `main`'s inference gave, when it has one. -/
def checkBlock (prog : Program) (sig : FunDecl) : List Stmt → List Stmt → CheckM Unit
  | [], _ => pure ()
  | s :: rest, ms => do
    modify fun st => { st with changes := [] }
    checkStmt prog sig s ms.head?
    checkBlock prog sig rest ms.tail
end

end MojoGrimoire.Check
