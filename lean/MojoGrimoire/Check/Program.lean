import MojoGrimoire.Check.Block

/-!
The checking of whole programs: their declarations, and the body of every
function, method, initializer and destructor.

A program is accepted when its names are declared once, its types are
those it declares, no struct lies on a cycle of fields that the fixed compiler
rejects, every function and method has parameters of the conventions its
kind allows, every operator method that inference calls takes as many
operands as its operator, every body is accepted, every field of a struct that declares `Copyable`
or `ImplicitlyCopyable` can be copied so, and it has a `main` that takes
nothing and returns nothing. The checker checks all of it in the type
phase, then in the flow phase, and a rejection names the first error
found, and where.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a function holds a parameter of convention `c`, and which of its
parts are uninitialized on entry: the `self` of `__init__` is wholly
uninitialized, and every other parameter wholly initialized. -/
def paramState (prm : Param) : VarState :=
  match prm.conv with
  | .read | .ref => ⟨prm.name, prm.ty, .readOnly, [], [], [[]], [], []⟩
  | .mutable => ⟨prm.name, prm.ty, .mutable, [], [], [[]], [], []⟩
  | .owned => ⟨prm.name, prm.ty, .owned, [], [], [[]], [], []⟩
  | .out => ⟨prm.name, prm.ty, .constructing, [[]], [], [], [], []⟩
  | .deinit => ⟨prm.name, prm.ty, .dying, [], [], [[]], [], []⟩

/-- Rejects a list of names that holds a name twice. -/
def checkDistinct : List Name → Except CheckError Unit
  | [] => pure ()
  | x :: xs => if xs.contains x then throw (.duplicate x) else checkDistinct xs

/-- Checks the body of the function `fd`, a member of the struct `owner`
or a free function when `owner` is none: its parameters and result must
have declarable types, its origin must name parameters passed as locations,
the body must be accepted, checked beside the body that `main`'s inference
gave it (`Program.twinBody`), and, unless the function returns nothing,
every path through it must return. It is checked in the phase `phase`. -/
def checkBody (prog : Program) (phase : Phase) (owner : Option Name) (fd : FunDecl) :
    Except CheckError Unit := do
  checkDistinct (fd.params.map (·.name))
  for prm in fd.params do
    unless validTy prog prm.ty do throw (typeError prm.ty)
  unless fd.result == .noneType || validTy prog fd.result do throw (typeError fd.result)
  checkOrigin fd
  let start : State :=
    { vars := fd.params.reverse.map paramState, live := true, stale := [], changes := [], phase }
  let ((), _) ← (do
      checkBlock prog fd fd.body (Thunk.mk fun _ => prog.twinBody owner fd)
      if (← get).live then
        unless fd.result == Ty.noneType do flowCheck (throw (CheckError.missingReturn fd.name))
        checkExit prog).run start

/-- Rejects a parameter list in which a parameter has the convention `out` or
`deinit`, which only the `self` of `__init__` and `__deinit__` may have. -/
def checkConventions (fn : Name) (params : List Param) : Except CheckError Unit :=
  for prm in params do
    if prm.conv == .out || prm.conv == .deinit then throw (.invalidConvention fn)

/-- Checks a function. -/
def checkFun (prog : Program) (phase : Phase) (fd : FunDecl) : Except CheckError Unit := do
  checkConventions fd.name fd.params
  checkBody prog phase none fd

/-- The number of operands, `self` among them, that the operator method
`m` takes, for the operator methods that inference calls (#191): two for
a binary, reflected or in-place operator, one for `__neg__` and
`__bool__`. -/
def operatorArity (m : Name) : Option Nat :=
  if m == "__neg__" || m == "__bool__" then some 1
  else if ["__add__", "__sub__", "__mul__", "__floordiv__", "__mod__", "__lt__", "__le__",
      "__gt__", "__ge__", "__eq__", "__ne__", "__radd__", "__rsub__", "__rmul__",
      "__rfloordiv__", "__rmod__", "__iadd__", "__isub__", "__imul__"].contains m then some 2
  else none

/-- Checks a method of the struct `s`: an operator method takes as many
operands as its operator, which the compiler checks when it parses the
declaration (`operatorArity`); its first parameter is `self`, of the
struct's type, with the convention `read`, `mut`, `var` or `ref`. -/
def checkMethod (prog : Program) (phase : Phase) (s : Name) (fd : FunDecl) :
    Except CheckError Unit := do
  if let some n := operatorArity fd.name then
    unless fd.params.length == n do throw (.arityMismatch fd.name n fd.params.length)
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self.name == "self" && self.ty == .struct s do throw (.invalidSelf fd.name)
  if self.conv == .out || self.conv == .deinit then throw (.invalidSelf fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog phase (some s) fd

/-- Checks the initializer of the struct `s`: its first parameter is
`out self`, and it returns nothing. -/
def checkInit (prog : Program) (phase : Phase) (s : Name) (fd : FunDecl) :
    Except CheckError Unit := do
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self == ⟨.out, "self", .struct s⟩ do throw (.invalidSelf fd.name)
  unless fd.result == .noneType do throw (.invalidReturn fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog phase (some s) fd

/-- Checks a struct's own declaration: its names and its fields. A failure
is located at `S`. -/
def checkFields (prog : Program) (sd : StructDecl) : Except Rejection Unit :=
  Except.mapError (⟨sd.name, ·⟩) do
    checkDistinct (sd.fields.map (·.1) ++ sd.methods.map (·.name))
    for (_, t) in sd.fields do
      unless validTy prog t do throw (.invalidType t)
      if rejectedCycle prog sd.name t then throw (.recursiveStruct sd.name)

/-- Checks a struct's initializer, its destructor and its methods. A
failure is located at `S.m` for a method `m`. The compiler checks a
struct's members in declaration order. The model keeps that order among
the methods, so the first of their errors is reported, but not where the
initializer and the destructor stand among them: a type that a variable
hides in either, `valueAsType`, is reported only when no method has
another error (#193). -/
def checkMethods (prog : Program) (phase : Phase) (sd : StructDecl) : Except Rejection Unit := do
  let mut hidden : Option Rejection := none
  let lifecycle : List (Name × Except CheckError Unit) :=
    (sd.init.toList.map fun fd => (sd.name ++ ".__init__", checkInit prog phase sd.name fd)) ++
    sd.deinit.toList.map fun body => (sd.name ++ ".__deinit__",
      checkBody prog phase (some sd.name) (deinitDecl sd.name body))
  for (where_, r) in lifecycle do
    if let .error e := r then
      if !(e matches .valueAsType _) then throw ⟨where_, e⟩
      if hidden.isNone then hidden := some ⟨where_, e⟩
  for fd in sd.methods do
    if let .error e := checkMethod prog phase sd.name fd then
      if let (.valueAsType _, some r) := (e, hidden) then throw r
      throw ⟨sd.name ++ "." ++ fd.name, e⟩
  if let some r := hidden then throw r

/-- Checks that every field of the struct `sd` can be copied as `sd`
declares its values are: at all for `Copyable`, implicitly for
`ImplicitlyCopyable`. The first field that cannot is the error, since the
compiler cannot synthesize the copy initializer from it (#164). -/
def checkCopying (prog : Program) (sd : StructDecl) : Except CheckError Unit :=
  for (f, t) in sd.fields do
    let ok := match sd.copying with
      | .none => true
      | .explicit => copyingOf prog t != Copying.none
      | .implicit => copyingOf prog t == Copying.implicit
    unless ok do throw (CheckError.uncopyableField sd.name f t)

/-- Checks a program in the phase `phase`: it is accepted, or rejected with
the first error found and where it was found. A missing `main` is the
flow phase's. The fields of copyable structs are checked after
every body and the parameters and result of `main`, and before a program
with no `main` is rejected. The compiler checks a struct's fields after
the functions' bodies, `main`'s signature and the methods of the structs
up to it, and before its later passes and a missing `main`; the rest of
its order is left to #96 (#164). A type that a variable hides in a
struct's initializer, destructor or method, `valueAsType`, is reported
there too, before that struct's copyability check, and the methods of
the structs after it are not checked, since the compiler reports their
errors later (#193). When the struct declares its own `__init__` and the
type is in its destructor or a method, it comes after the copyability
check: the compiler checks the copy initializer right after `__init__`,
which the model, keeping no order between `__init__` and the methods,
takes to come first. -/
def checkPhase (prog : Program) (phase : Phase) : Except Rejection Unit := do
  (checkDistinct (prog.structs.map (·.name) ++ prog.funs.map (·.name))).mapError (⟨"", ·⟩)
  let mut hidden : Option (Name × Rejection) := none
  for sd in prog.structs do
    checkFields prog sd
    if hidden.isNone then
      match checkMethods prog phase sd with
      | .error r => if r.error matches .valueAsType _ then hidden := some (sd.name, r) else throw r
      | .ok () => pure ()
  for fd in prog.funs do (checkFun prog phase fd).mapError (⟨fd.name, ·⟩)
  let main := findFun prog "main"
  if let some fd := main then
    unless fd.params.isEmpty && fd.result == .noneType do throw ⟨"main", .noMain⟩
  for sd in prog.structs do
    let deferred := hidden.bind fun (s, r) => if s == sd.name then some r else none
    if let some r := deferred then
      if sd.init.isNone || r.decl == sd.name ++ ".__init__" then throw r
    (checkCopying prog sd).mapError (⟨sd.name, ·⟩)
    if let some r := deferred then throw r
  if phase == .flow && main.isNone then throw ⟨"", .noMain⟩

/-- Checks a program: it is accepted, or rejected with the first error of
the type phase, or else of the flow phase, which the compiler reports in
that order of tiers (`Phase`, ADR-2026-11-21-1941). -/
def checkProgram (prog : Program) : Except Rejection Unit := do
  checkPhase prog .type
  checkPhase prog .flow

end MojoGrimoire.Check
