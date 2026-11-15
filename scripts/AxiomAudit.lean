import Lean
open Lean

/-!
Axiom audit: every declaration in the `MojoGrimoire` library may depend only on
Lean's three standard axioms. Anything else, including `sorryAx`, fails CI.
-/

def allowedAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- Pure environment reader, enough for `collectAxioms`. -/
instance : MonadEnv (StateM Environment) where
  getEnv := get
  modifyEnv := modify

def libPrefix : Name := `MojoGrimoire

unsafe def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let env ← importModules #[{ module := libPrefix }] {} (trustLevel := 1024) (loadExts := true)
  let mut bad : Array (Name × Array Name) := #[]
  let mut checked := 0
  for (c, _) in env.constants.toList do
    let some idx := env.getModuleIdxFor? c | continue
    let mod := env.header.moduleNames[idx.toNat]!
    unless libPrefix.isPrefixOf mod do continue
    checked := checked + 1
    let axs : Array Name := (collectAxioms (m := StateM Environment) c).run' env
    let extra := axs.filter (fun a => !allowedAxioms.contains a)
    unless extra.isEmpty do bad := bad.push (c, extra)
  IO.println s!"axiom-audit: checked {checked} declarations"
  if bad.isEmpty then
    IO.println "axiom-audit: OK"
    return 0
  for (c, axs) in bad do
    IO.eprintln s!"axiom-audit: {c} depends on {axs}"
  return 1
