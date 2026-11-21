import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of values of type `None`, from a call that returns nothing (#131).
A variable may hold one, with or without the annotation `None`, copy it,
transfer it, which has no effect, and a literal may hold them. Each
expected outcome is the compiler's, at the pinned nightly. The programs are
parsed from text, one line per string, after the shared declarations.
-/

namespace MojoGrimoireTest.Parse.NoneValues

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "def f():",
  "    pass",
  "def g(x: Int):",
  "    pass",
  "def main():"]

/-- Parses, checks and runs a `main` made of the lines `ls`. -/
private def inMain (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)

/-- The rejection of `main` with the error `e`. -/
private def rejects (e : CheckError) : Option Outcome := some (.rejected ⟨"main", e⟩)

-- Inference gives `var u = f()` the type `None`, and a failed inference
-- the type `unknown`.
#guard (parse ("\n".intercalate (decls ++ ["    var u = f()"]))).toOption.map
    (·.funs.find? (·.name == "main") |>.map (·.body)) ==
  some (some [.decl "u" .noneType (some (.call "f" []))])
#guard inMain ["    var u = h()"] == rejects (.unknownFunction "h")

-- A variable of type `None`: bound, annotated, declared without a value,
-- assigned, copied, transferred twice, and bound by `ref`.
#guard inMain ["    var u = f()", "    print(1)"] == some (.finished ["1"])
#guard inMain ["    var u: None = f()", "    print(1)"] == some (.finished ["1"])
#guard inMain ["    var u: None", "    print(1)"] == some (.finished ["1"])
#guard inMain ["    var u = f()", "    u = f()", "    print(1)"] == some (.finished ["1"])
#guard inMain ["    var u = f()", "    var v = u", "    print(2)"] == some (.finished ["2"])
#guard inMain ["    var u = f()", "    var w = u^", "    var z = u^", "    var y = u", "    print(3)"] ==
  some (.finished ["3"])
#guard inMain ["    var u = f()", "    ref r = u", "    print(1)"] == some (.finished ["1"])

-- Literals of `None` elements, nested too, and an element read from one.
#guard inMain ["    var xs = [g(1), g(2)]", "    print(len(xs))"] == some (.finished ["2"])
#guard inMain ["    var xs = [g(1)]", "    var y = xs[0]", "    xs[0] = g(3)", "    print(len(xs))"] ==
  some (.finished ["1"])
#guard inMain ["    var xs = [[g(1)], [g(2)]]", "    print(len(xs))"] == some (.finished ["2"])
#guard inMain ["    var xs = [g(1), g(2)]", "    xs = [g(3), g(4)]", "    print(len(xs))"] ==
  some (.finished ["2"])
#guard inMain ["    var xs = [[g(1)], [g(2)]]", "    xs[0] = [g(3)]", "    print(len(xs))"] ==
  some (.finished ["2"])
#guard inMain ["    var xs = [g(1), g(2)]", "    var ys = xs.copy()", "    print(len(ys))"] ==
  some (.finished ["2"])

-- What Mojo rejects.
#guard inMain ["    var u = f()", "    print(u)"] == rejects (.notPrintable .noneType)
#guard inMain ["    var xs = [g(1), g(2)]", "    print(xs)"] ==
  rejects (.notPrintable (.array .noneType 2))
#guard inMain ["    var u = f()", "    var v = f()", "    print(u == v)"] ==
  rejects (.missingMethod .noneType "__eq__")
#guard inMain ["    var u = f()", "    var v = u + u"] == rejects (.missingMethod .noneType "__add__")
#guard inMain ["    var u = f()", "    var v = u.copy()"] ==
  rejects (.unknownAttribute "NoneType" "copy")
#guard inMain ["    var u: None", "    var v = u"] == rejects (.uninitializedUse (.var "u"))
#guard inMain ["    var u: None", "    var v = u.copy()"] ==
  rejects (.unknownAttribute "NoneType" "copy")
#guard inMain ["    var xs = [g(1)]", "    var k: Int", "    var v = xs[k].copy()"] ==
  rejects (.unknownAttribute "NoneType" "copy")
#guard inMain ["    var u = f()", "    u = 1"] == rejects (.typeMismatch .noneType .int)
#guard inMain ["    var u: None = 1"] == rejects (.typeMismatch .noneType .int)
#guard inMain ["    var x: Int = f()"] == rejects (.typeMismatch .int .noneType)
#guard inMain ["    var xs = [g(1), g(2)]", "    var ys = xs"] ==
  rejects (.implicitCopy (.array .noneType 2))
#guard inMain ["    var xs = [g(1), 2]"] == rejects (.typeMismatch .noneType .int)
#guard inMain ["    var xs = List[Int]([f()])"] == rejects (.noMatchingInit (.list .int))
#guard inMain ["    var xs = List[Int]([f(), 1])"] == rejects (.noMatchingInit (.list .int))

-- `None` as a type argument is a value where Mojo expects a type: the
-- parser reads it as `unknown`, which may not be declared (#183).
#guard inMain ["    var xs: List[None] = [g(1)]"] == rejects (.invalidType (.list .unknown))
#guard inMain ["    var xs: Array[None, 1] = [g(1)]"] == rejects (.invalidType (.array .unknown 1))
#guard inMain ["    var ys = List[None]([g(1)])"] == rejects (.invalidType (.list .unknown))
#guard inMain ["    var xs = [g(1), g(2)]", "    var ys = List[None](xs)"] ==
  rejects (.invalidType (.list .unknown))
#guard inMain ["    var ys = List[None]()"] == rejects (.invalidType (.list .unknown))

end MojoGrimoireTest.Parse.NoneValues
