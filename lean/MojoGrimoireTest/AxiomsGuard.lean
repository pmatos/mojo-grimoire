import Lean.Meta.Constructions.CasesOn
import MojoGrimoireTest.Axioms

/-!
The guard on the axiom check's one exception (ADR-2026-11-15-1906): Lean's
generated `T.ctorIdx` may be implemented by `T.ctorIdx._impl`, and
`T.ctorIdx._impl` may be `unsafe`, only in the exact shape that Lean
generates. Each case below declares what it needs in a scratch environment,
asks `untrusted` about each declaration, and throws the environment away, so
the check of `lean/` never sees these declarations. `#guard_msgs` fails the
build when a verdict changes: when a look-alike is accepted, or the pair
that Lean generates is rejected.

A look-alike cannot reuse the names of a pair that Lean generated, so the
cases that need the right names declare an inductive type in the kernel
alone, with its `casesOn`, which has no `ctorIdx`, then add a pair by hand.
-/

namespace MojoGrimoireTest.AxiomsGuard

open Lean Elab Command Meta MojoGrimoireTest

/-- Elaborates each of `cmds`, written as source text. -/
def elabSource (cmds : List String) : CommandElabM Unit := do
  for src in cmds do
    match Parser.runParserCategory (← getEnv) `command src with
    | .ok stx => elabCommand stx
    | .error e => throwError "cannot parse {src}: {e}"

/-- Declares the inductive type `t` with the constructors `ctors`, of no
fields, in the kernel alone, and its `casesOn`: Lean generates no
`ctorIdx` for it. -/
def declareBare (t : Name) (ctors : List String) : CommandElabM Unit := liftTermElabM do
  let ty := mkConst t
  addDecl <| .inductDecl [] 0 [{
    name := t, type := mkSort Level.one,
    ctors := ctors.map fun c => { name := t.str c, type := ty } }] false
  mkCasesOn t

/-- Adds `T.ctorIdx` with the given value, implemented by `impl`, and an
unsafe `T.ctorIdx._impl` with the given value, for the bare type `t`. -/
def declarePair (t impl : Name) (idx implValue : Expr → MetaM Expr) :
    CommandElabM Unit := liftTermElabM do
  let some (.inductInfo ind) := (← getEnv).find? t | throwError "{t} is not inductive"
  let (type, value) ← ctorIdxDecl ind
  addDecl <| .defnDecl {
    name := t.str "ctorIdx" |>.str "_impl", levelParams := [], type,
    value := ← implValue type, hints := .opaque, safety := .unsafe }
  addDecl <| .defnDecl {
    name := t.str "ctorIdx", levelParams := [], type,
    value := ← idx value, hints := .abbrev, safety := .safe }
  setImplementedBy (t.str "ctorIdx") impl

/-- Runs `setup` in a scratch environment and logs what the check says of
each of `names`, then restores the environment. -/
def verdicts (setup : CommandElabM Unit) (names : List Name) : CommandElabM Unit :=
  withoutModifyingEnv do
    setup
    let env ← getEnv
    let natives ← IO.mkRef ({} : NameSet)
    let mut out := #[]
    for n in names do
      let some info := env.find? n | throwError "{n} was not declared"
      out := out.push s!"{n}: {(← untrusted env natives n info).getD "trusted"}"
    logInfo ("\n".intercalate out.toList)

/-- The 0 and 1 literals of a `ctorIdx` value swapped. -/
def swapIndices (e : Expr) : MetaM Expr := pure <| e.replace fun
  | .lit (.natVal 0) => some (mkRawNatLit 1)
  | .lit (.natVal 1) => some (mkRawNatLit 0)
  | _ => none

end MojoGrimoireTest.AxiomsGuard

open Lean MojoGrimoireTest MojoGrimoireTest.AxiomsGuard

/--
info: Tri.ctorIdx: trusted
Tri.ctorIdx._impl: trusted
Vec.ctorIdx: trusted
Vec.ctorIdx._impl: trusted
-/
#guard_msgs in
run_cmd
  verdicts
    (elabSource ["inductive Tri | a | b | c",
      "inductive Vec.{u} (α : Type u) : Nat → Type u
        | nil : Vec α 0
        | cons {n : Nat} : α → Vec α n → Vec α (n + 1)"])
    [`Tri.ctorIdx, `Tri.ctorIdx._impl, `Vec.ctorIdx, `Vec.ctorIdx._impl]

/--
info: _private.MojoGrimoireTest.AxiomsGuard.0.Pri.ctorIdx: trusted
_private.MojoGrimoireTest.AxiomsGuard.0.Pri.ctorIdx._impl: trusted
-/
#guard_msgs in
run_cmd
  verdicts (elabSource ["private inductive Pri | a | b"])
    [mkPrivateName (← getEnv) `Pri.ctorIdx, mkPrivateName (← getEnv) `Pri.ctorIdx._impl]

-- A pair added by hand in the exact generated shape is that pair.
/--
info: Bare.ctorIdx: trusted
Bare.ctorIdx._impl: trusted
-/
#guard_msgs in
run_cmd
  verdicts
    (do declareBare `Bare ["a", "b"]
        declarePair `Bare `Bare.ctorIdx._impl pure ctorIdxImplValue)
    [`Bare.ctorIdx, `Bare.ctorIdx._impl]

-- The right names, but `_impl` does not read the tag.
/--
info: Bare.ctorIdx: is implemented by Bare.ctorIdx._impl
Bare.ctorIdx._impl: is unsafe
-/
#guard_msgs in
run_cmd
  verdicts
    (do declareBare `Bare ["a", "b"]
        declarePair `Bare `Bare.ctorIdx._impl pure
          fun _ => pure (.lam `x (mkConst `Bare) (mkRawNatLit 0) .default))
    [`Bare.ctorIdx, `Bare.ctorIdx._impl]

-- The right names, but `ctorIdx` does not give each constructor's index.
/--
info: Bare.ctorIdx: is implemented by Bare.ctorIdx._impl
Bare.ctorIdx._impl: is unsafe
-/
#guard_msgs in
run_cmd
  verdicts
    (do declareBare `Bare ["a", "b"]
        declarePair `Bare `Bare.ctorIdx._impl swapIndices ctorIdxImplValue)
    [`Bare.ctorIdx, `Bare.ctorIdx._impl]

-- A `ctorIdx` implemented by something other than its `_impl`.
/--
info: Bare.ctorIdx: is implemented by Bare.other
Bare.ctorIdx._impl: is unsafe
Bare.other: trusted
-/
#guard_msgs in
run_cmd
  verdicts
    (do declareBare `Bare ["a", "b"]
        elabSource ["noncomputable def Bare.other (_ : Bare) : Nat := 0"]
        declarePair `Bare `Bare.other pure ctorIdxImplValue)
    [`Bare.ctorIdx, `Bare.ctorIdx._impl, `Bare.other]

-- Another definition implemented by a generated `_impl`.
/-- info: Tri.idx: is implemented by Tri.ctorIdx._impl -/
#guard_msgs in
run_cmd
  verdicts
    (elabSource ["inductive Tri | a | b | c",
      "@[implemented_by Tri.ctorIdx._impl] def Tri.idx (x : Tri) : Nat := x.ctorIdx"])
    [`Tri.idx]

-- A stray pair whose prefix is not an inductive type.
/--
info: Fake.ctorIdx: is implemented by Fake.ctorIdx._impl
Fake.ctorIdx._impl: is unsafe
-/
#guard_msgs in
run_cmd
  verdicts
    (elabSource ["unsafe def Fake.ctorIdx._impl (x : Nat) : Nat := getObjTagNat x",
      "@[implemented_by Fake.ctorIdx._impl] def Fake.ctorIdx (_ : Nat) : Nat := 0"])
    [`Fake.ctorIdx, `Fake.ctorIdx._impl]

-- A type of one constructor, for which Lean generates no `_impl`.
/--
info: Solo.ctorIdx: is implemented by Solo.ctorIdx._impl
Solo.ctorIdx._impl: is unsafe
-/
#guard_msgs in
run_cmd
  verdicts
    (elabSource ["inductive Solo | a",
      "unsafe def Solo.ctorIdx._impl (x : Solo) : Nat := getObjTagNat x",
      "attribute [implemented_by Solo.ctorIdx._impl] Solo.ctorIdx"])
    [`Solo.ctorIdx, `Solo.ctorIdx._impl]
