import MojoGrimoire.Check.State

/-!
The uses, moves and liveness that ASAP elaboration needs.

Mojo destroys each value as soon as possible: right after its last use.
Elaboration finds those points with a liveness analysis that runs backwards
through each block. The unit it tracks is a slot: a variable, except in a
`__deinit__`, where each field of `self` is a slot of its own, since Mojo
destroys the fields of a value being destroyed one by one, each after its
own last use.

The checker forbids a declaration that hides a variable in scope, so a name
names one variable wherever it is used, and the analysis can track slots by
name.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- The slots of a function: `fieldwise` is `some fs` in a `__deinit__`,
where the fields `fs` of `self` are slots of their own, and `none`
elsewhere. -/
structure Slots where
  fieldwise : Option (List Name)
  deriving DecidableEq, Repr

/-- The slots that a use of the place `p` touches: the slot of its variable,
or, for `self` in a `__deinit__`, the slot of the field of `self` it is in,
or every field's slot for `self` itself. -/
def Slots.of (sl : Slots) (p : Place) : List Place :=
  match sl.fieldwise, splitPlace p with
  | some fs, ("self", []) => fs.map (.field (.var "self") ·)
  | some _, ("self", f :: _) => [.field (.var "self") f]
  | _, (x, _) => [.var x]

/-- Whether the place `p` is a whole slot, so that transferring it or
assigning to it moves or defines the slot. -/
def Slots.isSlot (sl : Slots) (p : Place) : Bool :=
  match sl.fieldwise, p with
  | some _, .var "self" => false
  | some _, .field (.var "self") _ => true
  | _, .var _ => true
  | _, _ => false

/-- The union of two lists of slots, as sets. -/
def union (a b : List Place) : List Place := a ++ b.filter (!a.contains ·)

/-- The slots of `a` that are not in `b`. -/
def diff (a b : List Place) : List Place := a.filter (!b.contains ·)

mutual
/-- The slots that the expression `e` uses. -/
def uses (sl : Slots) : Expr → List Place
  | .int _ | .bool _ | .str _ => []
  | .place p | .transfer p | .copy p => sl.of p
  | .call _ args => usesList sl args
  | .method p _ args => union (sl.of p) (usesList sl args)
  | .unary _ a => uses sl a
  | .binary _ a b => union (uses sl a) (uses sl b)

/-- The slots that the expressions `es` use. -/
def usesList (sl : Slots) : List Expr → List Place
  | [] => []
  | e :: es => union (uses sl e) (usesList sl es)
end

mutual
/-- The slots that the expression `e` moves away whole, with `p^` of a
whole slot. -/
def moves (sl : Slots) : Expr → List Place
  | .transfer p => if sl.isSlot p then [p] else []
  | .call _ args => movesList sl args
  | .method _ _ args => movesList sl args
  | .unary _ a => moves sl a
  | .binary _ a b => union (moves sl a) (moves sl b)
  | _ => []

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
before unless the value uses it. A loop's live slots are those of its
condition, those live after it, and those its body uses before defining
them; one pass through the body reaches that fixed point, since the body's
liveness only adds the slots it uses and keeps or removes the others. -/
def liveStmt (sl : Slots) (s : Stmt) (after : List Place) : List Place :=
  match s with
  | .pass | .drop _ => after
  | .decl x _ init => union (usesOpt sl init) (diff after [.var x])
  | .assign p e =>
    if sl.isSlot p then union (uses sl e) (diff after [p])
    else union (uses sl e) (union (sl.of p) after)
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

end MojoGrimoire.Elab
