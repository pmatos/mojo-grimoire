import MojoGrimoire.Elab.Live

/-!
ASAP elaboration: the insertion of an explicit `drop` wherever Mojo destroys
a value.

Mojo destroys a value right after its last use. Elaboration makes those
points explicit, so that the interpreter only destroys what a `drop` names,
and what remains when a function returns. A value is destroyed:

- right after the statement that last uses it, or right after its
  declaration when nothing uses it;
- at the start of a branch of an `if` that does not use it, when the other
  branch does;
- right after a loop that uses it, since the next iteration might use it;
- at the start of a function body, for a `var` parameter the body never
  uses.

A value moved away with `^` is not destroyed: its new owner destroys it.
Inside `__deinit__(deinit self)`, each field of `self` is destroyed on its own,
at the same points, so a field the body never uses is destroyed before the
body runs.

Only values of struct type, and lists of them, are dropped: values of the
other types of the core calculus have no destruction that can be observed. Several values destroyed
at the same point are destroyed in the order of their declaration, parameters
first.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- Whether a value of type `t` is dropped: one of struct type, or a list
of them. -/
def needsDrop : Ty → Bool
  | .struct _ => true
  | .list t => needsDrop t
  | _ => false

/-- The statements that drop the slots of `d`, in the order of `owned`, the
slots a function owns. A slot that the function does not own, such as a
borrowed parameter, is never dropped. -/
def drops (owned d : List Place) : List Stmt :=
  (owned.filter (d.contains ·)).map .drop

/-- The slots that the simple statement `s` defines: a declaration with an
initial value, or an assignment to a whole slot. -/
def defs (sl : Slots) : Stmt → List Place
  | .decl x _ (some _) => [.var x]
  | .assign p _ => if sl.isSlot p then [p] else []
  | _ => []

/-- The slots that the simple statement `s` uses. An assignment to a part of
a slot uses the slot. -/
def usesStmt (sl : Slots) : Stmt → List Place
  | .decl _ _ init => usesOpt sl init
  | .assign p e =>
    if sl.isSlot p then uses sl e else union (uses sl e) (union (sl.of p) (indexUses sl p))
  | .expr e => uses sl e
  | .print args => usesList sl args
  | _ => []

/-- The slots that the simple statement `s` moves away whole. -/
def movesStmt (sl : Slots) : Stmt → List Place
  | .decl _ _ (some e) | .expr e => moves sl e
  | .assign p e => union (moves sl e) (indexMoves sl p)
  | .print args => movesList sl args
  | _ => []

/-- The slots dead after the simple statement `s`, given the slots `after`
live after it: those it uses but does not move away, and those it defines,
unless they are live. -/
def dying (sl : Slots) (s : Stmt) (after : List Place) : List Place :=
  diff (union (diff (usesStmt sl s) (movesStmt sl s)) (defs sl s)) after

mutual
/-- The local variables of struct type that the statement `s` declares,
in order, each once. -/
def declared : Stmt → List Place
  | .decl x t _ => if needsDrop t then [.var x] else []
  | .ifElse _ a b => union (declaredBlock a) (declaredBlock b)
  | .whileLoop _ body => declaredBlock body
  | _ => []

/-- The local variables of struct type that the block `b` declares, in
order, each once. -/
def declaredBlock : List Stmt → List Place
  | [] => []
  | s :: rest => union (declared s) (declaredBlock rest)
end

mutual
/-- Elaborates the statement `s`, given the slots live after it. `owned` is
the slots that the function owns. -/
def elabStmt (sl : Slots) (owned : List Place) (s : Stmt) (after : List Place) :
    List Stmt :=
  match s with
  | .ifElse c a b =>
    let avail := diff (liveStmt sl (.ifElse c a b) after) (moves sl c)
    [.ifElse c
      (drops owned (diff avail (liveBlock sl a after)) ++ elabBlock sl owned a after)
      (drops owned (diff avail (liveBlock sl b after)) ++ elabBlock sl owned b after)]
  | .whileLoop c body =>
    let head := liveStmt sl (.whileLoop c body) after
    .whileLoop c (elabBlock sl owned body head) :: drops owned (diff head after)
  | .ret value => [.ret value]
  | .pass => [.pass]
  | .drop p => [.drop p]
  | .decl x t init => .decl x t init :: drops owned (dying sl (.decl x t init) after)
  | .assign p e => .assign p e :: drops owned (dying sl (.assign p e) after)
  | .expr e => .expr e :: drops owned (dying sl (.expr e) after)
  | .print args => .print args :: drops owned (dying sl (.print args) after)

/-- Elaborates the block `b`, given the slots live after it. -/
def elabBlock (sl : Slots) (owned : List Place) (b : List Stmt) (after : List Place) :
    List Stmt :=
  match b with
  | [] => []
  | s :: rest => elabStmt sl owned s (liveBlock sl rest after) ++ elabBlock sl owned rest after
end

/-- Elaborates a function body. `params` is the slots the function owns on
entry; those the body never uses are dropped before it runs. -/
def elabBody (sl : Slots) (params : List Place) (body : List Stmt) : List Stmt :=
  let owned := union params (declaredBlock body)
  drops owned (diff params (liveBlock sl body [])) ++ elabBlock sl owned body []

/-- The slots of the `var` parameters of struct type among `params`. -/
def ownedParams (params : List Param) : List Place :=
  (params.filter fun prm => prm.conv == .owned && needsDrop prm.ty).map (.var ·.name)

/-- Elaborates a function, a method or an initializer. -/
def elabFun (fd : FunDecl) : FunDecl :=
  { fd with body := elabBody ⟨none⟩ (ownedParams fd.params) fd.body }

/-- Elaborates the body of the `__deinit__` of a struct with the fields
`fields`: each field of struct type is a slot of its own. -/
def elabDeinit (fields : List (Name × Ty)) (body : List Stmt) : List Stmt :=
  elabBody ⟨some (fields.map (·.1))⟩
    ((fields.filter (needsDrop ·.2)).map (.field (.var "self") ·.1)) body

/-- Elaborates a struct: its initializer, destructor and methods. -/
def elabStruct (sd : StructDecl) : StructDecl :=
  { sd with
    init := sd.init.map elabFun
    deinit := sd.deinit.map (elabDeinit sd.fields)
    methods := sd.methods.map elabFun }

/-- Elaborates a program. It expects a program that the checker accepts and
that holds no `drop`. -/
def elabProgram (prog : Program) : Program :=
  ⟨prog.structs.map elabStruct, prog.funs.map elabFun⟩

end MojoGrimoire.Elab
