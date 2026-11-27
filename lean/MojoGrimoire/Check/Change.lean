import MojoGrimoire.Check.Loc

/-!
The changes that the checker records, and the operands it checks again
once every operand of an operation is evaluated.

A call records as changed each place it is passed `mut`, or `ref` when the
place may be changed and is not reached through `q^`, once its operands are
checked; a call that returns a reference passed so changes its origins. That invalidates the references
into the elements of a list that the place holds: the `ref` bindings, and
the operands of an enclosing operation that were located before the call.

A subscript `q[i]` of an array `q` that may change changes `q` too, for
the references into an element of a list inside it (#282): the compiler
calls `__getitem__` with a mutable `self`, which invalidates them. A
`read` parameter, or `q` reached through `p^`, passes an immutable one;
a `ref` parameter passes one that may be mutable. Such a reference bound
with `ref` is invalidated apart (`State.interior`): a store through it is
rejected only when it was invalidated before the store's value. A literal
operand is built only once every operand of its operation is evaluated,
so what its elements read is read late too (`literalLocs`).

Mojo reads a place operand only once every operand of its operation is
evaluated, and so it reads a call that returns a reference, used as a
value, and a reference argument is used during the call. Each such operand
is checked again then: the places it is read from must still be
initialized, and not invalidated by a change recorded after it was
checked.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How many changes the state records so far: where an operand checked
now stands among them. -/
def mark : CheckM Nat := do pure (← get).changes.length

/-- The references bound with `ref` that a change of the place of shape `m`
as a whole invalidates: those into an element of a list that it holds. -/
def invalidatedBy (prog : Program) (m : Shape) : CheckM (List Name) := do
  let mut stale := []
  for v in (← get).vars do
    if let .alias os _ _ _ := v.access then
      for o in os do
        if (splitPlace o).1 == m.1 then
          if invalidates m (← shapeOf prog o) then stale := v.name :: stale
  pure stale

/-- Records that the place `p` is changed as a whole, and invalidates every
reference bound with `ref` into an element of a list that `p` holds: in
the state's `stale`, or, `apart`, in its `interior`. -/
def recordChange (prog : Program) (p : Place) (apart : Bool) : CheckM Unit := do
  for q in resolvePlace (← get).vars p do
    let m ← shapeOf prog q
    let ns ← invalidatedBy prog m
    modify fun s => if apart then { s with interior := union s.interior ns, changes := s.changes ++ [m] }
      else { s with stale := union s.stale ns, changes := s.changes ++ [m] }

/-- Records that the place `p` is changed as a whole (`recordChange`). -/
def changePlace (prog : Program) (p : Place) : CheckM Unit := recordChange prog p false

/-- The access `a` as a subscript sees it (#282): a `ref` parameter, whose
mutability the compiler does not know, as one that may change, and a
reference bound with `ref` as one that may change when it is subscripted
so. -/
def Access.asSubscripted : Access → Access
  | .refParam => .mutable
  | .alias os _ s t => .alias os s s t
  | a => a

/-- Whether a variable held this way is passed to `__getitem__` as a
mutable `self` when it is subscripted (`Access.asSubscripted`). -/
def Access.subscriptsMutable (a : Access) : Bool := a.asSubscripted.canChange

/-- Whether a subscript of the place `p` passes it to `__getitem__` as a
mutable `self`: its variable is so held, and `p` is not reached through
`q^`, which the compiler borrows as a value that cannot be changed. -/
def subscriptsMutable (p : Place) : CheckM Bool := do
  if throughTransfer p then return false
  pure (((← get).vars.find? (·.name == (splitPlace p).1)).any (·.access.subscriptsMutable))

/-- The places among the arguments `args` that a call changes: those passed
`mut`, and those passed `ref` that pass on a mutable reference. A call that
returns a reference changes its origins. -/
def changedArgs (prog : Program) : List Param → List Expr → CheckM (List Place)
  | prm :: prms, a :: args => do
    let rest ← changedArgs prog prms args
    match prm.conv, a with
    | .mutable, .place q => pure (q :: rest)
    | .ref, .place q => if ← passedMutable q then pure (q :: rest) else pure rest
    | .mutable, a | .ref, a =>
      match ← locOf prog a with
      | some (os, m) => pure (if prm.conv == .mutable || m then os ++ rest else rest)
      | none => pure rest
    | _, _ => pure rest
  | _, _ => pure []

/-- Rejects the place `p`, located once `k` changes were recorded, when a
change recorded since then invalidates it. -/
def requireUnchanged (prog : Program) (p : Place) (k : Nat) : CheckM Unit := do
  let s ← get
  let later := s.changes.drop k
  unless later.isEmpty do
    for q in resolvePlace s.vars p do
      let o ← shapeOf prog q
      if later.any (invalidates · o) then flowThrow (CheckError.invalidatedReference p)

/-- The subscript `p[i]`, once its index `i` is evaluated: rejects `p`,
located once `k` changes were recorded, when the index invalidated it
(`requireUnchanged`). When `p` is an array that `subscriptsMutable`,
records that `p` is changed as a whole, and invalidates the references
bound with `ref` into an element of a list that `p` holds, apart (#282). -/
def subscript (prog : Program) (p : Place) (k : Nat) : CheckM Unit := do
  requireUnchanged prog p k
  unless ← subscriptsMutable p do return
  if (← placeTy prog p) matches .array .. then recordChange prog p true

/-- The origins of the call `e` that returns a reference, those of its
origin arguments that are temporaries left out; none for any other
expression. -/
def locsOf (prog : Program) (e : Expr) : CheckM (List Place) := do
  pure (((← locOf prog e).map (·.1)).getD [])

/-- Rejects a place among the operands' locations `ls` that a later operand
left uninitialized or invalidated: Mojo reads a place operand only once
every operand of its operation is evaluated, and a reference argument is
used during the call. Each operand gives the places it is read from, with
how many changes were recorded once it was checked. -/
def recheckLocs (prog : Program) (ls : List (List Place × Nat)) : CheckM Unit :=
  ls.forM fun (ps, k) => ps.forM fun p => do
    let _ ← readPlace prog p
    requireUnchanged prog p k

mutual
/-- The places that the operand `e` is read from once every operand of its
operation is evaluated: a place itself, or the origins of a call that
returns a reference, those of its origin arguments that are temporaries
left out. Mojo reads such a call's reference only then. A subscript that
Mojo reads late reads those of its getter's arguments then, when it calls
the getter (`lateGetter`, #191). -/
def lateLocs (prog : Program) : Expr → CheckM (List Place)
  | .place p => pure [p]
  | .call f args => if lateGetter prog f then lateLocsList prog args else locsOf prog (.call f args)
  | e => locsOf prog e

/-- The places that the operands `es` are read from late (`lateLocs`). -/
def lateLocsList (prog : Program) : List Expr → CheckM (List Place)
  | [] => pure []
  | e :: es => do pure ((← lateLocs prog e) ++ (← lateLocsList prog es))
end

/-- The places that `e`, an element of a literal or an argument, reads late
of its own (`lateLocs`). A literal reads only what a literal `[e]` of an
`Int`, the `Int` `e`, reads (#103): one that is an operand is read as
`literalLocs` says, and one inside a literal is built in its turn, before
the elements after it are evaluated; what else it reads waits for #308. -/
def nestedLocs (prog : Program) : Expr → CheckM (List Place)
  | .list .int [x] => lateLocs prog x
  | .list .. => pure []
  | e => lateLocs prog e

/-- The places that the literal operand `e` reads once every operand of its
operation is evaluated: Mojo builds a literal operand only then (#282), so
what each element reads late (`nestedLocs`) is read then. An operand that
is no literal reads none so. -/
def literalLocs (prog : Program) : Expr → CheckM (List Place)
  | .list _ es => do pure (← es.mapM (nestedLocs prog)).flatten
  | _ => pure []

/-- Rechecks the operands among `es`, read from their `lateLocs`, with
`recheckLocs`. `ks` holds, for each operand, how many changes were recorded
once it was checked. -/
def recheckPlaces (prog : Program) (es : List Expr) (ks : List Nat) : CheckM Unit := do
  recheckLocs prog (← (es.zip ks).mapM fun (e, k) => do pure (← lateLocs prog e, k))

/-- Rechecks the literal operands among `es`, read from their `literalLocs`,
as `recheckLocs` does; `ks` as for `recheckPlaces`. A place that a later
operand transfers, `q^`, may be uninitialized now: the compiler builds the
literal before it takes `q`, so `print([b[0]], b^)` runs, but not before a
call that takes `q^` runs, so `print([b[0]], take(b^))` is rejected. -/
def recheckLiterals (prog : Program) : List Expr → List Nat → CheckM Unit
  | e :: es, k :: ks => do
    let later := es.filterMap fun | .transfer q => some q | _ => none
    for p in ← literalLocs prog e do
      tryCatch (do let _ ← readPlace prog p) fun err => do
        unless err matches .uninitializedUse _ && later.any (overlaps · p) do throw err
      requireUnchanged prog p k
    recheckLiterals prog es ks
  | _, _ => pure ()

/-- Rechecks the arguments `args` of a call once every one is evaluated:
what checking them gave, `ls` (`recheckLocs`), then what a literal among
them reads (`recheckLiterals`). -/
def recheckArgs (prog : Program) (args : List Expr) (ls : List (List Place × Nat)) : CheckM Unit := do
  recheckLocs prog ls
  recheckLiterals prog args (ls.map (·.2))

/-- The places that the first element `e` of an untyped literal is read
from once every element is evaluated: a place itself, or the arguments of
a subscript that Mojo reads late (`lateGetter`), since the getter is called
only then. Any other element is not rechecked, as before #191. -/
def firstElemLocs (prog : Program) : Expr → CheckM (List Place)
  | .place p => pure [p]
  | .call f args => if lateGetter prog f then lateLocsList prog args else pure []
  | _ => pure []

end MojoGrimoire.Check
