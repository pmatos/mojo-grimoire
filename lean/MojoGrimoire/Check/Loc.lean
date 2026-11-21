import MojoGrimoire.Check.State

/-!
Located operands: the expressions that name a location, which an argument
passed by reference passes as it is, without copying it.

A located operand is a place, or a call of a function or a method that
returns a reference, whose origin arguments are located operands in turn:
`len(first(xs))` and `first(first(xs))` read `xs` where it is. A call of
a name that a variable in scope hides is one with no origins, so that
checking it as a call rejects it (#176). Its origins
are the places it may point into: the place itself, or the same place in
each origin of the reference it starts from, or the origins of the arguments
that a call passes to the parameters its origin names, the receiver of a
method among them. It may be changed through when its place may be, or,
for a call, when each origin argument passes on a mutable reference. A
place reached through `q^` passes on an immutable one: the compiler borrows
it as a value that cannot be changed. So does the element of an `Int`, which
the compiler passes as a temporary (#127).
A reference that a call returns and that is read late is re-checked
through the origins of those of its origin arguments that are located
operands, a temporary among them left out.

A `mut` argument may not alias another argument that is passed as a location,
Mojo's argument exclusivity. An `Int` or a `Bool` passed to a `read`
parameter is not passed as a location: Mojo copies it. A `mut` argument of
any type is.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether a variable held this way may be changed: assigned to, or passed
`mut`. -/
def Access.canChange : Access → Bool
  | .readOnly => false
  | .alias _ m => m
  | _ => true

/-- Whether the variable of the place `p` may be changed through; a place
whose variable is not in scope may not. It ignores `q^`: a `ref` binding to
`q^.f` may change `q.f`, as the compiler allows. A place passed on as an
argument uses `passedMutable`, and a change of the place `requireMutable`. -/
def placeMutable (p : Place) : CheckM Bool := do
  pure (((← get).vars.find? (·.name == (splitPlace p).1)).any (·.access.canChange))

/-- Whether the place `p`, passed to a `ref` parameter or a `ref self`
receiver, passes on a mutable reference: it may be changed through, and is
not reached through `q^`, which the compiler borrows as a value that cannot
be changed, nor through the element of an `Int`, which it passes as a
temporary that cannot be changed (#127). -/
def passedMutable (prog : Program) (p : Place) : CheckM Bool := do
  pure ((← placeMutable p) && !throughTransfer p && !(← intIndexed prog p))

/-- Whether a reference that a callee returns through a parameter of
convention `c` may be changed, when its argument `m` may be: a `mut`
parameter gives a mutable reference, a `ref` parameter one as mutable as its
argument, and a `read` parameter an immutable one. -/
def passOn (c : Conv) (m : Bool) : Bool :=
  match c with
  | .mutable => true
  | .ref => m
  | _ => false

mutual
/-- The origins of the located operand `e`, and whether it may be changed
through; `none` when `e` is not one, or is a call with an origin argument
that is not one. A call of a name that a variable in scope hides is one,
with no origins, so that checking it as a call rejects it (#176). Unless `strict` holds, such an argument, a temporary, is
skipped instead: the call then gives the origins of its other origin
arguments, and may not be changed through. -/
def locOfAs (prog : Program) (strict : Bool) : Expr → CheckM (Option (List Place × Bool))
  | .place p => do pure (some (resolvePlace (← get).vars p, ← passedMutable prog p))
  | .call f args => do
    if (← findVar f).isSome then pure (some ([], false)) else
    match callSig prog f with
    | .ok ⟨_, params, _, some os, _⟩ => originsOf prog strict os params args
    | _ => pure none
  | .method p m args => do
    let sig ← tryCatch (do pure (methodSig prog (← placeTy prog p) m args.length).toOption)
      fun _ => pure none
    let some ⟨self, params, _, some os, _⟩ := sig | pure none
    let some (rest, mr) ← originsOf prog strict os params args | pure none
    match self with
    | some s =>
      if os.contains s.name then
        pure (some (resolvePlace (← get).vars p ++ rest, passOn s.conv (← passedMutable prog p) && mr))
      else pure (some (rest, mr))
    | none => pure (some (rest, mr))
  | .withDrops e _ _ => locOfAs prog strict e
  | _ => pure none

/-- The origins of the arguments `args` passed to the parameters among
`params` that the names `os` of a callee's origin name, and whether the
reference the callee returns may be changed through. -/
def originsOf (prog : Program) (strict : Bool) (os : List Name) :
    List Param → List Expr → CheckM (Option (List Place × Bool))
  | prm :: prms, a :: args => do
    let some (rest, m) ← originsOf prog strict os prms args | pure none
    if os.contains prm.name then
      let some (qs, mq) ← locOfAs prog strict a
        | pure (if strict then none else some (rest, false))
      pure (some (qs ++ rest, m && passOn prm.conv mq))
    else pure (some (rest, m))
  | _, _ => pure (some ([], true))
end

/-- The origins of the located operand `e`, and whether it may be changed
through, with `locOfAs` strict. -/
def locOf (prog : Program) : Expr → CheckM (Option (List Place × Bool)) := locOfAs prog true

/-- The name of the function or method that `e` calls; empty for an
expression that is no call. -/
def calleeOf : Expr → Name
  | .call f _ | .method _ f _ => f
  | .withDrops e _ _ => calleeOf e
  | _ => ""

/-- The origins of the call `e` that returns a reference, and whether it may
be changed through. It rejects the call when an origin argument is not a
located operand: a temporary would not outlive the call. -/
def locatedOrigins (prog : Program) (e : Expr) : CheckM (List Place × Bool) := do
  let some l ← locOf prog e | throw (CheckError.notAPlace (calleeOf e))
  pure l

/-- Whether two places may be the same location or overlap: one is the other
or a field of it. -/
def overlaps (p q : Place) : Bool :=
  let (x, a) := splitPlace p
  let (y, b) := splitPlace q
  x == y && (a.isPrefixOf b || b.isPrefixOf a)

/-- A location passed to a call: the convention it is passed by, the place
reported when it is aliased, and the places it may be. -/
structure PassedLoc where
  conv : Conv
  place : Place
  places : List Place

/-- The place `p` passed by the convention `c`. A reference counts as every
place it may point into. -/
def passedPlace (c : Conv) (p : Place) : CheckM PassedLoc := do
  pure ⟨c, p, resolvePlace (← get).vars p⟩

/-- The arguments among `args` that are passed as locations: every located
operand whose parameter is `read`, `mut` or `ref`, except an `Int` or a
`Bool` passed `read`, which is copied. A call that returns a reference is
reported by its first origin. -/
def locationArgs (prog : Program) : List Param → List Expr → CheckM (List PassedLoc)
  | prm :: prms, a :: args => do
    let rest ← locationArgs prog prms args
    if passedByValue prm then return rest
    match a, ← locOf prog a with
    | .place p, some _ => pure ((← passedPlace prm.conv p) :: rest)
    | _, some (o :: os, _) => pure (⟨prm.conv, o, o :: os⟩ :: rest)
    | _, _ => pure rest
  | _, _ => pure []

/-- Rejects a `mut` location among `locs` that overlaps another one. -/
def checkExclusive (locs : List PassedLoc) : CheckM Unit :=
  go locs []
where
  /-- Checks each location against those before and after it. -/
  go : List PassedLoc → List PassedLoc → CheckM Unit
    | [], _ => pure ()
    | l :: rest, seen => do
      let clash (o : PassedLoc) := l.places.any fun a => o.places.any (overlaps a)
      if l.conv == .mutable && (seen ++ rest).any clash then
        throw (CheckError.argumentExclusivity l.place)
      go rest (l :: seen)

end MojoGrimoire.Check
