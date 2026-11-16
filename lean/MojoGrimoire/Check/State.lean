import MojoGrimoire.Check.Env

/-!
What the checker knows at each point of a function body: the variables in
scope, how the function holds each one, and which parts of each are
initialized.

A part of a variable is a path of field names from the variable: the empty
path is the whole variable, and `[f, g]` is its field `f.g`. The state of a
variable is the list of its uninitialized parts. An initialized variable has
none, and one that is declared without a value, or whose value was
transferred, has the whole variable, the empty path. Moving a field out adds
that field's path. A part is initialized when no uninitialized part is
above or below it. The elements of a list or an array are not parts: they
are initialized whenever the list or array is.

A variable also records the fields moved out of it with `^` that it has not
been given again. The compiler cannot destroy a struct with such a field
missing, nor overwrite it, so the variable may not end, and no part above
such a field may be assigned, until that same field is assigned again.
Assigning its sub-fields one by one does not count: until then, the field
and the parts above it may not be read whole.

A reference into an element of a list is invalidated when the list, or a
place that holds it, is changed as a whole: assigned, or passed `mut`, or
`ref` from a place that may be changed, which includes the list methods
`append` and `pop`. Changing one element does not invalidate it, and an
array's elements are not invalidated by changes to the array, since an array holds them in place. The state
records the references bound with `ref` that are invalidated, and the
changes made so far in the current statement, so that an operand located
before a later operand changes its list is found too.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a function holds a variable. `owned` is a local variable or a `var`
parameter; `constructing` the `self` of `__init__`, which starts
uninitialized and must be initialized when the function returns; `mutable` a
`mut` parameter; `readOnly` a `read` or `ref` parameter; and `dying` the
`self` of `__deinit__`, which owns its value and may leave fields moved out.
`alias os m` is a reference bound with `ref`: it points into the places `os`,
and may be changed when `m` holds. -/
inductive Access where
  | owned
  | constructing
  | mutable
  | readOnly
  | dying
  | alias (origins : List Place) (mutable : Bool)
  deriving BEq

/-- A path of field names, from a variable to one of its parts. -/
abbrev Path := List Name

/-- A variable in scope: its name, type, how it is held, its
uninitialized parts, and the fields moved out of it that it has not been
given again. -/
structure VarState where
  name : Name
  ty : Ty
  access : Access
  uninit : List Path
  moved : List Path
  deriving BEq

/-- A step from a place down to a part of it, with indices left out: a
field, an element of a list, or an element of an array. -/
inductive ShapeStep where
  | field (f : Name)
  | listElem
  | arrayElem
  deriving BEq

/-- What a place names with its indices left out: the variable it starts
from, and the steps down from it. -/
abbrev Shape := Name × List ShapeStep

/-- The checker's state: the variables in scope, innermost first, whether
the current point can be reached, the references bound with `ref` that are
invalidated, and the places changed as a whole so far in the current
statement, in order. After a
`return`, the current point cannot be reached. -/
structure State where
  vars : List VarState
  live : Bool
  stale : List Name
  changes : List Shape
  deriving BEq

/-- The monad of the checker: it reads and updates the state, and may reject
the program. -/
abbrev CheckM := StateT State (Except CheckError)

/-- The variable a place starts from, and the path from it to the place.
The elements of a list or an array are not parts that the checker follows:
the path to a place inside an element stops at the list or array. -/
def splitPlace : Place → Name × Path
  | .var x => (x, [])
  | .field p f => let (x, path) := splitPlace p; if indexed p then (x, path) else (x, path ++ [f])
  | .index p _ => splitPlace p
where
  /-- Whether the place goes through an element of a list or an array. -/
  indexed : Place → Bool
    | .var _ => false
    | .field p _ => indexed p
    | .index _ _ => true

/-- The place of the part `path` of the variable `x`: the inverse of
`splitPlace` for a place that goes through no element. -/
def partPlace (x : Name) (path : Path) : Place := path.foldl .field (.var x)

/-- The parts among `us` strictly below the part `q`, as paths from `q`. -/
def below (q : Path) (us : List Path) : List Path :=
  (us.filter fun u => q.isPrefixOf u && u != q).map (·.drop q.length)

/-- The union of two lists, as sets. -/
def union {α : Type} [BEq α] (a b : List α) : List α := a ++ b.filter (!a.contains ·)

/-- Whether the part `q` of a variable whose uninitialized parts are `us` is
initialized: no uninitialized part is above or below it. -/
def initialized (us : List Path) (q : Path) : Bool :=
  us.all fun u => !(u.isPrefixOf q || q.isPrefixOf u)

/-- The uninitialized parts once the part `q` is uninitialized too: parts
below `q` are subsumed by it. -/
def uninitialize (us : List Path) (q : Path) : List Path :=
  if us.any (·.isPrefixOf q) then us else q :: us.filter (!q.isPrefixOf ·)

/-- The type of the part `path` of a value of type `t`, or `None` when the
path does not name a part. -/
def partTy (prog : Program) (t : Ty) : Path → Ty
  | [] => t
  | f :: rest => match fieldOf prog t f with
    | .ok ft => partTy prog ft rest
    | .error _ => .noneType

/-- The uninitialized parts that remain of a part of type `t` when its part
`rest` is initialized and the others are not: for each field on the way
down, the other fields of its struct. -/
def remainder (prog : Program) (t : Ty) : Path → List Path
  | [] => []
  | f :: rest =>
    let others := (fieldNames prog t).filter (· != f) |>.map ([·])
    let ft := match fieldOf prog t f with
      | .ok ft => ft
      | .error _ => .noneType
    others ++ (remainder prog ft rest).map (f :: ·)

/-- The uninitialized parts once the part `q`, of a variable of type `t`, is
initialized. Parts below `q` are initialized with it. An uninitialized part
`u` above `q` is split: `u` is replaced by the parts of `u` that are not on
the way down to `q`, which stay uninitialized. -/
def initPart (prog : Program) (us : List Path) (t : Ty) (q : Path) : List Path :=
  let us := us.filter (!q.isPrefixOf ·)
  match us.find? (·.isPrefixOf q) with
  | none => us
  | some u =>
    us.erase u ++ (remainder prog (partTy prog t u) (q.drop u.length)).map (u ++ ·)

/-- The variable named `x` that is innermost in scope. -/
def lookup (x : Name) : CheckM VarState := do
  let some v := (← get).vars.find? (·.name == x) | throw (CheckError.unknownVariable x)
  pure v

/-- Replaces the innermost variable named as `v` by `v`. -/
def setVar (v : VarState) : CheckM Unit :=
  modify fun s => { s with vars := go s.vars }
where
  /-- Replaces the first variable with `v`'s name. -/
  go : List VarState → List VarState
    | [] => []
    | w :: ws => if w.name == v.name then v :: ws else w :: go ws

/-- The type of the elements of a list or an array of type `t`. -/
def elemOf : Ty → Except CheckError Ty
  | .list t | .array t _ => pure t
  | t => throw (.notAList t)

/-- The type of a place, given the variables in scope. -/
def placeTy (prog : Program) : Place → CheckM Ty
  | .var x => do pure (← lookup x).ty
  | .field p f => do liftM (fieldOf prog (← placeTy prog p) f)
  | .index p _ => do liftM (elemOf (← placeTy prog p))
where
  /-- Lifts a result of the program's tables into the checker. -/
  liftM {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- The place `p` with the variable it starts from replaced by the place
`o`. -/
def rebase (o : Place) : Place → Place
  | .var _ => o
  | .field p f => .field (rebase o p) f
  | .index p i => .index (rebase o p) i

/-- The places that the place `p` may be, given the variables `vars`: for a
place reached through a reference, the same place in each of its origins,
or `p` itself. -/
def resolvePlace (vars : List VarState) (p : Place) : List Place :=
  match vars.find? (·.name == (splitPlace p).1) with
  | some ⟨_, _, .alias os _, _, _⟩ => os.map (rebase · p)
  | _ => [p]

/-- The shape of the place `p`. -/
def shapeOf (prog : Program) : Place → CheckM Shape
  | .var x => pure (x, [])
  | .field p f => do
    let (x, steps) ← shapeOf prog p
    pure (x, steps ++ [.field f])
  | .index p _ => do
    let (x, steps) ← shapeOf prog p
    let step := if let .list _ := ← placeTy prog p then ShapeStep.listElem else .arrayElem
    pure (x, steps ++ [step])

/-- Whether changing the place of shape `m` as a whole invalidates a
reference into the place of shape `o`: `o` is inside an element of a list
that `m` holds. -/
def invalidates (m o : Shape) : Bool :=
  m.1 == o.1 && m.2.isPrefixOf o.2 && (o.2.drop m.2.length).contains .listElem

/-- Rejects unless the place `p` of the variable `v` is initialized, with no
field moved out at or below it: a field moved out and refilled one
sub-field at a time is still not whole. -/
def requireInit (v : VarState) (p : Place) : CheckM Unit := do
  let q := (splitPlace p).2
  unless initialized v.uninit q && !v.moved.any (q.isPrefixOf ·) do
    throw (CheckError.uninitializedUse p)

/-- The type of a place that is initialized, so that its value may be read;
it rejects a use of a part that is uninitialized. A place reached through a
reference needs the reference still valid, and every place it may point
into initialized. -/
def readPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← placeTy prog p
  let v ← lookup (splitPlace p).1
  match v.access with
  | .alias os _ =>
    if (← get).stale.contains v.name then throw (CheckError.invalidatedReference p)
    for o in os do requireInit (← lookup (splitPlace o).1) o
  | _ => requireInit v p
  pure t

end MojoGrimoire.Check
