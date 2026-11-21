import MojoGrimoire.Interp.Machine
import MojoGrimoire.Check.Env

/-!
The arguments and operands of the evaluator (`MojoGrimoire.Interp.Eval`):
what a call receives, an operand found but not yet read, and the binding
of a function's parameters to its arguments.
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core MojoGrimoire.Check

/-- An argument as a call receives it: a place, passed by reference, or a
value, passed by moving or copying it. `temp` is a value passed to a
borrowing parameter, which the caller destroys after the call. -/
inductive Arg where
  | place (r : Ref)
  | value (v : Value)
  | temp (v : Value)

/-- An operand as evaluation first finds it: a place passed by value, or
the reference that a call returns, located but not yet read, or the value
of any other expression. -/
inductive Operand where
  | loc (r : Ref)
  | val (v : Value)

/-- The value of an operand, once every operand has been evaluated. -/
def Operand.load : Operand → EvalM Value
  | .loc r => readRef r
  | .val v => pure v

/-- An argument before the operands passed by value are read: `load o` is
read into a value when the call is made. -/
inductive Pending where
  | arg (a : Arg)
  | load (o : Operand)

/-- The arguments of a call, once every argument has been evaluated: each
pending operand is read. -/
def Pending.loadAll (ps : List Pending) : EvalM (List Arg) :=
  ps.mapM fun
    | .arg a => pure a
    | .load o => do pure (.value (← o.load))

/-- The variables a function starts with: its parameters bound to the
arguments, each owned when it is passed `var`. The temporaries are given
locations of their own. -/
def bindParams : List Param → List Arg → EvalM Env
  | prm :: prms, a :: args => do
    let rest ← bindParams prms args
    let b ← match a with
      | .place r => pure ⟨r, false, prm.ty⟩
      | .value v => do pure ⟨← alloc v, prm.conv == .owned, prm.ty⟩
      | .temp v => do pure ⟨← alloc v, false, prm.ty⟩
    pure ((prm.name, b) :: rest)
  | _, _ => pure []

/-- The value that a call's result gives: a returned reference is read. -/
def Result.read : Result → EvalM Value
  | .value v => pure v
  | .ref r => readRef r

/-- The value of an `Int` or `Bool` written by `print`, or of a literal. -/
def asInt : Value → EvalM Int
  | .int n => pure n
  | _ => stuck "expected an Int"

/-- The truth value of a condition. -/
def asBool : Value → EvalM Bool
  | .bool b => pure b
  | _ => stuck "expected a Bool"

/-- The binding of the variable `x`. -/
def lookupVar (env : Env) (x : Name) : EvalM Ref := do
  let some b := env.lookup x | stuck s!"unknown variable {x}"
  pure b.ref

end MojoGrimoire.Interp
