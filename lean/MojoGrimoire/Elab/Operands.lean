import MojoGrimoire.Elab.Late

/-!
What an operation of an elaborated expression destroys (#191), for
`MojoGrimoire.Elab.Elaborate`. An operation uses directly the slots of the
places among its operands, by value or by reference, and those that a call
returning a reference points into; a subscript that Mojo reads late uses
the places among its getter's arguments until its getter is called
(`MojoGrimoire.Elab.Late`). Given the slots live once it is done, those it
uses by value and nowhere later die once its operands are read, and those
it uses by reference once it is done. A method call that takes `var self`
on `q^` consumes `q`, so nothing destroys it.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

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
  | .unary _ a | .withDrops a _ _ | .temp _ a => consumedIn ctx a
  | _ => []

/-- The slots that the method calls in `es` consume. -/
def consumedList (ctx : Ctx) : List Expr → List Place
  | [] => []
  | e :: es => union (consumedIn ctx e) (consumedList ctx es)
end

/-- The slots that the operand `e`, neither a place, a literal of type
`Int` nor a subscript read late, uses directly, with whether it is passed
by value `m` (`directOf`). -/
def locOperand (ctx : Ctx) (e : Expr) (m : Bool) : List Place × Bool :=
  let ls := locSlots ctx.prog ctx.sl ctx.env e
  (if m then ctx.owned.filter (ls.contains ·) else ls, m)

/-- The slots that the operand `e` uses directly, with whether it is passed
by value `m`. A literal `[e]` of type `Int` uses those of `e`, read by
value: a place uses its slots and those of its indices; any other
operand is an operation of its own, which destroys what it last uses. A
call that returns a reference also uses the slots it points into: passed
by reference, they live until the operation is done; passed by value, until
the operands are read, since Mojo reads the reference then, and those the
function owns die then in the order of `owned`. A subscript that Mojo
reads late and whose getter returns a value uses the places among its
getter's arguments, read by value: the getter is called once the operands
are read. One whose getter returns a reference uses what the reference
points into, as a call that returns one does; its getter destroys what
else it last uses right after it (#191). -/
def directOf (ctx : Ctx) (e : Expr) (m : Bool) : List Place × Bool :=
  match e with
  | .place p => (union (ctx.sl.of p) (indexUses ctx.sl p), m)
  | .list .int [x] => directOf ctx x true
  | e =>
    match e with
    | .call _ args =>
      if lateValue ctx.prog e then (placeSlots ctx.prog ctx.sl args, true) else locOperand ctx e m
    | e => locOperand ctx e m

/-- What the operand `e`, read once it is done, keeps alive until then: what
a call's reference points into, and for a subscript read late only that,
since its getter destroys what else it last uses (#191). -/
def opKeep (ctx : Ctx) (e : Expr) : List Place :=
  (if isGetter ctx.prog e then locOperand ctx e true else directOf ctx e true).1

/-- The direct uses of the operands `es`, passed by value as `ms` says. A
subscript read late that gives a value has none: its getter destroys what
it last uses (`lateValue`). -/
def directArgs (ctx : Ctx) : List Expr → List Bool → List (List Place × Bool)
  | [], _ => []
  | e :: es, ms =>
    (if lateValue ctx.prog e then ([], true) else directOf ctx e (ms.headD false)) ::
      directArgs ctx es ms.tail

/-- The slots that the operands `es`, read by reference, use directly; for
a subscript read late, the places among its getter's arguments, which live
until its getter is called. -/
def placeUses (ctx : Ctx) : List Expr → List Place
  | [] => []
  | e :: es =>
    let own := match e with
      | .call f args => if lateGetter ctx.prog f then placeSlots ctx.prog ctx.sl args else []
      | _ => []
    union (union own (directOf ctx e false).1) (placeUses ctx es)

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

end MojoGrimoire.Elab
