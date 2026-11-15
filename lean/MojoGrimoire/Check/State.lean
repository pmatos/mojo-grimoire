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
above or below it.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a function holds a variable. `owned` is a local variable or a `var`
parameter; `constructing` the `self` of `__init__`, which starts
uninitialized and must be initialized when the function returns; `mutable` a
`mut` parameter; `readOnly` a `read` or `ref` parameter; and `dying` the
`self` of `__deinit__`, which owns its value and may leave fields moved out. -/
inductive Access where
  | owned
  | constructing
  | mutable
  | readOnly
  | dying
  deriving DecidableEq, Repr

/-- A path of field names, from a variable to one of its parts. -/
abbrev Path := List Name

/-- A variable in scope: its name, type, how it is held, and its
uninitialized parts. -/
structure VarState where
  name : Name
  ty : Ty
  access : Access
  uninit : List Path
  deriving DecidableEq, Repr

/-- The checker's state: the variables in scope, innermost first, and
whether the current point can be reached. After a `return`, it cannot. -/
structure State where
  vars : List VarState
  live : Bool
  deriving DecidableEq, Repr

/-- The monad of the checker: it reads and updates the state, and may reject
the program. -/
abbrev CheckM := StateT State (Except CheckError)

/-- The variable a place starts from, and the path from it to the place. -/
def splitPlace : Place → Name × Path
  | .var x => (x, [])
  | .field p f => let (x, path) := splitPlace p; (x, path ++ [f])

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

/-- Replaces the state of the innermost variable named `x`. -/
def setUninit (x : Name) (us : List Path) : CheckM Unit :=
  modify fun s => { s with vars := go s.vars }
where
  /-- Updates the first variable named `x`. -/
  go : List VarState → List VarState
    | [] => []
    | v :: vs => if v.name == x then { v with uninit := us } :: vs else v :: go vs

/-- The type of a place, given the variables in scope. -/
def placeTy (prog : Program) (p : Place) : CheckM Ty := do
  let (x, path) := splitPlace p
  let v ← lookup x
  path.foldlM (fun t f => liftM (fieldOf prog t f)) v.ty
where
  /-- Lifts a result of the program's tables into the checker. -/
  liftM {α : Type} (r : Except CheckError α) : CheckM α := StateT.lift r

/-- The type of a place that is initialized, so that its value may be read;
it rejects a use of a part that is uninitialized. -/
def readPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← placeTy prog p
  let (x, path) := splitPlace p
  let v ← lookup x
  unless initialized v.uninit path do throw (CheckError.uninitializedUse p)
  pure t

end MojoGrimoire.Check
