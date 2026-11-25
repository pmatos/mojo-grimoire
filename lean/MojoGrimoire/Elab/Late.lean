import MojoGrimoire.Elab.Origins

/-!
Subscripts that Mojo reads late (#191): a subscript of a struct that
declares `__getitem__` and `__setitem__` calls its getter when its
operation reads the operand, once every operand is evaluated
(`MojoGrimoire.Check.lateGetter`). The places among the getter's arguments,
and those of the subscripts read late among them, live until then, and
until then also what the later operands use, since the arguments are
evaluated in operand order. The getter destroys what it last uses right
after it is called; one that returns a reference keeps alive only what
its reference points into, which the operation uses, as a call that
returns one does.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- The slots that the places among the arguments `args` of a subscript
read late use where they are, with those of their indices, and those of
the subscripts read late among them, whose getters are called with it. -/
def placeSlots (prog : Program) (sl : Slots) : List Expr → List Place
  | [] => []
  | .place p :: es => union (union (sl.of p) (indexUses sl p)) (placeSlots prog sl es)
  | .call f args :: es =>
    if lateGetter prog f then union (placeSlots prog sl args) (placeSlots prog sl es)
    else placeSlots prog sl es
  | _ :: es => placeSlots prog sl es

/-- Whether `e` is a subscript that Mojo reads late, a call of a getter
that it makes when it reads the operand. -/
def isGetter (prog : Program) (e : Expr) : Bool :=
  match e with
  | .call f _ => lateGetter prog f
  | _ => false

/-- Whether `e` is a subscript read late whose getter returns a value, and
so destroys what it last uses itself. -/
def lateValue (prog : Program) (e : Expr) : Bool :=
  match e with
  | .call f _ => lateGetter prog f && !(callSig prog f).toOption.any (·.origin.isSome)
  | _ => false

end MojoGrimoire.Elab
