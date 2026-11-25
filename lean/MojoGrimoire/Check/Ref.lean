import MojoGrimoire.Check.Expr

/-!
The checking of references: what a `ref` binding or a returned reference may
point into, and whether it may be changed.

A reference is bound with `ref x = e`, where `e` is a located operand
(`MojoGrimoire.Check.locOf`): a place, or a call of a function or method
that returns a reference. Its origins are the places it may point into: the
place itself, or the origins of the arguments, a method's receiver
included, passed to the parameters that the callee's origin names. A
reference may be changed only when every origin may be, and a use of it
needs every origin initialized, so a value cannot be moved away and then
used through a reference to it.

A function returns a reference within its own origin: each origin of the
returned reference is a parameter the origin names, or an element of an
array, at any depth, of one. The compiler gives a field and an element of a
list an origin of their own.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The type, origins and mutability of the reference that `e` names, in
the function `fn`: a place, or a call of a function or method that returns
a reference. A call of a name that a variable in scope hides is checked as
a call, which rejects it (#176). A place through the element of an `Int`
has no memory origin (`escapingReference`), which the compiler finds once
it has typed the place, and, in a `return`, compared its type with the
result type `expected`, before any later error (#127). -/
def refTarget (prog : Program) (fn : Name) (e : Expr) (expected : Option Ty := none) :
    CheckM (Ty × List Place × Bool) := do
  let located : CheckM (Ty × List Place × Bool) := do
    let t ← checkExprAs prog true e
    let (origins, m) ← locatedOrigins prog e
    pure (t, origins, m)
  match e with
  | .place p =>
    if ← intIndexed prog p then
      typePlace prog p
      if let some r := expected then expect r (← placeTy prog p)
      throw (CheckError.escapingReference fn)
    checkIndices prog p
    let t ← readPlace prog p
    pure (t, resolvePlace (← get).vars p, ← placeMutable p)
  | .call f _ =>
    if (← findVar f).isSome then located else
    let .ok ⟨_, _, _, some _, _⟩ := callSig prog f | throw CheckError.notAReference
    located
  | .method p m args =>
    let .ok ⟨_, _, _, some _, _⟩ := methodSig prog (← placeTy prog p) m args.length
      | throw CheckError.notAReference
    located
  | _ => throw CheckError.notAReference

/-- Whether a reference bound to `e` with `ref` is subscripted as one that
may change: whether it may be changed, as `refTarget` finds, with each
variable's access as a subscript sees it. The compiler does not know the
mutability of a `ref` parameter, so it subscripts a reference to one as
one that may change, though the reference may not be changed through. -/
def refSubscripts (prog : Program) (e : Expr) : CheckM Bool := do
  let s ← get
  set { s with vars := s.vars.map fun (v : VarState) => { v with access := v.access.asSubscripted } }
  let r ← match e with
    | .place p => placeMutable p
    | e => do pure (((← locOf prog e).map (·.2)).getD false)
  set s
  pure r

/-- Whether a returned reference to the place `o` stays within the origin
`os`: with its indices into arrays left out, `o` is a parameter that `os`
names. The compiler gives a field and an element of a list an origin of
their own, while an element of an array stays within the array's. -/
def withinOrigin (prog : Program) (os : List Name) (o : Place) : CheckM Bool := do
  let (x, steps) ← shapeOf prog o
  pure (os.contains x && steps.all (· == .arrayElem))

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
