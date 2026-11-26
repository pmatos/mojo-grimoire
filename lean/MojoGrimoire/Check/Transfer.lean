import MojoGrimoire.Check.Change

/-!
Reading a place as a value, and transferring the value out of it, Mojo's
`p^`. A read copies the value implicitly, unless the place's location is
used, as a comparison of arrays or lists uses its operands (#166, #185).
A transfer needs a value with an origin of its own, initialized, in a
variable that the function owns or holds `mut`, and leaves the place
uninitialized.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Rejects an implicit copy of a value of the type `t`, unless it is
implicitly copyable, while copies are checked (`copyChecks`). -/
def requireImplicitCopy (prog : Program) (t : Ty) : CheckM Unit := do
  if (← get).copyChecks && copyingOf prog t != .implicit then throw (CheckError.implicitCopy t)

/-- Reads the place `p` as a value, which copies it implicitly
(`requireImplicitCopy`). -/
def copyPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  requireImplicitCopy prog t
  pure t

/-- Reads the place `p` by reference, uncopied, when `asRef` holds, and
copies it otherwise (`copyPlace`). -/
def usePlace (prog : Program) (asRef : Bool) (p : Place) : CheckM Ty :=
  if asRef then readPlace prog p else copyPlace prog p

/-- Whether the value in the place `p` has no origin of its own, so that
`p^` cannot transfer it out: `p` goes through an element of a list or an
array, which would be left with a hole, or is reached through a reference
bound with `ref`, mutable or not. -/
def noOwnOrigin (p : Place) : CheckM Bool := do
  pure (splitPlace.indexed p || (← lookup (splitPlace p).1).access matches .alias ..)

/-- Rejects unless the value in the place `p` may be transferred out, and
gives its type. It must have an origin of its own (`noOwnOrigin`), checked
before anything else, be initialized, and the function must own it, or
hold it `mut`: a `read` or `ref` parameter cannot give its value away. -/
def requireTransferable (prog : Program) (p : Place) : CheckM Ty := do
  let _ ← placeTy prog p
  if ← noOwnOrigin p then throw (CheckError.transferFromElement p)
  let t ← readPlace prog p
  unless (← lookup (splitPlace p).1).access.canChange do
    throw (CheckError.transferFromBorrowed p)
  pure t

/-- Transfers the value out of the place `p`, Mojo's `p^`, which leaves `p`
uninitialized and holding nothing, with no pieces. It is recorded as moved,
and a part held whole above it as touched. In Mojo, `p^` of an `Int` or a
`Bool` is the place `p`, which inference puts in its stead. -/
def transferPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← requireTransferable prog p
  let (x, path) := splitPlace p
  let v ← lookup x
  setVar { v with uninit := uninitialize v.uninit path, moved := path :: v.moved,
                  held := initPart prog v.held v.ty path,
                  touched := union (v.touched.filter fun c =>
                      (c == path && !path.isEmpty) || !path.isPrefixOf c) (above path v.held),
                  pieces := v.pieces.filter (!path.isPrefixOf ·) }
  pure t

end MojoGrimoire.Check
