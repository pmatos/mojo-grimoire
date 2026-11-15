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

/-- A program: its structs and its functions. It runs by calling `main`. -/
structure Program where
  structs : List StructDecl
  funs : List FunDecl
  deriving BEq

end MojoGrimoire.Core
