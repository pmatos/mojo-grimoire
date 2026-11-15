import MojoGrimoire.Check.Stmt

/-!
The checking of whole programs: their declarations, and the body of every
function, method, initializer and destructor.

A program is accepted when its names are declared once, its types are
those it declares, no struct contains itself, every function and method
has parameters of the conventions its kind allows, every body is accepted,
and it has a `main` that takes nothing and returns nothing. A rejection
names the first error found, and where.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a function holds a parameter of convention `c`, and which of its
parts are uninitialized on entry: the `self` of `__init__` is wholly
uninitialized, and every other parameter wholly initialized. -/
def paramState (prm : Param) : VarState :=
  match prm.conv with
  | .read | .ref => ⟨prm.name, prm.ty, .readOnly, []⟩
  | .mutable => ⟨prm.name, prm.ty, .mutable, []⟩
  | .owned => ⟨prm.name, prm.ty, .owned, []⟩
  | .out => ⟨prm.name, prm.ty, .constructing, [[]]⟩
  | .deinit => ⟨prm.name, prm.ty, .dying, []⟩

/-- Rejects a list of names that holds a name twice. -/
def checkDistinct : List Name → Except CheckError Unit
  | [] => pure ()
  | x :: xs => if xs.contains x then throw (.duplicate x) else checkDistinct xs

/-- Checks the body of the function `fd`: its parameters and result must
have declarable types, its origin must name parameters passed as locations,
the body must be accepted, and, unless the function returns nothing, every
path through it must return. -/
def checkBody (prog : Program) (fd : FunDecl) : Except CheckError Unit := do
  checkDistinct (fd.params.map (·.name))
  for prm in fd.params do
    unless validTy prog prm.ty do throw (.invalidType prm.ty)
  unless fd.result == .noneType || validTy prog fd.result do throw (.invalidType fd.result)
  checkOrigin fd
  let start : State := ⟨fd.params.reverse.map paramState, true⟩
  let ((), _) ← (do
      checkBlock prog fd fd.body
      if (← get).live then
        unless fd.result == Ty.noneType do throw (CheckError.missingReturn fd.name)
        checkExit prog).run start

/-- Rejects a parameter list in which a parameter has the convention `out` or
`deinit`, which only the `self` of `__init__` and `__deinit__` may have. -/
def checkConventions (fn : Name) (params : List Param) : Except CheckError Unit :=
  for prm in params do
    if prm.conv == .out || prm.conv == .deinit then throw (.invalidConvention fn)

/-- Checks a function. -/
def checkFun (prog : Program) (fd : FunDecl) : Except CheckError Unit := do
  checkConventions fd.name fd.params
  checkBody prog fd

/-- Checks a method of the struct `s`: its first parameter is `self`, of the
struct's type, with the convention `read`, `mut`, `var` or `ref`. -/
def checkMethod (prog : Program) (s : Name) (fd : FunDecl) : Except CheckError Unit := do
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self.name == "self" && self.ty == .struct s do throw (.invalidSelf fd.name)
  if self.conv == .out || self.conv == .deinit then throw (.invalidSelf fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog fd

/-- Checks the initializer of the struct `s`: its first parameter is
`out self`, and it returns nothing. -/
def checkInit (prog : Program) (s : Name) (fd : FunDecl) : Except CheckError Unit := do
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self == ⟨.out, "self", .struct s⟩ do throw (.invalidSelf fd.name)
  unless fd.result == .noneType do throw (.invalidReturn fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog fd

/-- Checks a struct: its fields, its initializer, its destructor and its
methods. A failure is located at `S`, or at `S.m` for a method `m`. -/
def checkStruct (prog : Program) (sd : StructDecl) : Except Rejection Unit := do
  let at_ {α : Type} (where_ : Name) (r : Except CheckError α) : Except Rejection α :=
    r.mapError (⟨where_, ·⟩)
  at_ sd.name do
    checkDistinct (sd.fields.map (·.1) ++ sd.methods.map (·.name))
    for (_, t) in sd.fields do
      unless validTy prog t do throw (.invalidType t)
      if contains prog sd.name prog.structs.length t then throw (.recursiveStruct sd.name)
  if let some fd := sd.init then at_ (sd.name ++ ".__init__") (checkInit prog sd.name fd)
  if let some body := sd.deinit then
    at_ (sd.name ++ ".__deinit__")
      (checkBody prog ⟨"__deinit__", [⟨.deinit, "self", .struct sd.name⟩], .noneType, body, none⟩)
  for fd in sd.methods do
    at_ (sd.name ++ "." ++ fd.name) (checkMethod prog sd.name fd)

/-- Checks a program: it is accepted, or rejected with the first error found
and where it was found. -/
def checkProgram (prog : Program) : Except Rejection Unit := do
  (checkDistinct (prog.structs.map (·.name) ++ prog.funs.map (·.name))).mapError (⟨"", ·⟩)
  for sd in prog.structs do checkStruct prog sd
  for fd in prog.funs do (checkFun prog fd).mapError (⟨fd.name, ·⟩)
  match findFun prog "main" with
  | some fd =>
    unless fd.params.isEmpty && fd.result == .noneType do throw ⟨"main", .noMain⟩
  | none => throw ⟨"", .noMain⟩

end MojoGrimoire.Check
