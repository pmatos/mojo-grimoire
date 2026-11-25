import MojoGrimoire.Check.Program
import MojoGrimoire.Elab.Strip

/-!
The instantiation phase, and the checking of whole programs in the
compiler's three tiers (#96 part 7, ADR-2026-11-21-1941).

The compiler instantiates the functions from `main`, after its pass
manager has checked every body, and reports the first that fails: a
literal of `Int`s of the wrong length, or a constant index out of an
array's or an `Int`'s range, in a body, in the order of the body, and
then each of its calls, the last first, depth first. A negative constant
index of a list fails as a call does, and the destructor of a value is
called where the value is destroyed: the elaborated body's `drop`
statements show where (`MojoGrimoire.Elab.elabProgram`), which the
model keeps among the body's own statements (`withDropStmts`). A value
destroyed inside an expression, a temporary, is not followed yet. A body is instantiated once. The
bodies that `main` does not reach are then checked in the order of the
declarations, as the model does not yet accept them as the compiler does
(#96's Q2). Where the compiler's order at `-O0` differs, the model keeps
its order at `-O3` (#324).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core MojoGrimoire.Elab

mutual
/-- The statement `s` of an elaborated body with its `drop` statements
kept and every `withDrops` erased. -/
def withDropStmt : Stmt → List Stmt
  | .drop p => [.drop p]
  | .ifElse c a b => [.ifElse (stripExpr c) (withDropStmts a) (withDropStmts b)]
  | .whileLoop c body => [.whileLoop (stripExpr c) (withDropStmts body)]
  | s => stripStmt s

/-- The block `b` of an elaborated body with its `drop` statements kept
and every `withDrops` erased (`withDropStmt`). -/
def withDropStmts : List Stmt → List Stmt
  | [] => []
  | s :: rest => withDropStmt s ++ withDropStmts rest
end

/-- The program `prog` elaborated, with the `drop` statements of its
bodies kept and every `withDrops` erased: its own statements, and where
each value is destroyed. -/
def dropsProgram (prog : Program) : Program :=
  let e := elabProgram prog
  let fn (fd : FunDecl) : FunDecl := { fd with body := withDropStmts fd.body }
  { e with
    funs := e.funs.map fn
    structs := e.structs.map fun sd =>
      { sd with init := sd.init.map fn, deinit := sd.deinit.map withDropStmts,
                methods := sd.methods.map fn } }

/-- Instantiates the body `w` and, depth first, the bodies it calls, the
last call first, unless `visited` holds it, given `bodies`, each with its
check in the instantiation phase; `fuel` bounds the depth. It gives the
bodies visited, or the first error found, located at its body. -/
def instantiate (bodies : List (Name × (Stage → Except CheckError BodyResult))) :
    Nat → Name → List Name → Except Rejection (List Name)
  | 0, _, visited => pure visited
  | n + 1, w, visited => do
    if visited.contains w then return visited
    let some (_, check) := bodies.find? (·.1 == w) | return visited
    let (_, events) ← (check .ends).mapError (⟨w, ·⟩)
    let mut seen := w :: visited
    for e in events.reverse do
      match e with
      | .fail err => throw ⟨w, err⟩
      | .call c => seen ← instantiate bodies n c seen
    pure seen

/-- Checks a program in the instantiation phase, on a program that the
type and flow phases accept: from `main`, then the bodies that it does not
reach, in the order of the declarations (`instantiate`). -/
def checkInst (prog : Program) : Except Rejection Unit := do
  let bodies := declBodies (dropsProgram prog) .inst
  let fuel := bodies.length + 1
  let mut seen ← instantiate bodies fuel "main" []
  for (w, _) in bodies do
    seen ← instantiate bodies fuel w seen

/-- Checks a program: it is accepted, or rejected with the first error of
the type phase, or else of the flow phase, or else of the instantiation
phase, which the compiler reports in that order of tiers (`Phase`,
ADR-2026-11-21-1941). -/
def checkProgram (prog : Program) : Except Rejection Unit := do
  checkFlow prog (← checkTypes prog)
  checkInst prog

end MojoGrimoire.Check
