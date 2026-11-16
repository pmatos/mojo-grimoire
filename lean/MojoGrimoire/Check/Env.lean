import MojoGrimoire.Check.Errors

/-!
What the checker looks up in a program: its structs and functions, the
fields and methods of a struct, and how the values of a type are copied and
destroyed.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The struct named `s`, if the program declares one. -/
def findStruct (prog : Program) (s : Name) : Option StructDecl :=
  prog.structs.find? (·.name == s)

/-- The function named `f`, if the program declares one. -/
def findFun (prog : Program) (f : Name) : Option FunDecl :=
  prog.funs.find? (·.name == f)

/-- The type of the field `f` of the struct `sd`, if it has one. -/
def fieldTy (sd : StructDecl) (f : Name) : Option Ty :=
  (sd.fields.find? (·.1 == f)).map (·.2)

/-- The method named `m` of the struct `sd`, if it has one. -/
def findMethod (sd : StructDecl) (m : Name) : Option FunDecl :=
  sd.methods.find? (·.name == m)

/-- How the values of the type `t` can be copied. `Int` and `Bool` are
implicitly copyable, as in Mojo; a list or an array only explicitly, with
`.copy()`, and only when its elements can be copied; string literals and
`None` are never copied. -/
def copyingOf (prog : Program) : Ty → Copying
  | .int | .bool => .implicit
  | .struct s => (findStruct prog s).elim .none (·.copying)
  | .list t | .array t _ => if copyingOf prog t == .none then .none else .explicit
  | .str | .noneType => .none

/-- Whether the type `t` is a struct with a `__deinit__` of its own. -/
def hasDeinit (prog : Program) : Ty → Bool
  | .struct s => (findStruct prog s).any (·.deinit.isSome)
  | _ => false

/-- The type of the field `f` of a value of type `t`. -/
def fieldOf (prog : Program) (t : Ty) (f : Name) : Except CheckError Ty :=
  match t with
  | .struct s => do
    let some sd := findStruct prog s | throw (.unknownStruct s)
    let some ft := fieldTy sd f | throw (.unknownField s f)
    pure ft
  | t => throw (.typeMismatch (.struct "") t)

/-- The names of the fields of a value of type `t`: none unless `t` is a
struct. -/
def fieldNames (prog : Program) : Ty → List Name
  | .struct s => (findStruct prog s).elim [] (·.fields.map (·.1))
  | _ => []

/-- Whether a variable or parameter may be declared with the type `t`:
`Int`, `Bool`, a struct of the program, or a list or an array of such
values. -/
def validTy (prog : Program) : Ty → Bool
  | .int | .bool => true
  | .struct s => (findStruct prog s).isSome
  | .list t | .array t _ => validTy prog t
  | .str | .noneType => false

/-- Whether the type `t` contains, through the fields of its structs, the
struct `s`. A list holds its elements apart from the value that holds the
list, so a list of `s` does not count; an array holds them inline, so an
array of `s` does. `fuel` bounds the depth of the search; the number of structs of
the program is enough, since a deeper chain repeats a struct. -/
def contains (prog : Program) (s : Name) : Nat → Ty → Bool
  | 0, _ => false
  | fuel + 1, .struct t =>
    t == s || (findStruct prog t).any fun sd =>
      sd.fields.any fun (_, ft) => contains prog s fuel ft
  | fuel + 1, .array t _ => contains prog s fuel t
  | _, _ => false

end MojoGrimoire.Check
