import MojoGrimoire.Elab.Elaborate

/-!
Elaboration only inserts drops: erasing every `drop` statement and every
`withDrops` from an elaborated program gives the program it elaborated,
with its drops erased too. So elaboration changes when values are
destroyed, and nothing else.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core

mutual
/-- The place `p` with every `withDrops` in its indices erased. -/
def stripPlace : Place → Place
  | .var x => .var x
  | .field p f => .field (stripPlace p) f
  | .index p i => .index (stripPlace p) (stripExpr i)
  | .transferred p => .transferred (stripPlace p)

/-- The expression `e` with every `withDrops` in it erased. -/
def stripExpr : Expr → Expr
  | .int k => .int k
  | .bool b => .bool b
  | .str t => .str t
  | .place p => .place (stripPlace p)
  | .transfer p => .transfer (stripPlace p)
  | .copy p => .copy (stripPlace p)
  | .call f args => .call f (stripExprs args)
  | .method p m args => .method (stripPlace p) m (stripExprs args)
  | .unary op a => .unary op (stripExpr a)
  | .binary op a b => .binary op (stripExpr a) (stripExpr b)
  | .list t es => .list t (stripExprs es)
  | .listInit u es => .listInit u (stripExprs es)
  | .withDrops e _ _ => stripExpr e

/-- The expressions `es` with every `withDrops` in them erased. -/
def stripExprs : List Expr → List Expr
  | [] => []
  | e :: es => stripExpr e :: stripExprs es
end

mutual
/-- The statement `s` with every `drop` and `withDrops` in it erased. -/
def stripStmt : Stmt → List Stmt
  | .drop _ => []
  | .ifElse c a b => [.ifElse (stripExpr c) (stripBlock a) (stripBlock b)]
  | .whileLoop c body => [.whileLoop (stripExpr c) (stripBlock body)]
  | .pass => [.pass]
  | .decl x t init => [.decl x t (init.map stripExpr)]
  | .refDecl x e => [.refDecl x (stripExpr e)]
  | .assign p e => [.assign (stripPlace p) (stripExpr e)]
  | .expr e => [.expr (stripExpr e)]
  | .print args => [.print (stripExprs args)]
  | .ret value => [.ret (value.map stripExpr)]

/-- The block `b` with every `drop` in it erased. -/
def stripBlock : List Stmt → List Stmt
  | [] => []
  | s :: rest => stripStmt s ++ stripBlock rest
end

/-- A function with every `drop` erased from its body. -/
def stripFun (fd : FunDecl) : FunDecl := { fd with body := stripBlock fd.body }

/-- A struct with every `drop` erased from its methods. -/
def stripStruct (sd : StructDecl) : StructDecl :=
  { sd with
    init := sd.init.map stripFun
    deinit := sd.deinit.map stripBlock
    methods := sd.methods.map stripFun }

/-- A program with every `drop` erased. -/
def stripProgram (prog : Program) : Program :=
  ⟨prog.structs.map stripStruct, prog.funs.map stripFun⟩

/-- Erasing drops distributes over the concatenation of blocks. -/
theorem stripBlock_append (a b : List Stmt) :
    stripBlock (a ++ b) = stripBlock a ++ stripBlock b := by
  induction a with
  | nil => rfl
  | cons s rest ih => simp [stripBlock, ih]

/-- Dropped slots erase to nothing. -/
theorem stripBlock_drops (owned d : List Place) : stripBlock (drops owned d) = [] := by
  unfold drops
  induction owned.filter (d.contains ·) with
  | nil => rfl
  | cons p rest ih => simp [stripBlock, stripStmt, ih]

/-- Erasing the drops of an operation leaves the operation. -/
theorem stripExpr_withDropsOf (e : Expr) (pre post : List Place) :
    stripExpr (withDropsOf e pre post) = stripExpr e := by
  unfold withDropsOf
  split <;> simp [stripExpr]

mutual
/-- Elaborating an expression only inserts drops. -/
theorem stripExpr_elabExpr (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) :
    stripExpr (elabExpr ctx top e after) = stripExpr e := by
  match e with
  | .call f args => simp [elabExpr, stripExpr_withDropsOf, stripExpr, stripExprs_elabOps]
  | .method p m args =>
    simp [elabExpr, stripExpr_withDropsOf, stripExpr, stripExprs_elabOps]
  | .binary op a b =>
    simp only [elabExpr]
    split <;> simp [stripExpr_withDropsOf, stripExpr, stripExpr_elabExpr]
  | .unary op a => simp [elabExpr, stripExpr_withDropsOf, stripExpr, stripExpr_elabExpr]
  | .list t es => simp [elabExpr, stripExpr_withDropsOf, stripExpr, stripExprs_elabOps]
  | .listInit u es => simp [elabExpr, stripExpr_withDropsOf, stripExpr, stripExprs_elabOps]
  | .copy p => simp [elabExpr, stripExpr_withDropsOf]
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .withDrops .. =>
    simp [elabExpr]

/-- Elaborating operands only inserts drops. -/
theorem stripExprs_elabOps (ctx : Ctx) (es : List Expr) (after : List Place) :
    stripExprs (elabOps ctx es after) = stripExprs es := by
  match es with
  | [] => simp [elabOps, stripExprs]
  | e :: rest =>
    simp [elabOps, stripExprs, stripExpr_elabExpr, stripExprs_elabOps ctx rest after]
end

/-- Elaborating the value of a `return` only inserts drops. -/
theorem stripExpr_elabReturn (ctx : Ctx) (e : Expr) :
    stripExpr (elabReturn ctx e) = stripExpr e := by
  unfold elabReturn
  split
  · rfl
  · split <;> simp [stripExpr, stripExpr_elabExpr]

mutual
/-- Elaborating a statement only inserts drops. -/
theorem stripBlock_elabStmt (ctx : Ctx) (s : Stmt) (after : List Place) :
    stripBlock (elabStmt ctx s after) = stripStmt s := by
  match s with
  | .ifElse c a b =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_append, stripBlock_drops,
      stripBlock_elabBlock, stripExpr_elabExpr]
  | .whileLoop c body =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_drops, stripBlock_elabBlock]
  | .ret value =>
    cases value <;> simp [elabStmt, stripBlock, stripStmt, stripExpr_elabReturn]
  | .pass | .drop _ => simp [elabStmt, stripBlock, stripStmt]
  | .decl x t init =>
    cases init <;> simp [elabStmt, stripBlock, stripStmt, stripBlock_drops, stripExpr_elabExpr]
  | .refDecl .. | .assign .. | .expr _ =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_drops, stripExpr_elabExpr]
  | .print _ =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_drops, stripExprs_elabOps]

/-- Elaborating a block only inserts drops. -/
theorem stripBlock_elabBlock (ctx : Ctx) (b : List Stmt) (after : List Place) :
    stripBlock (elabBlock ctx b after) = stripBlock b := by
  match b with
  | [] => simp [elabBlock, stripBlock]
  | s :: rest =>
    simp [elabBlock, stripBlock, stripBlock_append, stripBlock_elabStmt,
      stripBlock_elabBlock _ rest after]
end

/-- Elaborating a function body only inserts drops. -/
theorem stripBlock_elabBody (prog : Program) (sl : Slots) (env : TyEnv) (params : List Place)
    (body : List Stmt) : stripBlock (elabBody prog sl env params body) = stripBlock body := by
  simp [elabBody, stripBlock_append, stripBlock_drops, stripBlock_elabBlock]

/-- Elaboration only inserts drops: a program and its elaboration are the
same once their drops are erased. -/
theorem stripProgram_elabProgram (prog : Program) :
    stripProgram (elabProgram prog) = stripProgram prog := by
  have hf : ∀ fd : FunDecl, stripFun (elabFun prog fd) = stripFun fd := by
    intro fd
    simp [stripFun, elabFun, stripBlock_elabBody]
  have hs : ∀ sd : StructDecl, stripStruct (elabStruct prog sd) = stripStruct sd := by
    intro sd
    cases sd
    simp [stripStruct, elabStruct, elabDeinit, stripBlock_elabBody, Option.map_map,
      Function.comp_def, hf]
  simp [stripProgram, elabProgram, Function.comp_def, hf, hs]

end MojoGrimoire.Elab
