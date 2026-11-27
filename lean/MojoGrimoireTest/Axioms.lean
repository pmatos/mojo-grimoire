import Lean.Compiler.CSimpAttr
import Lean.Compiler.ExternAttr
import Lean.Compiler.ImplementedByAttr
import Lean.Compiler.LCNF.Util
import Lean.Elab.Command
import Lean.Meta.Native
import Lean.Util.CollectAxioms

/-!
The check that every declaration of `lean/` is trusted (ADR-2026-11-15-1906).
`#check_axioms` names the root modules of the libraries to check. `MojoGrimoireCheck`
imports `MojoGrimoireTest`'s root module, which imports every module of
`lean/`, and runs it as its last command.
It fails the build when a declaration of one of their modules, or of the
module that runs it:

* depends on an axiom other than Lean's three standard ones, `propext`,
  `Classical.choice` and `Quot.sound`, and the axioms of native evaluation
  below. A `sorry` depends on `sorryAx`, so it fails the check;
* is `unsafe` or `partial`;
* is `implemented_by` other code, or `extern`, so that a program would not
  run the definition that the proofs are about.

There is one exception to the last two. For every inductive type `T`
except one of exactly one constructor, Lean 4.36 generates `T.ctorIdx`,
which gives each constructor's index, and has it implemented by
`T.ctorIdx._impl`, an `unsafe` definition that reads the tag of the value at
run time (`Lean.mkCtorIdx`). Lean needs both: without them it cannot build
`T.noConfusion`. The check allows `T.ctorIdx` to be implemented by
`T.ctorIdx._impl`, and `T.ctorIdx._impl` to be `unsafe`, only for a type of
two or more constructors, so the pair of a type of no constructors is still
rejected, and only when the pair has exactly the shape that Lean generates
(`isGeneratedCtorIdx`); each must still pass every other test. The check
looks at the shape, not at who wrote the pair: any pair that differs from
the generated shape is rejected, and a pair in exactly that shape is
accepted even when it is written by hand, since it behaves the same.

The shape is: `T` is a safe inductive type of two or more constructors, not
in `Prop` and not one that the run time represents in its own way, declared
in the same module as the pair; `T.ctorIdx` is safe and its value is the
`casesOn` of its argument whose case for each constructor is that
constructor's index; its implementation is exactly `T.ctorIdx._impl`, of the
same type, whose value is exactly `getObjTagNat` of its last argument. The
compiled code of `T.ctorIdx` then equals its definition only if Lean's
run-time tag of a value is its constructor's index, and the check trusts
that, as it trusts the compiler. Derived equality calls `T.ctorIdx`, so a
proof by native evaluation may rest on it too. `MojoGrimoireTest.AxiomsGuard`
shows that a pair that differs from the shape is rejected.

It also fails when a source file in `lean/` is not imported, or belongs to a
library that is not checked, so that every module of `lean/` is checked; when
a root has no declaration, so that a renamed library is not skipped in
silence; and when any text follows it, since the check would not see a
command there.

A proof by native evaluation (`native_decide`, `decide +native` or
`bv_decide`) compiles a closed term `e : Bool`, runs it, and adds an axiom
`e = true`, named after the declaration, `_native`, the tactic and `ax_…`.
The check allows such an axiom only when it compiles and runs `e` again
itself and gets `true`, so the proof trusts the compiler and nothing else
(ADR-2026-11-15-1906). The bans on `unsafe`, `partial`, `implemented_by` and
`extern` keep the compiled code equal to the definitions that the proofs are
about, up to the exception above. A `@[csimp]` swap is allowed because it
is proved, but only from the standard axioms: the compiler applies every
swap when the check runs a claim again, so a swap proved from a native axiom
could make a false claim run as true and so confirm that axiom.

Lean does not keep an `example`, so the check cannot see one. A `sorry` in an
example gives a warning, and `lean/` builds with `lake build --wfail`, so it
fails the build (ADR-2026-11-15-1906). Native evaluation is allowed in an
example, as it is anywhere.
-/

namespace MojoGrimoireTest

open Lean Elab Command Meta

/-- Lean's three standard axioms: the only ones a declaration may use. -/
def standardAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- Whether `n` is an axiom that Lean's native evaluation added
(`Lean.Meta.nativeEqTrue`) and whose claim holds. Its name ends in `_native`,
the tactic and `ax_…`; it states `e = true` for a closed term `e : Bool`; and
`e` gives `true` when the check compiles and runs it again. -/
def isNativeAxiom (env : Environment) (n : Name) : CommandElabM Bool := do
  let some (.axiomInfo info) := env.find? n | return false
  let named := match n.components.reverse with
    | .str _ ax :: _ :: native :: _ => ax.startsWith "ax_" && native == `_native
    | _ => false
  let (``Eq, #[.const ``Bool [], e, .const ``Bool.true []]) :=
      info.type.getAppFnArgs | return false
  if info.isUnsafe || !named || e.hasLooseBVars || e.hasFVar || e.hasMVar then
    return false
  liftTermElabM <| withoutModifyingEnv do
    try return (← Meta.nativeEqTrue `check_axioms e) matches .success _
    catch _ => return false

/-- The type and the value that Lean generates for `T.ctorIdx`, given an
inductive type `T` of other than one constructor (`Lean.mkCtorIdx`): the
`casesOn` of the argument, whose case for each constructor is that
constructor's index as a literal. -/
def ctorIdxDecl (ind : InductiveVal) : MetaM (Expr × Expr) := do
  let us := ind.levelParams.map mkLevelParam
  let nat := mkConst ``Nat
  forallBoundedTelescope ind.type (ind.numParams + ind.numIndices) fun xs _ => do
    let params := xs.extract 0 ind.numParams
    let indices := xs.extract ind.numParams xs.size
    let indType := mkAppN (mkConst ind.name us) xs
    let type ← mkForallFVars xs (← mkArrow indType nat)
    let value ← withLocalDeclD `x indType fun x => do
      let motive ← mkLambdaFVars (indices.push x) nat
      let casesOn := mkConst (mkCasesOnName ind.name) (.one :: us)
      let mut value := mkApp (mkAppN (mkApp (mkAppN casesOn params) motive) indices) x
      for c in ind.ctors do
        let ctor ← getConstInfoCtor c
        let ctorType ← instantiateForall ctor.type params
        value := mkApp value <| ← forallBoundedTelescope ctorType ctor.numFields
          fun fields _ => mkLambdaFVars fields (mkRawNatLit ctor.cidx)
      mkLambdaFVars (xs.push x) value
    return (type, value)

/-- The value that Lean generates for `T.ctorIdx._impl`, given the type of
`T.ctorIdx`: `getObjTagNat` of its last argument. -/
def ctorIdxImplValue (type : Expr) : MetaM Expr :=
  forallTelescope type fun args _ => do
    let some x := args.back? | throwError "{type} takes no argument"
    let xType ← Meta.inferType x
    mkLambdaFVars args (mkApp2 (mkConst ``getObjTagNat [← Meta.getLevel xType]) xType x)

/-- Whether `T.ctorIdx` and `T.ctorIdx._impl` are exactly the pair that Lean
generates for the inductive type `t`. `T` is a safe inductive type with two
or more constructors, not one of the types that the run time represents in
its own way, and it eliminates into `Type`. All three are declared in the
same module. `T.ctorIdx` is safe, and its type and value are the ones that
`ctorIdxDecl` builds. It is implemented by `T.ctorIdx._impl`, which has the
same type and the value that `ctorIdxImplValue` builds. Terms are compared
up to the names and annotations of their binders. -/
def isGeneratedCtorIdx (env : Environment) (t : Name) : MetaM Bool := do
  let idx := t.str "ctorIdx"
  let impl := idx.str "_impl"
  let some (.inductInfo ind) := env.find? t | return false
  let some (.defnInfo d) := env.find? idx | return false
  let some (.defnInfo i) := env.find? impl | return false
  let sameModule := [idx, impl].all (env.getModuleIdxFor? · == env.getModuleIdxFor? t)
  unless sameModule && !ind.isUnsafe && ind.numCtors ≥ 2 do return false
  if Compiler.LCNF.isRuntimeBuiltinType t || (← Meta.isPropFormerType ind.type) then
    return false
  unless d.safety == .safe && i.safety == .unsafe do return false
  unless d.levelParams == ind.levelParams && i.levelParams == ind.levelParams do
    return false
  unless Compiler.getImplementedBy? env idx == some impl do return false
  let (type, value) ← ctorIdxDecl ind
  return d.type == type && d.value == value && i.type == type &&
    i.value == (← ctorIdxImplValue type)

/-- Why the declaration `n` is not trusted, if it is not. `natives` holds the
axioms of native evaluation already found to hold. -/
def untrusted (env : Environment) (natives : IO.Ref NameSet) (n : Name)
    (info : ConstantInfo) : CommandElabM (Option String) := do
  let generated (t : Name) := liftTermElabM (isGeneratedCtorIdx env t)
  if info.isUnsafe then
    let isImpl := n matches .str (.str _ "ctorIdx") "_impl"
    unless isImpl && (← generated n.getPrefix.getPrefix) do return some "is unsafe"
  -- A `partial` definition is an opaque constant whose code is its
  -- `_unsafe_rec`. Well-founded recursion makes an `_unsafe_rec` too, for
  -- the compiler, beside a definition with a value, so the copy alone is not
  -- a sign of `partial`.
  if info matches .opaqueInfo _ && env.contains (n.str "_unsafe_rec") then
    return some "is partial"
  if let some impl := Compiler.getImplementedBy? env n then
    let isIdx := n matches .str _ "ctorIdx"
    unless isIdx && impl == n.str "_impl" && (← generated n.getPrefix) do
      return some s!"is implemented by {impl}"
  if isExtern env n then return some "is extern"
  -- A `@[csimp]` swap changes the code that the check runs to confirm a native
  -- claim, so a swap that rests on a native axiom could confirm itself.
  let csimp := Compiler.hasCSimpAttribute env n
  let mut bad := #[]
  for a in ← liftCoreM (collectAxioms n) do
    if standardAxioms.contains a then continue
    if !csimp && (← natives.get).contains a then continue
    if !csimp && (← isNativeAxiom env a) then natives.modify (·.insert a)
    else bad := bad.push a
  if bad.isEmpty then return none
  return some s!"depends on the axioms {bad.toList}"

/-- The directory that holds the sources of a library whose module `mod` is in
the file `file`: the file's directory, one level up per dot in `mod`. -/
def sourceDir (file : System.FilePath) (mod : Name) : System.FilePath :=
  mod.components.foldl (fun dir _ => dir.parent.getD ".") file

/-- The modules whose sources are in `dir`: one for each `.lean` file under it,
other than `lakefile.lean` and the files under a hidden directory, such as
Lake's `.lake`. -/
def sourceModules (dir : System.FilePath) : IO (Array Name) := do
  let hidden (p : System.FilePath) := (p.fileName.getD "").startsWith "."
  let files ← dir.walkDir fun p => pure (p == dir || !hidden p)
  let depth := dir.components.length
  let mut mods := #[]
  for file in files do
    let isSource := file.fileName != some "lakefile.lean"
    unless file.extension == some "lean" && isSource do continue
    let some stem := file.fileStem | continue
    let dirs := (file.components.drop depth).dropLast
    mods := mods.push ((dirs ++ [stem]).foldl Name.str .anonymous)
  return mods

/-- `#check_axioms R₁ R₂ …` checks every declaration of the module that runs
it and of every imported module whose name starts with one of the roots `Rᵢ`,
and fails with each one that is not trusted. It also fails when a module whose
source is in the running module's library directory is not imported or not
under a root, when a root has no declaration, and when any text follows it. -/
syntax (name := checkAxioms) "#check_axioms " ident+ : command

@[command_elab checkAxioms]
def elabCheckAxioms : CommandElab
  | `(#check_axioms $roots*) => do
    let env ← getEnv
    let main := env.mainModule
    let roots := roots.map (·.getId)
    let natives ← IO.mkRef ({} : NameSet)
    let mut problems : Array String := #[]
    let mut checked : NameSet := {}
    for h : i in [0:env.header.moduleNames.size] do
      let mod := env.header.moduleNames[i]
      unless roots.contains mod.getRoot do continue
      for n in env.header.moduleData[i]!.constNames do
        checked := checked.insert mod.getRoot
        let some info := env.find? n | continue
        if let some why ← untrusted env natives n info then
          problems := problems.push s!"{n}, in {mod}, {why}"
    for (n, info) in env.constants.map₂.toList do
      checked := checked.insert main.getRoot
      if let some why ← untrusted env natives n info then
        problems := problems.push s!"{n}, in {main}, {why}"
    for r in roots do
      unless checked.contains r do
        problems := problems.push s!"no declaration of {r} was checked"
    let dir := sourceDir ⟨← getFileName⟩ main
    for mod in ← sourceModules dir do
      if mod == main then continue
      unless env.header.moduleNames.contains mod do
        problems := problems.push s!"{mod} is not imported by {main}"
      unless roots.contains mod.getRoot do
        problems := problems.push s!"{mod} is not in a checked library"
    let src := (← getFileMap).source
    let tail := (← getRef).getTailPos?.getD 0
    let rest := String.Pos.Raw.extract src tail ⟨src.utf8ByteSize⟩
    unless rest.all Char.isWhitespace do
      problems := problems.push s!"text follows #check_axioms in {main}"
    unless problems.isEmpty do
      throwError m!"#check_axioms found {problems.size} problems:\n" ++
        "\n".intercalate problems.toList
  | _ => throwUnsupportedSyntax

end MojoGrimoireTest
