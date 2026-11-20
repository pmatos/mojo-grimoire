import MojoGrimoire.Interp.Machine
import MojoGrimoire.Check.State

/-!
The arguments and operands of the evaluator (`MojoGrimoire.Interp.Eval`):
what a call receives, and what evaluation finds of an operand before it
reads it, once every operand of its operation is evaluated.

An operand that is a place passed by value, or a call that returns a
reference, is only located when it is evaluated: as in Mojo, it is read
once every operand has been evaluated, so a call among the later operands
may change it first. A subscript `p[i]` of a struct that declares
`__getitem__` and `__setitem__`, which inference makes a call of the
getter (#191), is an operand of its own kind: Mojo locates its receiver
and evaluates its index in order, but calls the getter only when it
reads the operand (`MojoGrimoire.Check.lateGetter`), before it reads the
operation's other operands (`loadFirst`). On the left of `and` or `or`,
such a getter runs once to test the operand and again for the result
when it decides. The operand of a unary operator, and those of `and` and
`or`, are read at once. An `Int` or a `Bool` passed to a `read` parameter is passed
by value: Mojo copies it.
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

mutual
/-- An operand as evaluation first finds it: a place passed by value, or
the reference that a call returns, located but not yet read; the value of
any other expression; or a subscript of a struct, `getter fd args pre
post`, whose getter `fd` is called with the arguments `args` when the
operand is read, destroying the values in `pre` once they are read and
those in `post` once it is done. -/
inductive Operand where
  | loc (r : Ref)
  | val (v : Value)
  | getter (fd : FunDecl) (args : List Pending) (pre post : List Place)

/-- An argument before the operands passed by value are read: `load o` is
read into a value when the call is made, and `temp o` into a temporary
passed to a borrowing parameter. -/
inductive Pending where
  | arg (a : Arg)
  | load (o : Operand)
  | temp (o : Operand)
end

/-- The value that the result `r` of a call gives: the value it points to,
for a reference. -/
def Result.read : Result → EvalM Value
  | .value v => pure v
  | .ref r => readRef r

/-- Whether the operand `o` is a subscript read late. -/
def Operand.late : Operand → Bool
  | .getter .. => true
  | _ => false

/-- Whether the pending argument `p` is a subscript read late. -/
def Pending.late : Pending → Bool
  | .load o | .temp o => o.late
  | .arg _ => false

mutual
/-- The operand `o` with none of its getters' drops: the compiler calls the
getter of a subscript read late on the left of `and` or `or` once to test
it, destroying nothing, and again for the result when it decides. -/
def Operand.undropped : Operand → Operand
  | .getter fd as _ _ => .getter fd (Pending.undroppedAll as) [] []
  | o => o

/-- The pending arguments `ps` with none of their getters' drops. -/
def Pending.undroppedAll : List Pending → List Pending
  | [] => []
  | .load o :: ps => .load o.undropped :: Pending.undroppedAll ps
  | .temp o :: ps => .temp o.undropped :: Pending.undroppedAll ps
  | p :: ps => p :: Pending.undroppedAll ps
end

mutual
/-- The drops of the getters of the operand `o`, in the order they run. -/
def Operand.drops : Operand → List Place
  | .getter _ as pre post => Pending.dropsAll as ++ pre ++ post
  | _ => []

/-- The drops of the getters of the pending arguments `ps`. -/
def Pending.dropsAll : List Pending → List Place
  | [] => []
  | .load o :: ps | .temp o :: ps => o.drops ++ Pending.dropsAll ps
  | _ :: ps => Pending.dropsAll ps
end

mutual
/-- The variables of the places among the arguments of the subscript read
late `e`, and of those read late among them. -/
def lateRoots : Expr → List Name
  | .place p => [(splitPlace p).1]
  | .call _ args | .withDrops (.call _ args) _ _ => lateRootsAll args
  | _ => []

/-- The variables of the places among `es`, and among their arguments. -/
def lateRootsAll : List Expr → List Name
  | [] => []
  | e :: es => lateRoots e ++ lateRootsAll es
end

/-- Reads `xs` with `load`: those that `late` picks first, then the others,
each in order. Mojo calls the getters of the subscripts read late among an
operation's operands before it reads its other operands (#191). -/
def loadFirst {α β : Type} (late : α → Bool) (load : α → EvalM β) (xs : List α) :
    EvalM (List β) := do
  if !xs.any late then return ← xs.mapM load
  let mut got ← (xs.filter late).mapM load
  let mut out := []
  for x in xs do
    if late x then
      let v :: vs := got | stuck "a getter read twice"
      out := v :: out
      got := vs
    else out := (← load x) :: out
  pure out.reverse

/-- The getter, its arguments and its drops, of the operand `e` when it is
a subscript read late (`MojoGrimoire.Check.lateGetter`). -/
def lateCall (prog : Program) : Expr → Option (Name × List Expr × List Place × List Place)
  | .call f args => if lateGetter prog f then some (f, args, [], []) else none
  | .withDrops (.call f args) pre post =>
    if lateGetter prog f then some (f, args, pre, post) else none
  | _ => none

/-- The variables a function starts with: its parameters bound to the
arguments, each owned when it is passed `var`. The temporaries are given
locations of their own. -/
def bindParams : List Param → List Arg → EvalM Env
  | prm :: prms, a :: args => do
    let rest ← bindParams prms args
    let b ← match a with
      | .place r => pure ⟨r, false⟩
      | .value v => do pure ⟨← alloc v, prm.conv == .owned⟩
      | .temp v => do pure ⟨← alloc v, false⟩
    pure ((prm.name, b) :: rest)
  | _, _ => pure []

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

/-- Calls the method `m` of the list at `r` with the values `vs` of its
arguments: `append` adds its element at the end, and `pop` takes out the
last element, or the one at its index, and gives it. -/
def listMethodOn (r : Ref) (m : Name) (vs : List Value) : EvalM Result := do
  let .list es ← readRef r | stuck s!"{m} on a value that is not a list"
  match m, vs with
  | "append", [v] => do
    writeRef r (.list (es ++ [v]))
    pure (.value .none)
  | "pop", [] => do
    let some v := es.getLast? | fail .indexOutOfBounds
    writeRef r (.list es.dropLast)
    pure (.value v)
  | "pop", [k] => do
    let j ← position es.length (← asInt k)
    let some v := es[j]? | fail .indexOutOfBounds
    writeRef r (.list (es.eraseIdx j))
    pure (.value v)
  | _, _ => stuck s!"unknown list method {m}"

/-- The list that the standard library's `range`, which only `List[u](…)`
takes (#121), gives for the arguments `args`, its `Int`s read by value as
a call reads `read` arguments. The fuel left at the call, `fuel`, bounds
its length: a longer range runs out of fuel before the list is built. -/
def rangeOf (fuel : Nat) (args : List Arg) : EvalM Value := do
  let ks ← args.mapM fun
    | .value v | .temp v => asInt v
    | .place _ => stuck "range reads its Ints by value"
  let (a, b, c) ← match ks with
    | [b] => pure (0, b, 1)
    | [a, b] => pure (a, b, 1)
    | [a, b, c] => pure (a, b, c)
    | _ => stuck "range with no argument or more than three"
  rangeList fuel a b c

end MojoGrimoire.Interp
