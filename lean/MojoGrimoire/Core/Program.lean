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

/-- A program: its structs and its functions. It runs by calling `main`.
Inference also gives it the bodies that `main`'s inference gave, as
functions, each with the struct it belongs to, or none for a free
function, `twin`, for the checker's bridge to `main`'s order
(`MojoGrimoire.Check.bridgedToTwin`); `mainMode` holds in the program that
infers and checks as `main` did. -/
structure Program where
  structs : List StructDecl
  funs : List FunDecl
  mainMode : Bool := false
  twin : Thunk (List (Option Name × FunDecl)) := Thunk.pure []

/-- Two programs are equal when their structs, functions and mode are.
The twin, a thunk, is not compared: forcing it would infer it. Inference
gives it from the same source as the functions, but elaboration and the
stripping of tests change the functions and keep the twin, so two
programs equal so may differ in their twins. -/
instance instBEqProgram : BEq Program :=
  ⟨fun a b => a.structs == b.structs && a.funs == b.funs && a.mainMode == b.mainMode⟩

/-- The destructor of the struct `s`, whose body is `body`, as a function. -/
def deinitDecl (s : Name) (body : List Stmt) : FunDecl :=
  ⟨"__deinit__", [⟨.deinit, "self", .struct s⟩], .noneType, body, none⟩

/-- The program `prog`, inferred and checked as `main` did. -/
def Program.asMain (prog : Program) : Program := { prog with mainMode := true }

/-- The body that `main`'s inference gave the function `fd` of the
program `prog`, a member of the struct `owner`, or a free function when
`owner` is none, from its `twin`: the twin of the same owner, name and
parameters, so that a free function never stands for a method. Empty
when it has none. -/
def Program.twinBody (prog : Program) (owner : Option Name) (fd : FunDecl) : List Stmt :=
  ((prog.twin.get.find? fun (o, t) => o == owner && t.name == fd.name && t.params == fd.params).map
    (·.2.body)).getD []

end MojoGrimoire.Core
