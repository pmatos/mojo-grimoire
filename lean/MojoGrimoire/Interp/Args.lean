import MojoGrimoire.Interp.Machine
import MojoGrimoire.Check.Env

/-!
The arguments and operands of the evaluator (`MojoGrimoire.Interp.Eval`):
what a call receives, an operand found but not yet read, the binding
of a function's parameters to its arguments, and the indices of an
assigned place, evaluated before its value.
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

/-- The `__bool__` and the operand of `e`, when `e` is a call of a `__bool__`
whose `self` is `var` that inference made to test a struct operand
(`MojoGrimoire.Core.boolTest`). As the left operand of `and` or `or`, the
compiler gives `self` a copy of the operand, which may be the result,
and destroys a temporary operand once it is copied (#191). -/
def copiedTest (prog : Program) (e : Expr) : Option (FunDecl × Expr) :=
  (boolTest e).bind fun (s, x) =>
    ((findStruct prog s).bind (findMethod · "__bool__")).bind fun fd =>
      if fd.params.head?.any (·.conv == .owned) then some (fd, x) else none

/-- The binding of the variable `x`. -/
def lookupVar (env : Env) (x : Name) : EvalM Ref := do
  let some b := env.lookup x | stuck s!"unknown variable {x}"
  pure b.ref

/-- The `Int` and the index of the place `p` of the variables `env` when
`p` is an element of an `Int` (#127). -/
def intElem (prog : Program) (env : Env) : Place → Option (Place × Expr)
  | .index q i => if placeTy prog env q == some .int then some (q, i) else none
  | _ => none

/-- The place `p` with each of its indices replaced by its value, which
`index` evaluates, outermost first, as the compiler does before it
evaluates an assigned value (#205). Once an index is evaluated, `locate`
locates the element it names, so that an index out of bounds stops the
run there, before any index after it is evaluated. An assignment
locates the element again once its value is evaluated (D-0002). -/
def fixIndices (index : Expr → EvalM Int) (locate : Place → EvalM Ref) : Place → EvalM Place
  | .var x => pure (.var x)
  | .field q f => do pure (.field (← fixIndices index locate q) f)
  | .index q i => do
    let q ← fixIndices index locate q
    let p := Place.index q (.int (← index i))
    let _ ← locate p
    pure p
  | .transferred q => do pure (.transferred (← fixIndices index locate q))

end MojoGrimoire.Interp
