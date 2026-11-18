import MojoGrimoire.Core.Program

/-!
The values of the interpreter, and how a part of a value is read and
replaced.

A value is an `Int`, a `Bool`, a struct with its fields, or a list with its
elements. An array is a list value too: its length is fixed by its type,
`Array[T, N]` holding `N` elements, which the checker ensures, so the
interpreter needs no value of its own for it. A location, or a part of
one, that holds no value holds `uninit`, or, when it is of a struct type
with fields, a blank: the struct with each field blank in turn. A blank
keeps the shape of the struct, so that its fields can be assigned one by
one, and destroying it does nothing. A part of a value is named by a path
of steps: a field of a struct, or an element of a list or an array.
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
element at an index of a list or an array. -/
inductive Step where
  | field (name : Name)
  | elem (index : Nat)
  deriving DecidableEq, Repr

/-- The part of the value `v` that the path `path` names, if there is one. -/
def Value.get (v : Value) : List Step → Option Value
  | [] => some v
  | .field f :: rest => match v with
    | .struct _ fs => (fs.lookup f).bind (·.get rest)
    | _ => Option.none
  | .elem i :: rest => match v with
    | .list es => es[i]?.bind (·.get rest)
    | _ => Option.none

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
    | _ => Option.none
  | .elem i :: rest => match v with
    | .list es => do
      let old ← es[i]?
      let new ← old.set rest w
      pure (.list (es.set i new))
    | _ => Option.none

mutual
/-- What is left of the value `v` once it is taken out of its location: the
blank of a struct with fields, and `uninit` for any other value. -/
def Value.blank : Value → Value
  | .struct s fs => if fs.isEmpty then .uninit else .struct s (Value.blankFields fs)
  | _ => .uninit

/-- The fields `fs`, each replaced by its blank. -/
def Value.blankFields : List (Name × Value) → List (Name × Value)
  | [] => []
  | (f, w) :: fs => (f, w.blank) :: Value.blankFields fs
end

mutual
/-- Whether the value `v` holds nothing: `uninit`, or a blank, a struct with
fields that each hold nothing. A struct with no fields holds itself. -/
def Value.empty : Value → Bool
  | .uninit => true
  | .struct _ fs => !fs.isEmpty && Value.emptyFields fs
  | _ => false

/-- Whether each of the fields `fs` holds nothing. -/
def Value.emptyFields : List (Name × Value) → Bool
  | [] => true
  | (_, w) :: fs => w.empty && Value.emptyFields fs
end

/-- How `print` writes a value: an `Int` in decimal, a `Bool` as `True` or
`False`, and a list or an array as its elements between brackets,
separated by `, `. -/
def Value.show : Value → String
  | .int n => toString n
  | .bool true => "True"
  | .bool false => "False"
  | .list es => "[" ++ ", ".intercalate (es.map Value.show) ++ "]"
  | _ => "<value>"

end MojoGrimoire.Interp
