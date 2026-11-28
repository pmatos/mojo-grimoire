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
(#96's Q2). The order from `main` is the compiler's at `-O3`, the
default. Where its order at `-O0` differs, the order is left undefined
(#324, #331): the model keeps `-O3`'s in a body, and `-O0`'s between a
literal and a constant index into an array in the arguments of `range`,
where it reports the literal first (`MojoGrimoire.Check.Fit`).
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
  | .temp _ e => exprDrops e
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

/-- The `drop` statements of the places `ps` but the hidden variables of
temporaries. -/
def keptDrops (ps : List Place) : List Stmt :=
  (ps.filter fun p => !isTempName (splitPlace p).1).map .drop

mutual
/-- The statement `s` of an elaborated body with its `drop` statements
kept and every `withDrops` erased. A value that a `withDrops` destroys
is destroyed by a `drop` statement after the statement, or, in a
condition, at the start of each block it leads to and after a loop. The
drops of the hidden variables of temporaries are left out, as their
declarations are (`stripStmt`). -/
def withDropStmt : Stmt → List Stmt
  | .drop p => keptDrops [p]
  | .ifElse c a b =>
    let ds := keptDrops (exprDrops c)
    [.ifElse (stripExpr c) (ds ++ withDropStmts a) (ds ++ withDropStmts b)]
  | .whileLoop c body =>
    let ds := keptDrops (exprDrops c)
    [.whileLoop (stripExpr c) (ds ++ withDropStmts body)] ++ ds
  | s => stripStmt s ++ keptDrops (stmtDrops s)

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
def checkInst (prog : Program) (strict : Bool) : Except Rejection Unit := do
  let bodies := declBodies (dropsProgram prog) strict .inst ++ synthesizedDestructors prog
  let fuel := bodies.length + 1
  let mut seen ← instantiate bodies fuel "main" []
  for (w, _) in bodies do
    seen ← instantiate bodies fuel w seen

/-- Checks a program: it is accepted, or rejected with the first error of
the type phase, or else of the flow phase, or else of the instantiation
phase, which the compiler reports in that order of tiers (`Phase`,
ADR-2026-11-21-1941). When `strict` holds, a temporary origin argument in
a place's index is rejected (`strictIndices`). -/
def checkProgramAs (prog : Program) (strict : Bool) : Except Rejection Unit := do
  checkFlow prog strict (← checkTypes prog strict)
  checkInst prog strict

mutual
/-- Whether the expression `e` calls a function or a method in the index of
a place, or anywhere when `inIndex` holds. -/
def indexCallIn (inIndex : Bool) : Expr → Bool
  | .int _ | .bool _ | .str _ => false
  | .place p | .transfer p | .copy p => indexCallAt p
  | .call _ args => inIndex || indexCallsIn inIndex args
  | .method p _ args => inIndex || indexCallAt p || indexCallsIn inIndex args
  | .unary _ a | .withDrops a _ _ | .temp _ a => indexCallIn inIndex a
  | .binary _ a b => indexCallIn inIndex a || indexCallIn inIndex b
  | .list _ es | .listInit _ es => indexCallsIn inIndex es

/-- Whether the expressions `es` call one so (`indexCallIn`). -/
def indexCallsIn (inIndex : Bool) : List Expr → Bool
  | [] => false
  | e :: es => indexCallIn inIndex e || indexCallsIn inIndex es

/-- Whether an index of the place `p` calls a function or a method. -/
def indexCallAt : Place → Bool
  | .var _ => false
  | .field p _ | .transferred p => indexCallAt p
  | .index p i => indexCallAt p || indexCallIn true i
end

mutual
/-- Whether the statement `s` calls a function or a method in the index of
a place (`indexCallIn`). -/
def indexCallStmt : Stmt → Bool
  | .pass | .ret none | .decl _ _ none => false
  | .decl _ _ (some e) | .refDecl _ e | .expr e | .ret (some e) => indexCallIn false e
  | .assign p e => indexCallAt p || indexCallIn false e
  | .print args => indexCallsIn false args
  | .ifElse c a b => indexCallIn false c || indexCallBlock a || indexCallBlock b
  | .whileLoop c body => indexCallIn false c || indexCallBlock body
  | .drop p => indexCallAt p

/-- Whether a statement of the block `b` does (`indexCallStmt`). -/
def indexCallBlock : List Stmt → Bool
  | [] => false
  | s :: rest => indexCallStmt s || indexCallBlock rest
end

/-- Whether a body of the program `prog` calls a function or a method in
the index of a place: only then can a temporary origin argument be in one. -/
def indexedCalls (prog : Program) : Bool :=
  let fn (fd : FunDecl) := indexCallBlock fd.body
  prog.funs.any fn || prog.structs.any fun sd =>
    sd.init.any fn || sd.deinit.any indexCallBlock || sd.methods.any fn

/-- Checks a program as `checkProgramAs` does, twice. The first time, a
temporary origin argument in a place's index is left out of the origins,
as anywhere else, so that a rejected program gets the compiler's first
error. A program that this accepts is checked again with every such
argument rejected, as before #80, since elaboration does not keep it
alive until it is read, and the model would read it destroyed (#377). The
second time is needed only when an index holds a call (`indexedCalls`). -/
def checkProgram (prog : Program) : Except Rejection Unit := do
  checkProgramAs prog false
  if indexedCalls prog then checkProgramAs prog true

end MojoGrimoire.Check
