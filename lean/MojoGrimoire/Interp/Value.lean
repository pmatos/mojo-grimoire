import MojoGrimoire.Core.Program

/-!
The values of the interpreter, and how a part of a value is read and
replaced.

A value is an `Int`, a `Bool`, a struct with its fields, or a list with its
elements. A field moved out of a struct leaves `uninit` in its place, and a
variable whose value was transferred holds `uninit`. A part of a value is
named by a path of steps: a field of a struct, or an element of a list.
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core

/-- The values. `none` is the result of a call that returns nothing, Mojo's
`None`. `uninit` marks a location, or a part of one, with no value: before
its first assignment, or after its value was moved out. -/
inductive Value where
  | int (value : Int)
  | bool (value : Bool)
  | struct (name : Name) (fields : List (Name × Value))
  | list (elems : List Value)
  | none
  | uninit

/-- A step from a value to one of its parts: a field of a struct, or the
element at an index of a list. -/
inductive Step where
  | field (name : Name)
  | elem (index : Nat)
  deriving DecidableEq, Repr

/-- The part of the value `v` that the path `path` names, if there is one. -/
def Value.get (v : Value) : List Step → Option Value
  | [] => some v
  | .field f :: rest => match v with
    | .struct _ fs => (fs.lookup f).bind (·.get rest)
    | _ => none
  | .elem i :: rest => match v with
    | .list es => es[i]?.bind (·.get rest)
    | _ => none

/-- The value `v` with the part that `path` names replaced by `w`, if there
is such a part. -/
def Value.set (v : Value) (path : List Step) (w : Value) : Option Value :=
  match path with
  | [] => some w
  | .field f :: rest => match v with
    | .struct s fs => do
      let old ← fs.lookup f
      let new ← old.set rest w
      pure (.struct s (fs.map fun (g, u) => if g == f then (g, new) else (g, u)))
    | _ => none
  | .elem i :: rest => match v with
    | .list es => do
      let old ← es[i]?
      let new ← old.set rest w
      pure (.list (es.set i new))
    | _ => none

/-- How `print` writes a value: an `Int` in decimal, a `Bool` as `True` or
`False`. -/
def Value.show : Value → String
  | .int n => toString n
  | .bool true => "True"
  | .bool false => "False"
  | _ => "<value>"

end MojoGrimoire.Interp
