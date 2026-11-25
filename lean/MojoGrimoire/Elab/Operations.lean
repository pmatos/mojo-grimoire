import MojoGrimoire.Elab.Origins

/-!
The elaboration of the operations of an expression: the drops that each
call, method call, operator, list literal, `List[u](e)` and `.copy()`
makes, given the slots live once it is evaluated. `MojoGrimoire.Elab.Elaborate`
elaborates the statements that hold them.

Elaboration returns, with each elaborated expression, the slots that the
expression uses and those that the elaboration destroys. An operation reads
them from its operands, and does not walk the operands again, so that a
right-nested chain of operations, such as `a and (b or (a and …))`, is
elaborated in time linear in its depth (#283). Theorems at the end show
that they are what `uses` and `droppedIn` give.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- Whether each argument of a call of `f` is passed by value, when it is a
place, as its signature says. `len`, which has none, takes its list by
reference. The standard library's `range` reads its `Int`s by value. -/
def callModes (prog : Program) (f : Name) : List Bool :=
  match callSig prog f with
  | .ok sig => sig.params.map passedByValue
  | .error _ =>
    if builtinRange prog f then (rangeParams 3).map passedByValue else []

/-- Whether the receiver `p` of a call of the method `m` with `n` arguments,
and each argument, is passed by value, as the method's signature says. -/
def methodModes (prog : Program) (env : TyEnv) (p : Place) (m : Name) (n : Nat) :
    Bool × List Bool :=
  match (placeTyOf prog env p).bind fun t => (methodSig prog t m n).toOption with
  | some sig => (sig.self.any passedByValue, sig.params.map passedByValue)
  | none => (false, [])

/-- What elaboration knows inside a function: the program, its slots, the
slots it owns in the order they die when several die at once, and the types
of the variables declared so far. -/
structure Ctx where
  prog : Program
  sl : Slots
  owned : List Place
  env : TyEnv

/-- The slot that a call of the method `m` with `n` arguments on the
receiver `p` consumes: `q`, when `p` is `q^`, `q` is a whole slot, and the
method takes `var self`. The call moves it away, so nothing destroys it. -/
def consumedSlot (ctx : Ctx) (p : Place) (m : Name) (n : Nat) : List Place :=
  let self := (placeTyOf ctx.prog ctx.env p).bind fun t =>
    (methodSig ctx.prog t m n).toOption.bind (·.self)
  match self.bind (consumedReceiver ·.conv p) with
  | some q => if ctx.sl.isSlot q then [q] else []
  | none => []

mutual
/-- The slots that the method calls in `e` consume. -/
def consumedIn (ctx : Ctx) : Expr → List Place
  | .method p m args => union (consumedSlot ctx p m args.length) (consumedList ctx args)
  | .call _ args | .list _ args | .listInit _ args => consumedList ctx args
  | .binary _ a b => union (consumedIn ctx a) (consumedIn ctx b)
  | .unary _ a | .withDrops a _ _ => consumedIn ctx a
  | _ => []

/-- The slots that the method calls in `es` consume. -/
def consumedList (ctx : Ctx) : List Expr → List Place
  | [] => []
  | e :: es => union (consumedIn ctx e) (consumedList ctx es)
end

/-- The slots that the operand `e` uses directly, with whether it is passed
by value `m`. A literal `[e]` of type `Int` uses those of `e`, read by
value: a place uses its slots and those of its indices; any other
operand is an operation of its own, which destroys what it last uses. A
call that returns a reference also uses the slots it points into: passed
by reference, they live until the operation is done; passed by value, until
the operands are read, since Mojo reads the reference then, and those the
function owns die then in the order of `owned`. -/
def directOf (ctx : Ctx) (e : Expr) (m : Bool) : List Place × Bool :=
  match e with
  | .place p => (union (ctx.sl.of p) (indexUses ctx.sl p), m)
  | .list .int [x] => directOf ctx x true
  | e =>
    let ls := locSlots ctx.prog ctx.sl ctx.env e
    (if m then ctx.owned.filter (ls.contains ·) else ls, m)

/-- The direct uses of the operands `es`, passed by value as `ms` says. -/
def directArgs (ctx : Ctx) : List Expr → List Bool → List (List Place × Bool)
  | [], _ => []
  | e :: es, ms => directOf ctx e (ms.headD false) :: directArgs ctx es ms.tail

/-- The values that an operation destroys, given the direct uses of its
operands, `direct`, and the slots live once it is done, `after`: those read
by value die once the operands are read, in the order they are read, and
those used by reference once it is done, in the order of `owned`. Also the
slots live once every operand is evaluated. -/
def opDrops (owned : List Place) (direct : List (List Place × Bool)) (after : List Place) :
    List Place × List Place × List Place :=
  let byRef := (direct.filter (!·.2)).foldl (fun acc d => union acc d.1) []
  let byVal := (direct.filter (·.2)).foldl (fun acc d => union acc d.1) []
  let atLoad := union after byRef
  (byVal.filter fun x => owned.contains x && !atLoad.contains x,
   owned.filter fun x => byRef.contains x && !after.contains x,
   union atLoad byVal)

/-- The operation `e`, destroying `pre` once its operands are read and
`post` once it is done; `e` itself when it destroys nothing. -/
def withDropsOf (e : Expr) (pre post : List Place) : Expr :=
  if pre.isEmpty && post.isEmpty then e else .withDrops e pre post

mutual
/-- The slots that the elaborated expression `e` destroys. -/
def droppedIn : Expr → List Place
  | .withDrops e pre post => pre ++ post ++ droppedIn e
  | .call _ args | .method _ _ args | .list _ args | .listInit _ args => droppedList args
  | .binary _ a b => droppedIn a ++ droppedIn b
  | .unary _ a => droppedIn a
  | _ => []

/-- The slots that the elaborated expressions `es` destroy. -/
def droppedList : List Expr → List Place
  | [] => []
  | e :: es => droppedIn e ++ droppedList es
end

/-- What the operand `e`, read once it is done, keeps alive until then:
what a call's reference points into (#191). -/
def opKeep (ctx : Ctx) (e : Expr) : List Place := (directOf ctx e true).1

/-- An elaboration, `out`, of an expression or of a list of operands, with
the slots that the input uses, `uses`, and those that `out` destroys,
`dropped`. Each operation reads both from the results of its operands, so
that elaborating an expression walks it once (#283); `elabExpr_uses` and
`elabExpr_dropped` show that they are `uses` and `droppedIn`. -/
structure Elaborated (α : Type) where
  out : α
  uses : List Place
  dropped : List Place

/-- The elaborated operation `mk r.out`, which uses `u` and destroys `pre`
once its operands, elaborated as `r`, are read and `post` once it is done. -/
def Elaborated.wrap {α : Type} (r : Elaborated α) (mk : α → Expr) (u pre post : List Place) :
    Elaborated Expr :=
  ⟨withDropsOf (mk r.out) pre post, u, pre ++ post ++ r.dropped⟩

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
    let r := elabOps ctx args d.2.2
    r.wrap (.call f) r.uses d.1 (if top then [] else d.2.1)
  | .method p m args =>
    let ms := methodModes ctx.prog ctx.env p m args.length
    let d := opDrops ctx.owned (directOf ctx (.place p) ms.1 :: directArgs ctx args ms.2)
      after
    let gone := consumedSlot ctx p m args.length
    let r := elabOps ctx args d.2.2
    r.wrap (.method p m) (union (union (ctx.sl.of p) (indexUses ctx.sl p)) r.uses)
      (diff d.1 gone) (if top then [] else diff d.2.1 gone)
  | .binary op a b =>
    if op == .and || op == .or then
      let rb := elabExpr ctx false b (union after (opKeep ctx b))
      let d := opDrops ctx.owned [directOf ctx a true, (rb.uses, false)] after
      let rest := diff d.2.1 rb.dropped
      let b' := if rest.isEmpty then rb.out else .withDrops (.withDrops rb.out [] []) [] rest
      let ra := elabExpr ctx false a d.2.2
      ⟨withDropsOf (.binary op ra.out b') d.1 d.2.1, union ra.uses rb.uses,
        d.1 ++ d.2.1 ++ (ra.dropped ++ (rest ++ rb.dropped))⟩
    else
      let byVal := fun e => ((refSlots ctx.prog ctx.sl ctx.env e).2.bind (seqCompare op)).isNone
      let d := opDrops ctx.owned (directArgs ctx [a, b] [byVal a, byVal b]) after
      let rb := elabExpr ctx false b d.2.2
      let ra := elabExpr ctx false a (union d.2.2 rb.uses)
      let post := if top then [] else d.2.1
      ⟨withDropsOf (.binary op ra.out rb.out) d.1 post, union ra.uses rb.uses,
        d.1 ++ post ++ (ra.dropped ++ rb.dropped)⟩
  | .unary op a =>
    let d := opDrops ctx.owned [directOf ctx a true] after
    let r := elabExpr ctx false a d.2.2
    r.wrap (.unary op) r.uses d.1 (if top then [] else d.2.1)
  | .list t es =>
    if t == .int then
      let r := elabOps ctx es after
      ⟨.list t r.out, r.uses, r.dropped⟩
    else
    let d := opDrops ctx.owned (directArgs ctx es (es.map fun _ => true)) after
    let r := elabOps ctx es d.2.2
    r.wrap (.list t) r.uses d.1 (if top then [] else d.2.1)
  | .listInit u es =>
    let d := opDrops ctx.owned (directArgs ctx es []) after
    let r := elabOps ctx es d.2.2
    r.wrap (.listInit u) r.uses d.1 (if top then [] else d.2.1)
  | .copy p =>
    let d := opDrops ctx.owned [directOf ctx (.place p) false] after
    let post := if top then [] else d.2.1
    ⟨withDropsOf (.copy p) d.1 post, union (ctx.sl.of p) (indexUses ctx.sl p), d.1 ++ post⟩
  | e => ⟨e, uses ctx.sl e, droppedIn e⟩

/-- Elaborates the operands `es`, evaluated in order, given the slots live
once the last is evaluated. -/
def elabOps (ctx : Ctx) (es : List Expr) (after : List Place) : Elaborated (List Expr) :=
  match es with
  | [] => ⟨[], [], []⟩
  | e :: rest =>
    let rs := elabOps ctx rest after
    let r := elabExpr ctx false e (union after rs.uses)
    ⟨r.out :: rs.out, union r.uses rs.uses, r.dropped ++ rs.dropped⟩
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
  | .call f args | .listInit _ args =>
    simp [elabExpr, Elaborated.wrap, uses, elabOps_uses]
  | .method p m args => simp [elabExpr, Elaborated.wrap, uses, elabOps_uses]
  | .binary op a b =>
    simp only [elabExpr]
    split <;> simp [uses, elabExpr_uses]
  | .unary op a => simp [elabExpr, Elaborated.wrap, uses, elabExpr_uses]
  | .list t es =>
    simp only [elabExpr]
    split <;> simp [Elaborated.wrap, uses, elabOps_uses]
  | .copy p => simp [elabExpr, uses]
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .withDrops .. => simp [elabExpr]

/-- Elaboration finds the slots that operands use. -/
theorem elabOps_uses (ctx : Ctx) (es : List Expr) (after : List Place) :
    (elabOps ctx es after).uses = usesList ctx.sl es := by
  match es with
  | [] => simp [elabOps, usesList]
  | e :: rest => simp [elabOps, usesList, elabExpr_uses, elabOps_uses ctx rest after]
end

mutual
/-- Elaboration finds the slots that the elaborated expression destroys. -/
theorem elabExpr_dropped (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) :
    (elabExpr ctx top e after).dropped = droppedIn (elabExpr ctx top e after).out := by
  match e with
  | .call f args | .listInit _ args =>
    simp [elabExpr, Elaborated.wrap, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .method p m args =>
    simp [elabExpr, Elaborated.wrap, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .binary op a b =>
    simp only [elabExpr]
    split
    · split <;> simp_all [droppedIn_withDropsOf, droppedIn, elabExpr_dropped]
    · simp [droppedIn_withDropsOf, droppedIn, elabExpr_dropped]
  | .unary op a =>
    simp [elabExpr, Elaborated.wrap, droppedIn_withDropsOf, droppedIn, elabExpr_dropped]
  | .list t es =>
    simp only [elabExpr]
    split <;> simp [Elaborated.wrap, droppedIn_withDropsOf, droppedIn, elabOps_dropped]
  | .copy p => simp [elabExpr, droppedIn_withDropsOf, droppedIn]
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .withDrops .. => simp [elabExpr]

/-- Elaboration finds the slots that the elaborated operands destroy. -/
theorem elabOps_dropped (ctx : Ctx) (es : List Expr) (after : List Place) :
    (elabOps ctx es after).dropped = droppedList (elabOps ctx es after).out := by
  match es with
  | [] => simp [elabOps, droppedList]
  | e :: rest => simp [elabOps, droppedList, elabExpr_dropped, elabOps_dropped ctx rest after]
end

end MojoGrimoire.Elab
