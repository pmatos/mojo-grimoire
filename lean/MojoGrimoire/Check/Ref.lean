import MojoGrimoire.Check.Expr

/-!
The checking of references: what a `ref` binding or a returned reference may
point into, and whether it may be changed.

A reference is bound with `ref x = e`, where `e` is a place or a call of a
function that returns a reference. Its origins are the places it may point
into: the place itself, or the arguments passed to the parameters that the
function's origin names. A reference may be changed only when every origin
may be, and a use of it needs every origin initialized, so a value cannot be
moved away and then used through a reference to it.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether the place `p` may be changed through. -/
def placeMutable (p : Place) : CheckM Bool := do
  pure (← lookup (splitPlace p).1).access.canChange

/-- The origins of a reference returned by a call, and whether it may be
changed, given the parameters `params`, the arguments `args`, and the names
`os` of the function's origin. An argument passed to an origin parameter must
be a place: a temporary would not outlive the call. A `mut` parameter gives a
mutable reference, a `ref` parameter one as mutable as its argument, and a
`read` parameter an immutable one. -/
def callOrigins (callee : Name) (os : List Name) :
    List Param → List Expr → CheckM (List Place × Bool)
  | prm :: prms, a :: args => do
    let (rest, m) ← callOrigins callee os prms args
    if os.contains prm.name then
      let .place q := a | throw (CheckError.notAPlace callee)
      let mq ← match prm.conv with
        | .mutable => pure true
        | .ref => placeMutable q
        | _ => pure false
      pure (resolvePlace (← get).vars q ++ rest, m && mq)
    else pure (rest, m)
  | _, _ => pure ([], true)

/-- The type, origins and mutability of the reference that `e` names: a
place, or a call of a function or method that returns a reference. -/
def refTarget (prog : Program) (e : Expr) : CheckM (Ty × List Place × Bool) := do
  match e with
  | .place p =>
    checkIndices prog p
    let t ← readPlace prog p
    pure (t, resolvePlace (← get).vars p, ← placeMutable p)
  | .call f args =>
    let some fd := (findStruct prog f).elim (findFun prog f) (fun _ => none)
      | throw CheckError.notAReference
    let some os := fd.origin | throw CheckError.notAReference
    let t ← checkExprAs prog true e
    let (origins, m) ← callOrigins f os fd.params args
    pure (t, origins, m)
  | .method p m args =>
    let .struct s ← placeTy prog p | throw CheckError.notAReference
    let some fd := (findStruct prog s).bind (findMethod · m) | throw CheckError.notAReference
    let some os := fd.origin | throw CheckError.notAReference
    let t ← checkExprAs prog true e
    let (origins, mut_) ← callOrigins m os fd.params (.place p :: args)
    pure (t, origins, mut_)
  | _ => throw CheckError.notAReference

/-- Rejects a function whose origin is not made of its parameters passed as
locations, `read`, `mut` or `ref`, or that returns a reference to nothing. -/
def checkOrigin (fd : FunDecl) : Except CheckError Unit := do
  let some os := fd.origin | pure ()
  if fd.result == .noneType then throw (.invalidOrigin fd.name)
  for o in os do
    match fd.params.find? (·.name == o) with
    | some prm =>
      unless prm.conv == .read || prm.conv == .mutable || prm.conv == .ref do
        throw (.invalidOrigin fd.name)
    | none => throw (.invalidOrigin fd.name)

end MojoGrimoire.Check
