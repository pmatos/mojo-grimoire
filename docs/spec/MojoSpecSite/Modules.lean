import MojoSpecSite.Sources

/-!
Every module under `lean/MojoGrimoire` must be a section of the document, so a new
module cannot be left out of the spec
(`docs/decisions/spec.md#module-docs-and-every-module`). The check
compares the files under `lean/MojoGrimoire` with the sections that
`docs/spec/MojoSpec.lean` includes, and those of each chapter that it
includes as a document of its own, such as `MojoSpec.Chapters.Execution`.
-/

namespace MojoSpecSite

/-- The module of the file `path`, relative to the repository, such as `lean/MojoGrimoire/Core/Ops.lean`. -/
def moduleOfPath (path : String) : String :=
  (".".intercalate ((path.splitOn "/").drop 1)).replace ".lean" ""

/-- The modules that the document `text` includes, each named by an include command at the start of a line. -/
def includedModules (text : String) : Array String :=
  (text.splitOn "\n").toArray.filterMap fun line =>
    let tokens := line.splitOn " "
    if tokens.head? == some "{includeReadable" || tokens.head? == some "{includeLiterate" then
      tokens.find? (·.startsWith "MojoGrimoire.")
    else none

/-- The documents that the document `text` includes as chapters, each by an
`{include N Doc}` command at the start of a line. -/
def includedDocs (text : String) : Array String :=
  (text.splitOn "\n").toArray.filterMap fun line =>
    match line.splitOn " " with
    | ["{include", _, doc] => if doc.endsWith "}" then some (doc.dropEnd 1).toString else none
    | _ => none

/-- The path of the document module `doc`, relative to `docs/spec`. -/
def docPath (doc : String) : System.FilePath :=
  ("/".intercalate (doc.splitOn ".")) ++ ".lean"

/-- The modules of `files`, paths relative to the repository, that the document `text` does not include. -/
def notIncluded (files : Array String) (text : String) : Array String :=
  let included := includedModules text
  (files.map moduleOfPath).filter (!included.contains ·)

/-- One message per module under `lean/MojoGrimoire` of the repository at `root` that the document does not include. -/
def checkModules (root : System.FilePath) : IO (Array String) := do
  let files ← filesUnder root "lean/MojoGrimoire" (fun _ => false) (·.endsWith ".lean")
  let main ← IO.FS.readFile (root / "docs/spec/MojoSpec.lean")
  let mut text := main
  for doc in includedDocs main do
    text := text ++ "\n" ++ (← IO.FS.readFile (root / "docs/spec" / docPath doc))
  return (notIncluded (files.qsort (· < ·)) text).map fun m =>
    s!"{m} is under lean/MojoGrimoire, but docs/spec/MojoSpec.lean does not include it: add a section for it, in MojoSpec.lean or a chapter it includes, with includeReadable, or with includeLiterate if it declares nothing"

end MojoSpecSite
