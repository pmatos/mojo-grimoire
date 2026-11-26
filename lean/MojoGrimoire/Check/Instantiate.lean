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
called where the value is destroyed, the one that the struct declares or
else the one that the compiler synthesizes for its fields, and a list's
or an array's calls its elements': the elaborated body's `drop`
statements show where (`MojoGrimoire.Elab.elabProgram`), which the
model keeps among the body's own statements, with a value that an
expression destroys destroyed after its statement (`withDropStmts`). A body is instantiated once. The
bodies that `main` does not reach are then checked in the order of the
declarations, as the model does not yet accept them as the compiler does
(#96's Q2). Where the compiler's order at `-O0` differs, the model keeps
its order at `-O3` (#324).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core MojoGrimoire.Elab

mutual
/-- The places that the `withDrops` in the place `p` destroy, in order. -/
def placeDrops : Place → List Place
  | .var _ => []
  | .field p _ => placeDrops p
  | .index p i => placeDrops p ++ exprDrops i
  | .transferred p => placeDrops p

/-- The places that the `withDrops` in the expression `e` destroy, in the
order in which elaboration destroys them: an operation's operands' first,
then those destroyed before it is performed, then after. -/
def exprDrops : Expr → List Place
  | .place p | .transfer p | .copy p => placeDrops p
  | .call _ args | .list _ args | .listInit _ args => exprsDrops args
  | .method p _ args => placeDrops p ++ exprsDrops args
  | .unary _ a => exprDrops a
  | .binary _ a b => exprDrops a ++ exprDrops b
  | .withDrops e pre post => exprDrops e ++ pre ++ post
  | .int _ | .bool _ | .str _ => []

/-- The places that the `withDrops` in the expressions `es` destroy. -/
def exprsDrops : List Expr → List Place
  | [] => []
  | e :: es => exprDrops e ++ exprsDrops es
end

/-- The places that the `withDrops` in the simple statement `s` destroy. -/
def stmtDrops : Stmt → List Place
  | .decl _ _ (some e) | .refDecl _ e | .expr e | .ret (some e) => exprDrops e
  | .assign p e => placeDrops p ++ exprDrops e
  | .print args => exprsDrops args
  | _ => []

mutual
/-- The statement `s` of an elaborated body with its `drop` statements
kept and every `withDrops` erased. A value that a `withDrops` destroys
is destroyed by a `drop` statement after the statement, or, in a
condition, at the start of each block it leads to and after a loop. -/
def withDropStmt : Stmt → List Stmt
  | .drop p => [.drop p]
  | .ifElse c a b =>
    let ds := (exprDrops c).map .drop
    [.ifElse (stripExpr c) (ds ++ withDropStmts a) (ds ++ withDropStmts b)]
  | .whileLoop c body =>
    let ds := (exprDrops c).map .drop
    [.whileLoop (stripExpr c) (ds ++ withDropStmts body)] ++ ds
  | s => stripStmt s ++ (stmtDrops s).map .drop

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

/-- The destructors that the compiler synthesizes, `S.__del__`, for each
struct `S` that declares no `__deinit__`: each destroys the fields, which
calls their destructors (`destructorOf`). -/
def synthesizedDestructors (prog : Program) :
    List (Name × (Stage → Except CheckError BodyResult)) :=
  prog.structs.filterMap fun sd =>
    if sd.deinit.isSome then none
    else some (methodCallee sd.name "__del__", fun _ =>
      pure (none, (sd.fields.filterMap fun (_, t) => (destructorOf prog t).map .call).reverse))

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
    for e in events do
      match e with
      | .fail err => throw ⟨w, err⟩
      | .call c => seen ← instantiate bodies n c seen
    pure seen

/-- Checks a program in the instantiation phase, on a program that the
type and flow phases accept: from `main`, then the bodies that it does not
reach, in the order of the declarations (`instantiate`). -/
def checkInst (prog : Program) : Except Rejection Unit := do
  let bodies := declBodies (dropsProgram prog) .inst ++ synthesizedDestructors prog
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
