import MojoGrimoire.Check.Change

/-!
Reading a place as a value, and transferring the value out of it, Mojo's
`p^`. A read copies the value implicitly. A transfer needs a value with an
origin of its own, initialized, in a variable that the function owns or
holds `mut`, and leaves the place uninitialized.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Reads the place `p` as a value, which copies it implicitly: only an
implicitly copyable value may be. -/
def copyPlace (prog : Program) (p : Place) : CheckM Ty := do
  let t ← readPlace prog p
  unless copyingOf prog t == .implicit do throw (CheckError.implicitCopy t)
  pure t

/-- Whether the value in the place `p` has no origin of its own, so that
`p^` cannot transfer it out: `p` goes through an element of a list or an
array, which would be left with a hole, or is reached through a reference
bound with `ref`, mutable or not. -/
def noOwnOrigin (p : Place) : CheckM Bool := do
  pure (splitPlace.indexed p || (← lookup (splitPlace p).1).access matches .alias ..)

/-- Whether the compiler reports the error `e` in a later pass than a
transfer with no origin of its own: a use of an uninitialized or
invalidated value, and a constant index out of range (#119). -/
def CheckError.late : CheckError → Bool
  | .uninitializedUse _ | .invalidatedReference _ | .negativeIndex _
  | .constantIndexOutOfBounds _ => true
  | _ => false

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
