import MojoGrimoire.Check.State

/-!
The uses, moves and liveness that ASAP elaboration needs.

Mojo destroys each value as soon as possible: right after its last use.
Elaboration finds those points with a liveness analysis that runs backwards
through each block. The unit it tracks is a slot: a variable, except in a
`__deinit__`, where each field of `self` is a slot of its own, since Mojo
destroys the fields of a value being destroyed one by one, each after its
own last use. A reference bound with `ref` is no slot: a use of it is a use
of every slot it may point into.

The checker forbids a declaration that hides a variable in scope, so a name
names one variable wherever it is used, and the analysis can track slots by
name. A simple statement uses, moves and defines slots as its parts do,
and the slots that die right after it follow from them (`dying`). Only
values of struct type, and lists and arrays of them, are dropped
(`needsDrop`), each by a `drop` statement (`drops`).
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- The slots of a function: `fieldwise` is `some fs` in a `__deinit__`,
where the fields `fs` of `self` are slots of their own, and `none`
elsewhere. `aliases` maps each reference bound with `ref` to the slots it
may point into. -/
structure Slots where
  fieldwise : Option (List Name)
  aliases : List (Name × List Place)

/-- The slots that a use of the place `p` touches: the slot of its variable,
or, for `self` in a `__deinit__`, the slot of the field of `self` it is in,
or every field's slot for `self` itself. A use through a reference touches
every slot it may point into, so that they live as long as it is used. -/
def Slots.of (sl : Slots) (p : Place) : List Place :=
  match sl.aliases.lookup (splitPlace p).1 with
  | some os => os
  | none =>
    match sl.fieldwise, splitPlace p with
    | some fs, ("self", []) => fs.map (.field (.var "self") ·)
    | some _, ("self", f :: _) => [.field (.var "self") f]
    | _, (x, _) => [.var x]

/-- Whether the place `p` is a whole slot, so that transferring it or
assigning to it moves or defines the slot. A reference is not a slot:
assigning to it writes through it. -/
def Slots.isSlot (sl : Slots) (p : Place) : Bool :=
  if (sl.aliases.lookup (splitPlace p).1).isSome then false else
  match sl.fieldwise, p with
  | some _, .var "self" => false
  | some _, .field (.var "self") _ => true
  | _, .var _ => true
  | _, _ => false

/-- The slots of `a` that are not in `b`. -/
def diff (a b : List Place) : List Place := a.filter (!b.contains ·)

mutual
/-- The slots that the index expressions of the place `p` use. -/
def indexUses (sl : Slots) : Place → List Place
  | .var _ => []
  | .field p _ => indexUses sl p
  | .index p i => union (indexUses sl p) (uses sl i)
  | .transferred p => indexUses sl p

/-- The slots that the expression `e` uses. A place uses its own slot and
those its index expressions use; a temporary its hidden variable too. -/
def uses (sl : Slots) : Expr → List Place
  | .int _ | .bool _ | .str _ => []
  | .place p | .transfer p | .copy p => union (sl.of p) (indexUses sl p)
  | .call _ args => usesList sl args
  | .method p _ args => union (union (sl.of p) (indexUses sl p)) (usesList sl args)
  | .unary _ a => uses sl a
  | .binary _ a b => union (uses sl a) (uses sl b)
  | .list _ es | .listInit _ es => usesList sl es
  | .withDrops e _ _ => uses sl e
  | .temp x e => union (sl.of (.var x)) (uses sl e)

/-- The slots that the expressions `es` use. -/
def usesList (sl : Slots) : List Expr → List Place
  | [] => []
  | e :: es => union (uses sl e) (usesList sl es)
end

mutual
/-- The slots that the index expressions of the place `p` move away. -/
def indexMoves (sl : Slots) : Place → List Place
  | .var _ => []
  | .field p _ => indexMoves sl p
  | .index p i => union (indexMoves sl p) (moves sl i)
  | .transferred p => indexMoves sl p

/-- The slots that the expression `e` moves away whole, with `p^` of a
whole slot. -/
def moves (sl : Slots) : Expr → List Place
  | .int _ | .bool _ | .str _ => []
  | .transfer p => union (if sl.isSlot p then [p] else []) (indexMoves sl p)
  | .place p | .copy p => indexMoves sl p
  | .call _ args => movesList sl args
  | .method p _ args => union (indexMoves sl p) (movesList sl args)
  | .unary _ a => moves sl a
  | .binary _ a b => union (moves sl a) (moves sl b)
  | .list _ es | .listInit _ es => movesList sl es
  | .withDrops e _ _ | .temp _ e => moves sl e

/-- The slots that the expressions `es` move away whole. -/
def movesList (sl : Slots) : List Expr → List Place
  | [] => []
  | e :: es => union (moves sl e) (movesList sl es)
end

/-- The slots that an optional expression uses. -/
def usesOpt (sl : Slots) : Option Expr → List Place
  | some e => uses sl e
  | none => []

mutual
/-- The slots live before the statement `s`, given those live after it. A
declaration or an assignment to a whole slot defines it, so it is not live
before unless the value uses it. A `ref` binding uses what it binds to. A loop's live slots are those of its
condition, those live after it, and those its body uses before defining
them; one pass through the body reaches that fixed point, since the body's
liveness only adds the slots it uses and keeps or removes the others. -/
def liveStmt (sl : Slots) (s : Stmt) (after : List Place) : List Place :=
  match s with
  | .pass | .drop _ => after
  | .decl x _ init => union (usesOpt sl init) (diff after [.var x])
  | .refDecl _ e => union (uses sl e) after
  | .assign p e =>
    if sl.isSlot p then union (uses sl e) (diff after [p])
    else union (uses sl e) (union (union (sl.of p) (indexUses sl p)) after)
  | .expr e => union (uses sl e) after
  | .print args => union (usesList sl args) after
  | .ifElse c a b =>
    union (uses sl c) (union (liveBlock sl a after) (liveBlock sl b after))
  | .whileLoop c body =>
    let start := union (uses sl c) after
    union start (liveBlock sl body start)
  | .ret value => usesOpt sl value

/-- The slots live before the block `b`, given those live after it. -/
def liveBlock (sl : Slots) (b : List Stmt) (after : List Place) : List Place :=
  match b with
  | [] => after
  | s :: rest => liveStmt sl s (liveBlock sl rest after)
end

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
  | .refDecl _ e => uses sl e
  | .assign p e =>
    if sl.isSlot p then uses sl e else union (uses sl e) (union (sl.of p) (indexUses sl p))
  | .expr e => uses sl e
  | .print args => usesList sl args
  | _ => []

/-- The slots that the simple statement `s` moves away whole. -/
def movesStmt (sl : Slots) : Stmt → List Place
  | .decl _ _ (some e) | .refDecl _ e | .expr e => moves sl e
  | .assign p e => union (moves sl e) (indexMoves sl p)
  | .print args => movesList sl args
  | _ => []

/-- The slots that die right after the simple statement `s`, given the
slots `gone` that its expressions destroy or consume, and the slots `after`
live after it: those it uses but neither moves away nor leaves in `gone`,
and those it defines, unless they are live. `gone` holds values that die
before `s` defines anything, so it never holds the value that `s` defines,
even when an assignment destroys or consumes the old value of the slot it
assigns. -/
def dying (sl : Slots) (s : Stmt) (gone after : List Place) : List Place :=
  diff (union (diff (usesStmt sl s) (union (movesStmt sl s) gone)) (defs sl s)) after

/-- Whether a value of type `t` is dropped: one of struct type, or a list
or an array of them. -/
def needsDrop : Ty → Bool
  | .struct _ => true
  | .list t | .array t _ => needsDrop t
  | _ => false

/-- The statements that drop the slots of `d`, in the order of `owned`, the
slots a function owns, in the order they die when several die at once. A
slot that the function does not own, such as a borrowed parameter, is never
dropped. -/
def drops (owned d : List Place) : List Stmt :=
  (owned.filter (d.contains ·)).map .drop

mutual
/-- The local variables whose values are dropped that the statement `s`
declares, in order, each once. -/
def declared : Stmt → List Place
  | .decl x t _ => if needsDrop t then [.var x] else []
  | .ifElse _ a b => union (declaredBlock a) (declaredBlock b)
  | .whileLoop _ body => declaredBlock body
  | _ => []

/-- The local variables whose values are dropped that the block `b`
declares, in order, each once. -/
def declaredBlock : List Stmt → List Place
  | [] => []
  | s :: rest => union (declared s) (declaredBlock rest)
end

end MojoGrimoire.Elab
