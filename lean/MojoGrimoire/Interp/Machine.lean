import MojoGrimoire.Interp.Value
import MojoGrimoire.Check.Env

/-!
The machine that runs a program: a store of locations, the lines printed so
far, and the ways a run can stop early.

Every variable lives at a location of the store. A reference is a location
with a path to a part of its value, so that a `read`, `mut` or `ref`
argument and a `ref` binding name the very place they were given, and a
change through them is a change to that place. Locations are never reused.

`Int` is Mojo's 64-bit signed integer: arithmetic wraps around, `//` rounds
toward negative infinity and `%` takes the sign of the divisor, as in Mojo.
Both give 0 for a zero divisor, as Mojo's standard library defines them.
Two `Bool`s compare with `False` first, and two arrays or two lists
lexicographically, element by element (#166, #185).
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core MojoGrimoire.Check

/-- A reference: a location, and the path to a part of its value. -/
structure Ref where
  loc : Nat
  path : List Step
  deriving DecidableEq, Repr

/-- A variable of a function: the place it names, whether the function
owns its value and so destroys what is left of it when it returns, and its
type, which tells a place through the element of an `Int` (#127). -/
structure Binding where
  ref : Ref
  owned : Bool
  ty : Ty
  deriving DecidableEq, Repr

/-- The variables in scope, innermost first. -/
abbrev Env := List (Name × Binding)

/-- The ways a run stops before `main` returns. `stuck` is a state that a
program the checker accepts never reaches; it names what went wrong. -/
inductive RunError where
  | outOfFuel
  | indexOutOfBounds
  | stuck (what : String)
  deriving DecidableEq, Repr

/-- What a call gives back: a value, a reference for a function with an
origin, or nothing. -/
inductive Result where
  | value (v : Value)
  | ref (r : Ref)

/-- Why evaluation stopped going forward: an error, or a `return` with its
result, which the call catches. -/
inductive Signal where
  | error (e : RunError)
  | returned (r : Result)

/-- The machine: the store and the lines printed so far. -/
structure Machine where
  store : Array Value
  output : Array String

/-- The monad of the interpreter. The machine survives an error, so that a
failed run still shows what it printed. -/
abbrev EvalM := ExceptT Signal (StateM Machine)

/-- Stops the run with the error `e`. -/
def fail {α : Type} (e : RunError) : EvalM α := throw (.error e)

/-- Stops the run in a state that a checked program never reaches. -/
def stuck {α : Type} (what : String) : EvalM α := fail (.stuck what)

/-- A new location holding `v`. The store is changed in place: no other
reference to the machine is held while it changes, so the array is not
copied, and a run that allocates `n` locations takes time linear in `n`. -/
def alloc (v : Value) : EvalM Ref :=
  modifyGet fun m => (⟨m.store.size, []⟩, { m with store := m.store.push v })

/-- The value at the reference `r`. -/
def readRef (r : Ref) : EvalM Value := do
  let some v := (← get).store[r.loc]? | stuck "no such location"
  let some w := v.get r.path | stuck "no such part"
  pure w

/-- Replaces the value at the reference `r` by `w`, in place, as `alloc`
does. -/
def writeRef (r : Ref) (w : Value) : EvalM Unit := do
  let some v := (← get).store[r.loc]? | stuck "no such location"
  let some v' := v.set r.path w | stuck "no such part"
  modify fun m => { m with store := m.store.set! r.loc v' }

/-- Takes the value out of the reference `r`, and leaves what is left of
it, `Value.blank`, in its place. -/
def take (r : Ref) : EvalM Value := do
  let v ← readRef r
  writeRef r v.blank
  pure v

/-- Prints a line. -/
def emit (line : String) : EvalM Unit :=
  modify fun m => { m with output := m.output.push line }

/-- An integer wrapped to 64-bit two's complement. -/
def wrap (n : Int) : Int := (n + 2 ^ 63) % 2 ^ 64 - 2 ^ 63

mutual
/-- The order of two values that an array or a list may hold and compare:
`Int`s by value, `Bool`s with `False` first, and arrays and lists
lexicographically, as the comparisons of `Array` and `List` order them
(#166, #185); `none` for any other pair. -/
def Value.order : Value → Value → Option Ordering
  | .int x, .int y => some (compare x y)
  | .bool x, .bool y => some (compare x.toNat y.toNat)
  | .list xs, .list ys => Value.orderList xs ys
  | _, _ => Option.none

/-- The lexicographic order of two lists of values (`Value.order`). -/
def Value.orderList : List Value → List Value → Option Ordering
  | [], [] => some .eq
  | [], _ :: _ => some .lt
  | _ :: _, [] => some .gt
  | x :: xs, y :: ys => match Value.order x y with
    | some .eq => Value.orderList xs ys
    | o => o
end

/-- Whether two values in the order `o` satisfy the comparison `op`;
`none` when `op` does not compare. -/
def ordered (op : BinOp) (o : Ordering) : Option Bool :=
  match op with
  | .lt => some (o == .lt)
  | .le => some (o != .gt)
  | .gt => some (o == .gt)
  | .ge => some (o != .lt)
  | .eq => some (o == .eq)
  | .ne => some (o != .eq)
  | _ => none

/-- The result of the arithmetic or comparison operator `op` on `Int`s, of
a comparison of two `Bool`s, `False` first (#185), or of a comparison of
two arrays or two lists, in their order (`Value.order`). `and` and `or`
are evaluated elsewhere, since they short-circuit. -/
def binary (op : BinOp) (a b : Value) : EvalM Value :=
  match op.arith, op, a, b with
  | some f, _, .int x, .int y => pure (.int (wrap (f x y)))
  | _, .lt, .int x, .int y => pure (.bool (decide (x < y)))
  | _, .le, .int x, .int y => pure (.bool (decide (x ≤ y)))
  | _, .gt, .int x, .int y => pure (.bool (decide (x > y)))
  | _, .ge, .int x, .int y => pure (.bool (decide (x ≥ y)))
  | _, .eq, .int x, .int y => pure (.bool (x == y))
  | _, .ne, .int x, .int y => pure (.bool (x != y))
  | _, op, a, b => match (Value.order a b).bind (ordered op) with
    | some r => pure (.bool r)
    | none => stuck "operands of the wrong type"

/-- The result of the unary operator `op`. -/
def unary (op : UnOp) (a : Value) : EvalM Value :=
  match op, a with
  | .neg, .int x => pure (.int (wrap (-x)))
  | .not, .bool x => pure (.bool (!x))
  | _, _ => stuck "operand of the wrong type"

/-- The static type of the place `p` of the variables `env`, from the
types they are declared with, whatever their values hold: an index of an
`Int` is the `Int` (#127). -/
def placeTy (prog : Program) (env : Env) : Place → Option Ty
  | .var x => (env.lookup x).map (·.ty)
  | .field p f => (placeTy prog env p).bind fun t => (fieldOf prog t f).toOption
  | .index p _ => (placeTy prog env p).bind fun
    | .list t | .array t _ => some t
    | .int => some .int
    | _ => none
  | .transferred p => placeTy prog env p

/-- The static type of the reference that `e` names, for a `ref` binding:
a place, or a call of a function or a method that returns a reference. -/
def refTy (prog : Program) (env : Env) : Expr → Ty
  | .place p => (placeTy prog env p).getD .unknown
  | .call f _ => ((callSig prog f).toOption.map (·.result)).getD .unknown
  | .method p m args =>
    (((placeTy prog env p).bind fun t => (methodSig prog t m args.length).toOption).map
      (·.result)).getD .unknown
  | .withDrops e _ _ => refTy prog env e
  | _ => .unknown

/-- The position in a list of length `len` that the index `i` names. Mojo's
`List` does not count a negative index from the end: it is out of bounds. -/
def position (len : Nat) (i : Int) : EvalM Nat :=
  if 0 ≤ i && i < len then pure i.toNat else fail .indexOutOfBounds

/-- What a variable of type `t` declared without a value holds: the blank
of a struct with fields, whose fields can then be assigned one by one, and
`uninit` for any other type. -/
def blankOf (prog : Program) : Nat → Ty → EvalM Value
  | 0, _ => fail .outOfFuel
  | n + 1, .struct s => do
    let some sd := findStruct prog s | stuck s!"unknown struct {s}"
    if sd.fields.isEmpty then pure .uninit
    else pure (.struct s (← sd.fields.mapM fun (f, t) => do pure (f, ← blankOf prog n t)))
  | _ + 1, _ => pure .uninit

/-- The value of the struct `sd` with no field initialized, as `out self`
starts in `__init__`: each field is the blank of its type. -/
def emptyStruct (prog : Program) (fuel : Nat) (sd : StructDecl) : EvalM Value := do
  pure (.struct sd.name (← sd.fields.mapM fun (f, t) => do pure (f, ← blankOf prog fuel t)))

/-- The number of elements of `range(start, stop, step)`: the `Int`s
`start + k * step`, from `k = 0` up, that come before `stop` in the
direction of `step`. A `step` of 0 gives none. They all lie between `start`
and `stop`, so none wraps around (#121). -/
def rangeLength (start stop step : Int) : Nat :=
  if 0 < step then ((stop - start + step - 1) / step).toNat
  else if step < 0 then ((start - stop - step - 1) / -step).toNat
  else 0

/-- The elements `start + k * step` of a range, for `k` from 0 below `n`,
put in front of `acc`. -/
def rangeElems (start step : Int) : Nat → List Value → List Value
  | 0, acc => acc
  | k + 1, acc => rangeElems start step k (.int (start + (k : Int) * step) :: acc)

/-- The list `range(start, stop, step)` built with the fuel `fuel`. The fuel
bounds the list's length, as it bounds the depth of evaluation: a range
with more elements than `fuel` runs out of it before the list is built, so
that no list too long for any machine is started. -/
def rangeList (fuel : Nat) (start stop step : Int) : EvalM Value := do
  let k := rangeLength start stop step
  if fuel < k then fail .outOfFuel
  pure (.list (rangeElems start step k []))

end MojoGrimoire.Interp
