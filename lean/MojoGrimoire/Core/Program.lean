import MojoGrimoire.Core.Equality

/-!
The declarations of the core calculus: functions, structs and programs.

A struct declares its fields, whether its values can be copied, and its
lifecycle methods. Every struct can be moved: Mojo synthesizes a move
initializer for a struct that declares no conformance, and the core
calculus has no immovable struct. Copy and move initializers are always
the synthesized ones.
-/

namespace MojoGrimoire.Core

/-- A parameter: its convention, its name and its type. -/
structure Param where
  conv : Conv
  name : Name
  ty : Ty
  deriving BEq

/-- A function: its name, parameters, result type, body and origin. A
function that returns nothing has the result type `noneType`. A function
whose `origin` is `some os` returns a reference into the values of its
parameters named `os`, Mojo's `-> ref [a, b] T`; one whose origin is `none`
returns a value. A method is a function whose first parameter is `self`; an
initializer is a method whose `self` has the convention `out`. -/
structure FunDecl where
  name : Name
  params : List Param
  result : Ty
  body : List Stmt
  origin : Option (List Name) := none
  deriving BEq

/-- How the values of a struct can be copied: not at all, only with an
explicit `.copy()` (Mojo's `Copyable`), or also implicitly (Mojo's
`ImplicitlyCopyable`). -/
inductive Copying where
  | none
  | explicit
  | implicit
  deriving DecidableEq, Repr

/-- A struct: its name and fields, how its values can be copied, whether it is
`@fieldwise_init`, its optional `__init__`, the body of its optional
`__deinit__(deinit self)`, and its other methods. -/
structure StructDecl where
  name : Name
  fields : List (Name × Ty)
  copying : Copying
  fieldwiseInit : Bool
  init : Option FunDecl
  deinit : Option (List Stmt)
  methods : List FunDecl
  deriving BEq

/-- A member of a struct, where its declaration stands in the source: its
`i`-th field, its `__init__`, its `__deinit__`, or its `i`-th other
method. -/
inductive Member where
  | field (i : Nat)
  | init
  | deinit
  | method (i : Nat)
  deriving BEq, Repr

/-- A declaration of a program, where it stands in the source: its `i`-th
function, or its `i`-th struct, with the order of its members. -/
inductive Decl where
  | func (i : Nat)
  | struct (i : Nat) (members : List Member)
  deriving BEq, Repr

/-- A program: its structs and its functions. It runs by calling `main`.
The parser also records the order of its declarations in the source,
`order`, since the compiler reports some errors in that order (#96). -/
structure Program where
  structs : List StructDecl
  funs : List FunDecl
  order : List Decl := []
  deriving BEq

/-- The order of the members of the struct `sd` when none was recorded:
its fields, then its `__init__`, its `__deinit__` and its other methods. -/
def StructDecl.defaultMembers (sd : StructDecl) : List Member :=
  (List.range sd.fields.length).map .field ++ (sd.init.map fun _ => Member.init).toList ++
    (sd.deinit.map fun _ => Member.deinit).toList ++ (List.range sd.methods.length).map .method

/-- The order of the declarations of the program `prog` in its source, or,
for a program built with no order, such as one built by hand, its structs
and then its functions, each struct's members in `defaultMembers`. Later
passes read the order through it. -/
def Program.declOrder (prog : Program) : List Decl :=
  if prog.order.isEmpty then
    ((List.range prog.structs.length).zip prog.structs).map (fun (i, sd) => .struct i sd.defaultMembers) ++
      (List.range prog.funs.length).map .func
  else prog.order

/-- The destructor of the struct `s`, whose body is `body`, as a function. -/
def deinitDecl (s : Name) (body : List Stmt) : FunDecl :=
  ⟨"__deinit__", [⟨.deinit, "self", .struct s⟩], .noneType, body, none⟩

end MojoGrimoire.Core
