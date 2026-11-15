import MojoGrimoire.Elab.Elaborate

/-!
Elaboration only inserts drops: erasing every `drop` from an elaborated
program gives the program it elaborated, with its drops erased too. So
elaboration changes when values are destroyed, and nothing else.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core

mutual
/-- The statement `s` with every `drop` in it erased. -/
def stripStmt : Stmt → List Stmt
  | .drop _ => []
  | .ifElse c a b => [.ifElse c (stripBlock a) (stripBlock b)]
  | .whileLoop c body => [.whileLoop c (stripBlock body)]
  | .pass => [.pass]
  | .decl x t init => [.decl x t init]
  | .assign p e => [.assign p e]
  | .expr e => [.expr e]
  | .print args => [.print args]
  | .ret value => [.ret value]

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

mutual
/-- Elaborating a statement only inserts drops. -/
theorem stripBlock_elabStmt (sl : Slots) (owned : List Place) (s : Stmt)
    (after : List Place) : stripBlock (elabStmt sl owned s after) = stripStmt s := by
  match s with
  | .ifElse c a b =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_append, stripBlock_drops,
      stripBlock_elabBlock]
  | .whileLoop c body =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_drops, stripBlock_elabBlock]
  | .ret _ | .pass | .drop _ => simp [elabStmt, stripBlock, stripStmt]
  | .decl .. | .assign .. | .expr _ | .print _ =>
    simp [elabStmt, stripBlock, stripStmt, stripBlock_drops]

/-- Elaborating a block only inserts drops. -/
theorem stripBlock_elabBlock (sl : Slots) (owned : List Place) (b : List Stmt)
    (after : List Place) : stripBlock (elabBlock sl owned b after) = stripBlock b := by
  match b with
  | [] => simp [elabBlock, stripBlock]
  | s :: rest =>
    simp [elabBlock, stripBlock, stripBlock_append, stripBlock_elabStmt,
      stripBlock_elabBlock sl owned rest after]
end

/-- Elaborating a function body only inserts drops. -/
theorem stripBlock_elabBody (sl : Slots) (params : List Place) (body : List Stmt) :
    stripBlock (elabBody sl params body) = stripBlock body := by
  simp [elabBody, stripBlock_append, stripBlock_drops, stripBlock_elabBlock]

/-- Elaboration only inserts drops: a program and its elaboration are the
same once their drops are erased. -/
theorem stripProgram_elabProgram (prog : Program) :
    stripProgram (elabProgram prog) = stripProgram prog := by
  have hf : ∀ fd : FunDecl, stripFun (elabFun fd) = stripFun fd := by
    intro fd
    simp [stripFun, elabFun, stripBlock_elabBody]
  have hs : ∀ sd : StructDecl, stripStruct (elabStruct sd) = stripStruct sd := by
    intro sd
    cases sd
    simp [stripStruct, elabStruct, elabDeinit, stripBlock_elabBody, Option.map_map,
      Function.comp_def, hf]
  simp [stripProgram, elabProgram, Function.comp_def, hf, hs]

end MojoGrimoire.Elab
