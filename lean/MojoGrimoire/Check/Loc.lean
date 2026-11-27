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
it as a value that cannot be changed.
An origin argument may be a temporary, which the compiler keeps alive as
long as the reference (#80): it is left out of the origins, and the
reference may not be changed through it. A `return` rejects it (#366),
and so does a place's index (#377); a subscript read late is never left
out (#378).

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
  | .readOnly | .refParam => false
  | .alias _ m _ _ => m
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
be changed. -/
def passedMutable (p : Place) : CheckM Bool := do
  pure ((← placeMutable p) && !throughTransfer p)

/-- Whether a reference that a callee returns through a parameter of
convention `c` may be changed, when its argument `m` may be: a `mut`
parameter gives a mutable reference, a `ref` parameter one as mutable as its
argument, and a `read` parameter an immutable one. -/
def passOn (c : Conv) (m : Bool) : Bool :=
  match c with
  | .mutable => true
  | .ref => m
  | _ => false

/-- Whether `e` is a subscript that Mojo reads late (`lateGetter`), which
elaboration does not name as a temporary (#378). -/
def lateCall (prog : Program) : Expr → Bool
  | .call f _ => lateGetter prog f
  | .withDrops e _ _ => lateCall prog e
  | _ => false

mutual
/-- The origins of the located operand `e`, and whether it may be changed
through; `none` when `e` is not one, or is a call with an origin argument
that is not one. A call of a name that a variable in scope hides is one,
with no origins, so that checking it as a call rejects it (#176). Unless
`strict` holds, such an argument, a temporary, is skipped instead: the
call then gives the origins of its other origin arguments, and may not be
changed through. A subscript read late is not skipped (#378). -/
def locOfAs (prog : Program) (strict : Bool) : Expr → CheckM (Option (List Place × Bool))
  | .place p => do pure (some (resolvePlace (← get).vars p, ← passedMutable p))
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
        pure (some (resolvePlace (← get).vars p ++ rest, passOn s.conv (← passedMutable p) && mr))
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
        | pure (if strict || lateCall prog a then none else some (rest, false))
      pure (some (qs ++ rest, m && passOn prm.conv mq))
    else pure (some (rest, m))
  | _, _ => pure (some ([], true))
end

/-- The origins of the located operand `e`, and whether it may be changed
through, a temporary origin argument left out (`locOfAs`): the compiler
keeps the temporary alive while the reference is used, and it may not be
changed through it (#80). In a place's index, it is rejected
(`strictOrigins`, #377). -/
def locOf (prog : Program) (e : Expr) : CheckM (Option (List Place × Bool)) := do
  locOfAs prog (← get).strictOrigins e

/-- The name of the function or method that `e` calls; empty for an
expression that is no call. -/
def calleeOf : Expr → Name
  | .call f _ | .method _ f _ => f
  | .withDrops e _ _ => calleeOf e
  | _ => ""

/-- Whether the place `p` is reached through a reference that may point
into a temporary. -/
def throughTemp (p : Place) : CheckM Bool := do
  pure (((← get).vars.find? (·.name == (splitPlace p).1)).any (·.access matches .alias _ _ _ true))

mutual
/-- Whether the located operand `e` may point into a temporary, which its
origins leave out (#80): a reference bound to one, or a call with an origin
argument that is a temporary, when `direct` holds, or that may point into
one. -/
def tempOrigin (prog : Program) (direct : Bool) : Expr → CheckM Bool
  | .place p => throughTemp p
  | .call f args => do
    if (← findVar f).isSome then return false
    match callSig prog f with
    | .ok ⟨_, params, _, some os, _⟩ => tempArgs prog direct os params args
    | _ => pure direct
  | .method p m args => do
    let sig ← tryCatch (do pure (methodSig prog (← placeTy prog p) m args.length).toOption)
      fun _ => pure none
    let some ⟨self, params, _, some os, _⟩ := sig | pure direct
    if self.any (os.contains ·.name) && (← throughTemp p) then return true
    tempArgs prog direct os params args
  | .withDrops e _ _ => tempOrigin prog direct e
  | _ => pure direct

/-- Whether an argument among `args` passed to a parameter among `params`
that the names `os` of a callee's origin name may point into a temporary
(`tempOrigin`). -/
def tempArgs (prog : Program) (direct : Bool) (os : List Name) :
    List Param → List Expr → CheckM Bool
  | prm :: prms, a :: args => do
    if os.contains prm.name && (← tempOrigin prog direct a) then return true
    tempArgs prog direct os prms args
  | _, _ => pure false
end

/-- Whether two places may be the same location or overlap: one is the other
or a field of it. -/
def overlaps (p q : Place) : Bool :=
  let (x, a) := splitPlace p
  let (y, b) := splitPlace q
  x == y && (a.isPrefixOf b || b.isPrefixOf a)

/-- A location passed to a call: the convention it is passed by, the place
reported when it is aliased, the places it may be, whether it is a mutable
location passed to a `ref` parameter (`lent`), and whether it may point
into a temporary (`temp`, `tempOrigin`). -/
structure PassedLoc where
  conv : Conv
  place : Place
  places : List Place
  lent : Bool := false
  temp : Bool := false

/-- The place `p` passed by the convention `c`. A reference counts as every
place it may point into. -/
def passedPlace (c : Conv) (p : Place) : CheckM PassedLoc := do
  pure { conv := c, place := p, places := resolvePlace (← get).vars p }

/-- The arguments among `args` that are passed as locations: every located
operand whose parameter is `read`, `mut` or `ref`, except an `Int` or a
`Bool` passed `read`, which is copied. A call that returns a reference is
reported by its first origin. -/
def locationArgs (prog : Program) : List Param → List Expr → CheckM (List PassedLoc)
  | prm :: prms, a :: args => do
    let rest ← locationArgs prog prms args
    if passedByValue prm then return rest
    let lent (m : Bool) := prm.conv == .ref && m
    match a, ← locOf prog a with
    | .place p, some (_, m) =>
      pure ({ ← passedPlace prm.conv p with lent := lent m, temp := ← tempOrigin prog true a } :: rest)
    | _, some (o :: os, m) =>
      pure ({ conv := prm.conv, place := o, places := o :: os, lent := lent m,
              temp := ← tempOrigin prog true a } :: rest)
    | _, _ => pure rest
  | _, _ => pure []

/-- Rejects a `mut` location among `locs` that overlaps another one, and a
mutable location passed to a `ref` parameter that overlaps another one
when either may point into a temporary. The compiler rejects the latter
when neither does too, but the model does not yet (#381), and so keeps
the programs that reach it through a temporary rejected. -/
def checkExclusive (locs : List PassedLoc) : CheckM Unit :=
  go locs []
where
  /-- Checks each location against those before and after it. -/
  go : List PassedLoc → List PassedLoc → CheckM Unit
    | [], _ => pure ()
    | l :: rest, seen => do
      let clash (o : PassedLoc) := l.places.any fun a => o.places.any (overlaps a)
      let lentClash (o : PassedLoc) := (l.temp || o.temp) && clash o
      if l.conv == .mutable && (seen ++ rest).any clash || l.lent && (seen ++ rest).any lentClash then
        throw (CheckError.argumentExclusivity l.place)
      go rest (l :: seen)

end MojoGrimoire.Check
