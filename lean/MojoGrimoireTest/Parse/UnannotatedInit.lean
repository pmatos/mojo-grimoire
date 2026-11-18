import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of an unannotated `var u = e` whose initializer has no type that
inference can find (#123). The checker reports the initializer's own error,
as the compiler does, before the `None` type that inference leaves. Each
expected outcome is the compiler's. The programs are parsed from text, one
line per string, after the shared declarations.
-/

namespace MojoGrimoireTest.Parse.UnannotatedInit

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct S(Movable):",
  "    var k: Int",
  "def main():",
  "    var s = S(7)"]

/-- Parses, checks and runs a `main` that goes on with the lines `ls`. -/
private def inMain (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)

/-- The rejection of `main` with the error `e`. -/
private def rejects (e : CheckError) : Option Outcome := some (.rejected ⟨"main", e⟩)

-- An unknown field, read or transferred.
#guard inMain ["    var u = s.nope"] == rejects (.unknownAttribute "S" "nope")
#guard inMain ["    var u = s.nope^"] == rejects (.unknownAttribute "S" "nope")

-- The same root cause, the initializer's error, elsewhere in the initializer.
#guard inMain ["    var u = s.nope.k"] == rejects (.unknownAttribute "S" "nope")
#guard inMain ["    var u = s.k.nope"] == rejects (.unknownAttribute "Int" "nope")
#guard inMain ["    var u = s.nope()"] == rejects (.unknownAttribute "S" "nope")
#guard inMain ["    var u = [s.nope]"] == rejects (.unknownAttribute "S" "nope")
#guard inMain ["    var u = nope"] == rejects (.unknownVariable "nope")

-- An empty literal has no type, which the compiler rejects as well.
#guard inMain ["    var u = []"] == rejects (.invalidType .noneType)

-- An initializer that checks gives its type to the variable.
#guard inMain ["    var u = s.k", "    print(u)"] == some (.finished ["7"])

end MojoGrimoireTest.Parse.UnannotatedInit
