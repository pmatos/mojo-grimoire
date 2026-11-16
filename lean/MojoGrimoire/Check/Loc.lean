import MojoGrimoire.Check.State

/-!
Located operands: the expressions that name a location, which an argument
passed by reference passes as it is, without copying it.

A located operand is a place, or a call of a function or a method that
returns a reference, whose origin arguments are located operands in turn:
`len(first(xs))` and `first(first(xs))` read `xs` where it is. Its origins
are the places it may point into: the place itself, or the same place in
each origin of the reference it starts from, or the origins of the arguments
that a call passes to the parameters its origin names, the receiver of a
method among them. It may be changed through when its place may be, or,
for a call, when each origin argument passes on a mutable reference.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether a variable held this way may be changed: assigned to, or passed
`mut`. -/
def Access.canChange : Access → Bool
  | .readOnly => false
  | .alias _ m => m
  | _ => true

/-- Whether the place `p` may be changed through; a place whose variable is
not in scope may not. -/
def placeMutable (p : Place) : CheckM Bool := do
  pure (((← get).vars.find? (·.name == (splitPlace p).1)).any (·.access.canChange))

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
that is not one. -/
def locOf (prog : Program) : Expr → CheckM (Option (List Place × Bool))
  | .place p => do pure (some (resolvePlace (← get).vars p, ← placeMutable p))
  | .call f args =>
    match callSig prog f with
    | .ok ⟨_, params, _, some os, _⟩ => originsOf prog os params args
    | _ => pure none
  | .method p m args => do
    let sig ← tryCatch (do pure (methodSig prog (← placeTy prog p) m args.length).toOption)
      fun _ => pure none
    let some ⟨self, params, _, some os, _⟩ := sig | pure none
    let some (rest, mr) ← originsOf prog os params args | pure none
    match self with
    | some s =>
      if os.contains s.name then
        pure (some (resolvePlace (← get).vars p ++ rest, passOn s.conv (← placeMutable p) && mr))
      else pure (some (rest, mr))
    | none => pure (some (rest, mr))
  | .withDrops e _ _ => locOf prog e
  | _ => pure none

/-- The origins of the arguments `args` passed to the parameters among
`params` that the names `os` of a callee's origin name, and whether the
reference the callee returns may be changed through. -/
def originsOf (prog : Program) (os : List Name) :
    List Param → List Expr → CheckM (Option (List Place × Bool))
  | prm :: prms, a :: args => do
    let some (rest, m) ← originsOf prog os prms args | pure none
    if os.contains prm.name then
      let some (qs, mq) ← locOf prog a | pure none
      pure (some (qs ++ rest, m && passOn prm.conv mq))
    else pure (some (rest, m))
  | _, _ => pure (some ([], true))
end

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

end MojoGrimoire.Check
