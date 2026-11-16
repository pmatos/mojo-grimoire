import MojoGrimoire.Check.Loc

/-!
The changes that the checker records, and the operands it checks again
once every operand of an operation is evaluated.

A call records as changed each place it is passed `mut`, or `ref` when the
place may be changed, once its operands are checked; a call that returns a
reference passed so changes its origins. That invalidates the references
into the elements of a list that the place holds: the `ref` bindings, and
the operands of an enclosing operation that were located before the call.

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

/-- Records that the place `p` is changed as a whole, and invalidates every
reference bound with `ref` into an element of a list that `p` holds. -/
def changePlace (prog : Program) (p : Place) : CheckM Unit := do
  for q in resolvePlace (← get).vars p do
    let m ← shapeOf prog q
    let mut stale := []
    for v in (← get).vars do
      if let .alias os _ := v.access then
        for o in os do
          if (splitPlace o).1 == m.1 && invalidates m (← shapeOf prog o) then
            stale := v.name :: stale
    modify fun s => { s with stale := union s.stale stale, changes := s.changes ++ [m] }

/-- The places among the arguments `args` that a call changes: those passed
`mut`, and those passed `ref` that may be changed. A call that returns a
reference changes its origins. -/
def changedArgs (prog : Program) : List Param → List Expr → CheckM (List Place)
  | prm :: prms, a :: args => do
    let rest ← changedArgs prog prms args
    match prm.conv, a with
    | .mutable, .place q => pure (q :: rest)
    | .ref, .place q =>
      if (← lookup (splitPlace q).1).access.canChange then pure (q :: rest) else pure rest
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
      if later.any (invalidates · o) then throw (CheckError.invalidatedReference p)

/-- Rejects a place among the operands' locations `ls` that a later operand
left uninitialized or invalidated: Mojo reads a place operand only once
every operand of its operation is evaluated, and a reference argument is
used during the call. Each operand gives the places it is read from, with
how many changes were recorded once it was checked. -/
def recheckLocs (prog : Program) (ls : List (List Place × Nat)) : CheckM Unit :=
  ls.forM fun (ps, k) => ps.forM fun p => do
    let _ ← readPlace prog p
    requireUnchanged prog p k

/-- The places that the operand `e` is read from once every operand of its
operation is evaluated: a place itself, or the origins of a call that
returns a reference, those of its origin arguments that are temporaries
left out. Mojo reads such a call's reference only then. -/
def lateLocs (prog : Program) : Expr → CheckM (List Place)
  | .place p => pure [p]
  | e => do pure (((← locOfAs prog false e).map (·.1)).getD [])

/-- Rechecks the operands among `es`, read from their `lateLocs`, with
`recheckLocs`. `ks` holds, for each operand, how many changes were recorded
once it was checked. -/
def recheckPlaces (prog : Program) (es : List Expr) (ks : List Nat) : CheckM Unit := do
  recheckLocs prog (← (es.zip ks).mapM fun (e, k) => do pure (← lateLocs prog e, k))

end MojoGrimoire.Check
