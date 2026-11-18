import Lake
open Lake DSL

/-
The Lean model of Mojo: the semantics, its tests, and the check that every
declaration is trusted. It has no dependencies (ADR-2026-11-15-1905). Build it
with `scripts/build-lean.sh`, which applies the build's guards. Module and
declaration docs are written in Verso markup, so that the spec document in
`docs/spec/` renders them (ADR-2026-11-15-2030). TOML cannot set both doc
options below, because one name extends the other.
-/
package «mojo-grimoire» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`doc.verso, true⟩,
    ⟨`doc.verso.suggestions, false⟩
  ]

/-- The model of Mojo. -/
@[default_target]
lean_lib MojoGrimoire

/-- The interpreter as a command: `mojo-grimoire FILE.mojo` runs a file. It
is a default target, so every build links it. -/
@[default_target]
lean_exe «mojo-grimoire» where
  root := `MojoGrimoireCli

/-- The executable's root module as a library, so that `MojoGrimoireTest`
can import it and Lake builds it first. -/
lean_lib MojoGrimoireCli

/-- The Lean tests: building them runs their checks. -/
@[default_target]
lean_lib MojoGrimoireTest

/-- The paths of the package's `.lean` files, outside hidden directories such
as `.lake`, sorted, one per line. `#check_axioms` in `MojoGrimoireCheck` reads
the same list from the disk, and Lake would not see that read by itself. Only
the paths are traced, so adding, removing or renaming a file reruns the check,
and editing one does not rerun it by this trace. -/
target sourcePaths pkg : String := Job.async do
  let dir := pkg.dir
  let hidden (p : System.FilePath) := (p.fileName.getD "").startsWith "."
  let files ← dir.walkDir fun p => pure (p == dir || !hidden p)
  let depth := dir.components.length
  let paths := files.filter (·.extension == some "lean") |>.map fun file =>
    "/".intercalate (file.components.drop depth)
  let list := "\n".intercalate (paths.qsort (· < ·)).toList
  addPureTrace list "the paths of the Lean sources"
  return list

/-- The check that every declaration of `lean/` is trusted and every source
file is imported (ADR-2026-11-15-1906). It is a library of its own so that
only its one module reruns when the list of files changes. -/
@[default_target]
lean_lib MojoGrimoireCheck where
  needs := #[`@/sourcePaths]
