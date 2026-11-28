import MojoGrimoire.Elab.Operands

/-!
The elaboration of the operations of an expression: the drops that each
call, method call, operator, list literal, `List[u](e)` and `.copy()`
makes, given the slots live once it is evaluated, and those of a subscript
that Mojo reads late (`MojoGrimoire.Elab.Late`). `MojoGrimoire.Elab.Elaborate`
elaborates the statements that hold them.

Elaboration returns, with each elaborated expression, the slots that the
expression uses and those that the elaboration destroys. An operation reads
them from its operands instead of walking the operands again, so that a
right-nested chain of operators, such as `a and (b or (a and …))` or
`k + (k + …)`, is elaborated in time linear in its depth (#283).
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

mutual
/-- The slots that the elaborated expression `e` destroys. -/
def droppedIn : Expr → List Place
  | .withDrops e pre post => pre ++ post ++ droppedIn e
  | .call _ args | .method _ _ args | .list _ args | .listInit _ args => droppedList args
  | .binary _ a b => droppedIn a ++ droppedIn b
  | .unary _ a | .temp _ a => droppedIn a
  | _ => []

/-- The slots that the elaborated expressions `es` destroy. -/
def droppedList : List Expr → List Place
  | [] => []
  | e :: es => droppedIn e ++ droppedList es
end

/-- An elaboration, `out`, of an expression or of a list of operands, with
the slots that the input uses, `uses`, and those that `out` destroys,
`dropped`: `elabExpr_uses` and `elabExpr_dropped` show that they are
`uses` and `droppedIn`. -/
structure Elaborated (α : Type) where
  out : α
  uses : List Place
  dropped : List Place

/-- The elaborated operation `e`, which uses `u`, destroys `pre` once its
operands are read and `post` once it is done, and whose operands destroy
`inner`. -/
def Elaborated.op (e : Expr) (u pre post inner : List Place) : Elaborated Expr :=
  ⟨withDropsOf e pre post, u, pre ++ post ++ inner⟩

mutual
/-- Elaborates the expression `e`, given the slots live once it is
evaluated, `after`: each operation in it destroys the values whose last use
it is, and a place is left as it is, for the operation or the statement
that uses it. At the top of a statement, `top`, an operation leaves what
dies once it is done to the statement, which destroys it with the
statement's other values. The right operand of `and` and `or` may not run:
it destroys what it uses once it is read when it runs, and the operation
when it does not, before what the left one last uses, which dies once it
is tested (#191). Later operands are elaborated first, since what they use
is live after the earlier ones. -/
def elabExpr (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) : Elaborated Expr :=
  match e with
  | .call f args =>
    let d := opDrops ctx.owned (directArgs ctx args (callModes ctx.prog f)) after
    let r := elabOps ctx args d.2.2 []
    .op (.call f r.out) r.uses d.1 (if top then [] else d.2.1) r.dropped
  | .method p m args =>
    let ms := methodModes ctx.prog ctx.env p m args.length
    let d := opDrops ctx.owned (directOf ctx (.place p) ms.1 :: directArgs ctx args ms.2)
      after
    let gone := consumedSlot ctx p m args.length
    let r := elabOps ctx args d.2.2 []
    .op (.method p m r.out) (union (uses ctx.sl (.place p)) r.uses) (diff d.1 gone)
      (if top then [] else diff d.2.1 gone) r.dropped
  | .binary op a b =>
    if op == .and || op == .or then
      let a₀ := if isGetter ctx.prog a then locOperand ctx a true else directOf ctx a true
      let rb := elabExpr ctx false b (union after (opKeep ctx b))
      let d := opDrops ctx.owned [a₀, (rb.uses, false)] after
      let rest := diff d.2.1 rb.dropped
      let b' := if rest.isEmpty then rb.out else .withDrops (.withDrops rb.out [] []) [] rest
      let ra := elabExpr ctx false a d.2.2
      .op (.binary op ra.out b') (union ra.uses rb.uses) d.1 d.2.1
        (ra.dropped ++ (rest ++ rb.dropped))
    else
      let byVal := fun e => ((refSlots ctx.prog ctx.sl ctx.env e).2.bind (seqCompare op)).isNone
      let d := opDrops ctx.owned (directArgs ctx [a, b] [byVal a, byVal b]) after
      let late := lateValue ctx.prog
      let held := if isGetter ctx.prog a then placeUses ctx [a] else []
      let rb := if late b then elabLate ctx b d.2.2 held else elabExpr ctx false b (union d.2.2 held)
      let ra := if late a then
          elabLate ctx a (union d.2.2 (placeUses ctx ([b].filter (isGetter ctx.prog)))) rb.uses
        else elabExpr ctx false a (union d.2.2 rb.uses)
      .op (.binary op ra.out rb.out) (union ra.uses rb.uses) d.1 (if top then [] else d.2.1)
        (ra.dropped ++ rb.dropped)
  | .unary op a =>
    let d := opDrops ctx.owned (directArgs ctx [a] [true]) after
    let r := elabExpr ctx false a d.2.2
    .op (.unary op r.out) r.uses d.1 (if top then [] else d.2.1) r.dropped
  | .list t es =>
    if t == .int then
      let r := elabOps ctx es after []
      ⟨.list t r.out, r.uses, r.dropped⟩
    else
    let d := opDrops ctx.owned (directArgs ctx es (es.map fun _ => true)) after
    let r := elabOps ctx es d.2.2 []
    .op (.list t r.out) r.uses d.1 (if top then [] else d.2.1) r.dropped
  | .listInit u es =>
    let d := opDrops ctx.owned (directArgs ctx es []) after
    let r := elabOps ctx es d.2.2 []
    .op (.listInit u r.out) r.uses d.1 (if top then [] else d.2.1) r.dropped
  | .copy p =>
    let d := opDrops ctx.owned [directOf ctx (.place p) false] after
    .op (.copy p) (uses ctx.sl (.copy p)) d.1 (if top then [] else d.2.1) []
  | .temp x v =>
    let r := elabExpr ctx false v after
    ⟨.temp x r.out, union (ctx.sl.of (.var x)) r.uses, r.dropped⟩
  | e => ⟨e, uses ctx.sl e, droppedIn e⟩

/-- Elaborates the operands `es`, evaluated in order, given the slots live
once they are read, `after`, and those that the subscripts read late
before them use, `held`. Each is evaluated while those and what the
operands after it use live; a subscript read late that gives a value is
read later, while what those after it use lives. -/
def elabOps (ctx : Ctx) (es : List Expr) (after held : List Place) : Elaborated (List Expr) :=
  match es with
  | [] => ⟨[], [], []⟩
  | e :: rest =>
    let held' := if isGetter ctx.prog e then union held (placeUses ctx [e]) else held
    let rs := elabOps ctx rest after held'
    let r := if lateValue ctx.prog e then
        elabLate ctx e (union after (placeUses ctx (rest.filter (isGetter ctx.prog))))
          (union held rs.uses)
      else elabExpr ctx false e (union (union after held) rs.uses)
    ⟨r.out :: rs.out, union r.uses rs.uses, r.dropped ++ rs.dropped⟩

/-- Elaborates the subscript read late `e`, given the slots live once it is
read, `after`: the slots `held`, which the subscripts read late before it
and the operands after it use, live while its arguments are evaluated, in
operand order, since their getters are called, and those operands read,
later. -/
def elabLate (ctx : Ctx) (e : Expr) (after held : List Place) : Elaborated Expr :=
  match e with
  | .call f args =>
    let d := opDrops ctx.owned (directArgs ctx args (callModes ctx.prog f)) after
    let r := elabOps ctx args d.2.2 held
    .op (.call f r.out) r.uses d.1 d.2.1 r.dropped
  | e => ⟨e, uses ctx.sl e, droppedIn e⟩
end

/-- An operation's drops come before those of its operands. -/
theorem droppedIn_withDropsOf (e : Expr) (pre post : List Place) :
    droppedIn (withDropsOf e pre post) = pre ++ post ++ droppedIn e := by
  unfold withDropsOf
  split <;> simp_all [droppedIn]

mutual
/-- Elaboration finds the slots that an expression uses. -/
theorem elabExpr_uses (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) :
    (elabExpr ctx top e after).uses = uses ctx.sl e := by
  match e with
  | .call _ args | .method _ _ args | .listInit _ args =>
    simp [elabExpr, Elaborated.op, uses, elabOps_uses]
  | .binary op a b =>
    simp only [elabExpr]
    split <;> (try split) <;> (try split) <;>
      simp [Elaborated.op, uses, elabExpr_uses, elabLate_uses]
  | .unary op a => simp [elabExpr, Elaborated.op, uses, elabExpr_uses]
  | .list t es =>
    simp only [elabExpr]
    split <;> simp [Elaborated.op, uses, elabOps_uses]
  | .copy p => simp [elabExpr, Elaborated.op]
  | .temp x v => simp [elabExpr, uses, elabExpr_uses]
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .withDrops .. => simp [elabExpr]
termination_by structural e

/-- Elaboration finds the slots that operands use. -/
theorem elabOps_uses (ctx : Ctx) (es : List Expr) (after held : List Place) :
    (elabOps ctx es after held).uses = usesList ctx.sl es := by
  match es with
  | [] => simp [elabOps, usesList]
  | e :: rest =>
    simp only [elabOps]
    split <;> simp [usesList, elabExpr_uses, elabLate_uses, elabOps_uses]
termination_by structural es

/-- Elaboration finds the slots that a subscript read late uses. -/
theorem elabLate_uses (ctx : Ctx) (e : Expr) (after held : List Place) :
    (elabLate ctx e after held).uses = uses ctx.sl e := by
  match e with
  | .call f args => simp [elabLate, Elaborated.op, uses, elabOps_uses]
  | .method .. | .binary .. | .unary .. | .list .. | .listInit .. | .copy _ | .int _ | .bool _
    | .str _ | .place _ | .transfer _ | .withDrops .. | .temp .. =>
    simp [elabLate]
termination_by structural e
end

mutual
/-- Elaboration finds the slots that the elaborated expression destroys. -/
theorem elabExpr_dropped (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) :
    (elabExpr ctx top e after).dropped = droppedIn (elabExpr ctx top e after).out := by
  match e with
  | .call _ args | .method _ _ args | .listInit _ args =>
    simp [elabExpr, Elaborated.op, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .binary op a b =>
    simp only [elabExpr]
    split
    · split <;> split <;> simp_all [Elaborated.op, droppedIn_withDropsOf, droppedIn, elabExpr_dropped]
    · split <;> split <;> simp [Elaborated.op, droppedIn_withDropsOf, droppedIn,
        elabExpr_dropped, elabLate_dropped]
  | .unary op a =>
    simp [elabExpr, Elaborated.op, droppedIn_withDropsOf, droppedIn, elabExpr_dropped]
  | .list t es =>
    simp only [elabExpr]
    split <;> simp [Elaborated.op, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .copy p => simp [elabExpr, Elaborated.op, droppedIn_withDropsOf, droppedIn]
  | .temp x v => simp [elabExpr, droppedIn, elabExpr_dropped]
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .withDrops .. => simp [elabExpr]
termination_by structural e

/-- Elaboration finds the slots that the elaborated operands destroy. -/
theorem elabOps_dropped (ctx : Ctx) (es : List Expr) (after held : List Place) :
    (elabOps ctx es after held).dropped = droppedList (elabOps ctx es after held).out := by
  match es with
  | [] => simp [elabOps, droppedList]
  | e :: rest =>
    simp only [elabOps]
    split <;> simp [droppedList, elabExpr_dropped, elabLate_dropped, elabOps_dropped]
termination_by structural es

/-- Elaboration finds the slots that the elaborated subscript read late
destroys. -/
theorem elabLate_dropped (ctx : Ctx) (e : Expr) (after held : List Place) :
    (elabLate ctx e after held).dropped = droppedIn (elabLate ctx e after held).out := by
  match e with
  | .call f args =>
    simp [elabLate, Elaborated.op, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .method .. | .binary .. | .unary .. | .list .. | .listInit .. | .copy _ | .int _ | .bool _
    | .str _ | .place _ | .transfer _ | .withDrops .. | .temp .. =>
    simp [elabLate]
termination_by structural e
end

end MojoGrimoire.Elab
