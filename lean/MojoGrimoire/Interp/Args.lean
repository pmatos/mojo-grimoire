import MojoGrimoire.Interp.Machine
import MojoGrimoire.Check.Env

/-!
The arguments and operands of the evaluator (`MojoGrimoire.Interp.Eval`):
what a call receives, what evaluation finds of an operand before it
reads it, once every operand of its operation is evaluated, the
binding of a function's parameters to its arguments, and the indices of
an assigned place, evaluated before its value.

An operand that is a place passed by value, or a call that returns a
reference, is only located when it is evaluated: as in Mojo, it is read
once every operand has been evaluated, so a call among the later operands
may change it first. A subscript `p[i]` of a struct that declares
`__getitem__` and `__setitem__`, which inference makes a call of the
getter (#191), is an operand of its own kind: Mojo locates its receiver
and evaluates its index in order, but calls the getter only when it
reads the operand (`MojoGrimoire.Check.lateGetter`), before it reads the
operation's other operands, but after it copies the arguments of `var`
parameters (`loadFirst`). The operand of a unary operator, and those of
`and` and `or`, are read at once. An `Int` or a `Bool` passed to a `read`
parameter is passed by value: Mojo copies it.
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
read into a value when the call is made, `copy o` too, for a `var`
parameter, and `temp o` into a temporary passed to a borrowing
parameter. -/
inductive Pending where
  | arg (a : Arg)
  | load (o : Operand)
  | copy (o : Operand)
  | temp (o : Operand)
end

/-- When the operand `o` is read among its operation's: a subscript read
late, `1`, before any other, `2`. -/
def Operand.rank : Operand → Nat
  | .getter .. => 1
  | _ => 2

/-- When the pending argument `p` is read among its call's: a copy into a
`var` parameter first, `0`, then a subscript read late, then any other. -/
def Pending.rank : Pending → Nat
  | .copy o => if o.rank == 1 then 1 else 0
  | .load o | .temp o => o.rank
  | .arg _ => 2

/-- When the operand `o` of the field of type `t` of a `@fieldwise_init`
construction is read: like an argument, copied first into a struct field. -/
def fieldRank (o : Operand) (t : Ty) : Nat :=
  if o.rank == 1 then 1 else if t matches .struct _ then 0 else 2

/-- Reads `xs` with `load`, by `rank`, each rank in order: Mojo copies into
`var` parameters, calls the getters of the subscripts read late, and reads
the other operands, in that order (#191). -/
def loadFirst {α β : Type} (rank : α → Nat) (load : α → EvalM β) (xs : List α) :
    EvalM (List β) := do
  if xs.all (rank · == 2) then return ← xs.mapM load
  let mut out : Array (Option β) := xs.toArray.map fun _ => none
  for r in [0, 1, 2] do
    for (x, i) in xs.zipIdx do
      if rank x == r then out := out.set! i (some (← load x))
  pure (out.toList.filterMap id)

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
