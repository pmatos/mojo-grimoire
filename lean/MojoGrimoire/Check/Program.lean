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
phase, then checks every body in the flow phase, in the compiler's
order, and a rejection names the first error found, and where.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a function holds a parameter of convention `c`, and which of its
parts are uninitialized on entry: the `self` of `__init__` is wholly
uninitialized, and every other parameter wholly initialized. -/
def paramState (prm : Param) : VarState :=
  match prm.conv with
  | .read => ⟨prm.name, prm.ty, .readOnly, [], [], [[]], [], []⟩
  | .ref => ⟨prm.name, prm.ty, .refParam, [], [], [[]], [], []⟩
  | .mutable => ⟨prm.name, prm.ty, .mutable, [], [], [[]], [], []⟩
  | .owned => ⟨prm.name, prm.ty, .owned, [], [], [[]], [], []⟩
  | .out => ⟨prm.name, prm.ty, .constructing, [[]], [], [], [], []⟩
  | .deinit => ⟨prm.name, prm.ty, .dying, [], [], [[]], [], []⟩

/-- What checking a body gives: its missing return, if it can reach its end
where it must return a result, and what the instantiation phase records
in it (`InstEvent`). -/
abbrev BodyResult := Option CheckError × List InstEvent

/-- Rejects a list of names that holds a name twice. -/
def checkDistinct : List Name → Except CheckError Unit
  | [] => pure ()
  | x :: xs => if xs.contains x then throw (.duplicate x) else checkDistinct xs

/-- Checks the signature of the function `fd`: its parameters have distinct
names and declarable types, and its result is declarable or `None`. The
compiler resolves `main`'s signature so before it checks its shape. -/
def checkSignature (prog : Program) (fd : FunDecl) : Except CheckError Unit := do
  checkDistinct (fd.params.map (·.name))
  for prm in fd.params do
    unless validTy prog prm.ty do throw (typeError prm.ty)
  unless fd.result == .noneType || validTy prog fd.result do throw (typeError fd.result)

/-- Checks the body of the function `fd`: its parameters and result must
have declarable types, its origin must name parameters passed as locations,
and the body must be accepted. It is checked in the phase `phase`, and in
the flow phase up to the stage `stage`. When the body can
reach its end and the function returns a result, it gives the missing
return, which the flow phase reports before its other errors
(`checkFlow`); otherwise the state at the end is checked as at a
return. -/
def checkBody (prog : Program) (phase : Phase) (stage : Stage) (fd : FunDecl) :
    Except CheckError BodyResult := do
  checkSignature prog fd
  checkOrigin fd
  let start : State :=
    { vars := fd.params.reverse.map paramState, live := true, stale := [], changes := [], phase,
      stage }
  let (missing, s) ← (do
      checkBlock prog fd fd.body
      if !(← get).live then return none
      if fd.result != Ty.noneType then return some (CheckError.missingReturn fd.name)
      checkExit prog
      return none).run start
  pure (missing, s.events)

/-- Rejects a parameter list in which a parameter has the convention `out` or
`deinit`, which only the `self` of `__init__` and `__deinit__` may have. -/
def checkConventions (fn : Name) (params : List Param) : Except CheckError Unit :=
  for prm in params do
    if prm.conv == .out || prm.conv == .deinit then throw (.invalidConvention fn)

/-- Checks a function. -/
def checkFun (prog : Program) (phase : Phase) (stage : Stage) (fd : FunDecl) :
    Except CheckError BodyResult := do
  checkConventions fd.name fd.params
  checkBody prog phase stage fd

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
def checkMethod (prog : Program) (phase : Phase) (stage : Stage) (s : Name) (fd : FunDecl) :
    Except CheckError BodyResult := do
  if let some n := operatorArity fd.name then
    unless fd.params.length == n do throw (.arityMismatch fd.name n fd.params.length)
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self.name == "self" && self.ty == .struct s do throw (.invalidSelf fd.name)
  if self.conv == .out || self.conv == .deinit then throw (.invalidSelf fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog phase stage fd

/-- Checks the initializer of the struct `s`: its first parameter is
`out self`, and it returns nothing. -/
def checkInit (prog : Program) (phase : Phase) (stage : Stage) (s : Name) (fd : FunDecl) :
    Except CheckError BodyResult := do
  let some self := fd.params.head? | throw (.invalidSelf fd.name)
  unless self == ⟨.out, "self", .struct s⟩ do throw (.invalidSelf fd.name)
  unless fd.result == .noneType do throw (.invalidReturn fd.name)
  checkConventions fd.name fd.params.tail
  checkBody prog phase stage fd

/-- Checks a struct's own declaration, which the compiler checks with the
free functions, in the order of the declarations: its fields and methods
have distinct names, and its fields declarable types. -/
def checkFields (prog : Program) (sd : StructDecl) : Except CheckError Unit := do
  checkDistinct (sd.fields.map (·.1) ++ sd.methods.map (·.name))
  for (_, t) in sd.fields do
    unless validTy prog t do throw (.invalidType t)

/-- The member `m` of the struct `sd` that has a body, with where it is
and its check in a phase, up to a stage: its initializer, its destructor,
checked with the single parameter `deinit self`, or a method; none for a
field. -/
def memberCheck (prog : Program) (sd : StructDecl) :
    Member → Option (Name × (Phase → Stage → Except CheckError BodyResult))
  | .init => sd.init.map fun fd =>
      (sd.name ++ ".__init__", fun ph st => checkInit prog ph st sd.name fd)
  | .deinit => sd.deinit.map fun body =>
      (sd.name ++ ".__deinit__", fun ph st =>
        checkBody prog ph st (deinitDecl sd.name body))
  | .method j => sd.methods[j]?.map fun fd =>
      (sd.name ++ "." ++ fd.name, fun ph st => checkMethod prog ph st sd.name fd)
  | .field _ => none

/-- Checks that every field of the struct `sd` can be copied as `sd`
declares its values are: at all for `Copyable`, implicitly for
`ImplicitlyCopyable`. The first field that cannot is the error, since the
compiler cannot synthesize the copy initializer from it (#164). With
`cycles`, a field on a cycle of fields that the fixed compiler rejects is
the error at its place too, as the pin reports it in the implicit copy
initializer that follows `__init__`. -/
def checkCopying (prog : Program) (sd : StructDecl) (cycles : Bool := false) :
    Except CheckError Unit :=
  for (f, t) in sd.fields do
    if cycles && rejectedCycle prog sd.name t then throw (.recursiveStruct sd.name)
    let ok := match sd.copying with
      | .none => true
      | .explicit => copyingOf prog t != Copying.none
      | .implicit => copyingOf prog t == Copying.implicit
    unless ok do throw (CheckError.uncopyableField sd.name f t)

/-- The result of the type phase's check of the body at `w`: its error,
located there, or its missing return, if any. -/
def located (w : Name) : Except CheckError BodyResult → Except Rejection (List Rejection)
  | .error e => throw ⟨w, e⟩
  | .ok (r, _) => pure (r.map (⟨w, ·⟩)).toList

/-- Checks the struct `sd` in the type phase, as the compiler does once it
has checked the free functions, and gives its missing returns: its members
in their order `ms`, a failure located at `S.m` for a member `m`. The
copy initializer that the compiler synthesizes is checked right after
`__init__`, where an implicit one also meets a cycle of fields that the
fixed compiler rejects, field by field. Otherwise a cycle comes after the
last member, and then the copy initializer when the struct declares no
`__init__` (#164, #96 part 6). -/
def checkStruct (prog : Program) (sd : StructDecl) (ms : List Member) :
    Except Rejection (List Rejection) := do
  let atStruct (c : Except CheckError Unit) : Except Rejection Unit := c.mapError (⟨sd.name, ·⟩)
  let mut missing : List Rejection := []
  for m in ms do
    if let some (where_, check) := memberCheck prog sd m then
      missing := missing ++ (← located where_ (check .type .ends))
    if m == .init then atStruct (checkCopying prog sd (sd.copying == .implicit))
  atStruct do
    for (_, t) in sd.fields do
      if rejectedCycle prog sd.name t then throw (.recursiveStruct sd.name)
  if sd.init.isNone then atStruct (checkCopying prog sd)
  pure missing

/-- Checks a program in the type phase, in the compiler's order (#96 part
6): it is accepted, with the missing returns of its bodies, which the flow
phase reports, or rejected with the first error found and where it was
found. First, no struct has the name of another struct or of a function.
Then, in the order of the declarations, each free function, with `main`'s
signature, resolved and then of the shape that takes nothing and returns
nothing, before its conventions and its body,
and a function of the name of an earlier one, and each struct's own
declaration (`checkFields`). Last, each struct in the order of the
declarations (`checkStruct`). -/
def checkTypes (prog : Program) : Except Rejection (List Rejection) := do
  let structs := prog.structs.map (·.name)
  (checkDistinct structs).mapError (⟨"", ·⟩)
  if let some s := structs.find? fun s => (findFun prog s).isSome then
    throw ⟨"", .duplicate s⟩
  let mut missing : List Rejection := []
  let mut seen : List Name := []
  let mut declared : List (StructDecl × List Member) := []
  for d in prog.declOrder do
    match d with
    | .func i =>
      let some fd := prog.funs[i]? | continue
      if seen.contains fd.name then throw ⟨"", .duplicate fd.name⟩
      seen := fd.name :: seen
      if fd.name == "main" then
        (checkSignature prog fd).mapError (⟨"main", ·⟩)
        unless fd.params.isEmpty && fd.result == .noneType do throw ⟨"main", .noMain⟩
      missing := missing ++ (← located fd.name (checkFun prog .type .ends fd))
    | .struct i ms =>
      let some sd := prog.structs[i]? | continue
      (checkFields prog sd).mapError (⟨sd.name, ·⟩)
      declared := (sd, ms) :: declared
  for (sd, ms) in declared.reverse do
    missing := missing ++ (← checkStruct prog sd ms)
  pure missing

/-- The bodies of the program `prog` in the order of its declarations in
the source, the free functions and the members of the structs
interleaved, as the compiler's pass manager visits them, each with where
it is and its check in the phase `ph`, up to a stage. -/
def declBodies (prog : Program) (ph : Phase) :
    List (Name × (Stage → Except CheckError BodyResult)) :=
  prog.declOrder.flatMap fun
    | .func i => (prog.funs[i]?.map fun fd => (fd.name, fun st => checkFun prog ph st fd)).toList
    | .struct i ms => match prog.structs[i]? with
      | some sd => ms.filterMap fun m => (memberCheck prog sd m).map fun (w, c) => (w, c ph)
      | none => []

/-- Checks a program in the flow phase, on a program that the type phase
accepts with the missing returns `missing`, in the order of the
compiler's pass manager (#96 part 5): first the missing return of the
first body in the order of the declarations that has one; then each body
in that order, the free functions and the members of the structs
interleaved (`declBodies`). In a body, a use and what the body leaves at
a return come in the order of the body, before a value that may not end
(`Stage`, #159): a body is checked through every stage, and when that
finds a value that may not end, again up to the stage of uses, whose
error comes first. A missing `main` comes after every error of the flow
phase. -/
def checkFlow (prog : Program) (missing : List Rejection) : Except Rejection Unit := do
  let bodies := declBodies prog .flow
  for (w, _) in bodies do
    if let some r := missing.find? (·.decl == w) then throw r
  for (w, check) in bodies do
    if let .error e := check .ends then
      if e matches .partiallyDestroyed _ then
        let _ ← (check .uses).mapError (⟨w, ·⟩)
      throw ⟨w, e⟩
  if (findFun prog "main").isNone then throw ⟨"", .noMain⟩

end MojoGrimoire.Check
