import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the fields of a struct that declares `Copyable` or
`ImplicitlyCopyable` (#164): each must be copyable, or implicitly copyable,
since the compiler synthesizes the struct's copy initializer from them.
Each verdict is the pinned compiler's for the program, probed on the
nightly 1.3.0.dev2026111905.
-/

namespace MojoGrimoireTest.Parse.CopyableFields

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- A struct `Res` that can only be moved, and `C`, which can be copied
explicitly. -/
private def decls : List String :=
  ["@fieldwise_init", "struct Res(Movable):", "    var id: Int",
   "@fieldwise_init", "struct C(Copyable):", "    var x: Int"]

/-- The struct `S` with the conformances `cs` and the fields `fs`, each
`name: type`, then `main`, whose body is `body`. -/
private def withS (cs : String) (fs : List String) (body : List String) : List String :=
  decls ++ ["@fieldwise_init", s!"struct S({cs}):"] ++ fs.map ("    var " ++ ·) ++
    ["def main():"] ++ body.map ("    " ++ ·)

private def rejectsAt (cs : String) (fs body : List String) (decl : Name) (e : CheckError) :
    Bool :=
  runLines (withS cs fs body) == some (.rejected ⟨decl, e⟩)

private def prints (cs : String) (fs body : List String) (out : List String) : Bool :=
  runLines (withS cs fs body) == some (.finished out)

private def res : Ty := .struct "Res"

-- A field that cannot be copied, of a struct that nothing copies.
#guard rejectsAt "Copyable" ["r: Res"] ["print(1)"] "S" (.uncopyableField "S" "r" res)
#guard rejectsAt "Copyable" ["r: List[Res]"] ["print(1)"] "S"
  (.uncopyableField "S" "r" (.list res))
#guard rejectsAt "Copyable" ["r: Array[Res, 2]"] ["print(1)"] "S"
  (.uncopyableField "S" "r" (.array res 2))
#guard rejectsAt "Copyable" ["r: List[List[Res]]"] ["print(1)"] "S"
  (.uncopyableField "S" "r" (.list (.list res)))
-- The first such field is the error.
#guard rejectsAt "Copyable" ["x: Int", "r: Res", "q: List[Res]"] ["print(1)"] "S"
  (.uncopyableField "S" "r" res)

-- A field that cannot be copied implicitly: copyable only explicitly, or
-- not at all.
#guard rejectsAt "ImplicitlyCopyable" ["r: Res"] ["print(1)"] "S" (.uncopyableField "S" "r" res)
#guard rejectsAt "ImplicitlyCopyable" ["xs: List[Int]"] ["print(1)"] "S"
  (.uncopyableField "S" "xs" (.list .int))
#guard rejectsAt "ImplicitlyCopyable" ["a: Array[Int, 2]"] ["print(1)"] "S"
  (.uncopyableField "S" "a" (.array .int 2))
#guard rejectsAt "ImplicitlyCopyable" ["c: C"] ["print(1)"] "S" (.uncopyableField "S" "c" (.struct "C"))
#guard rejectsAt "Copyable, ImplicitlyCopyable" ["r: Res"] ["print(1)"] "S"
  (.uncopyableField "S" "r" res)

-- Fields that can be copied as the struct declares.
#guard prints "Copyable" ["b: Bool", "xs: List[Int]", "a: Array[Bool, 3]", "c: C"]
  ["var s = S(True, [1], [True, False, True], C(2))", "var t = s.copy()", "t.xs[0] = 9",
   "print(s.xs[0], t.xs[0], t.c.x)"] ["1 9 2"]
#guard prints "ImplicitlyCopyable" ["n: Int", "b: Bool"] ["var s = S(1, True)", "var t = s",
  "print(t.n, s.b)"] ["1 True"]
-- A struct without a copying conformance may hold any field.
#guard prints "Movable" ["r: Res", "xs: List[Res]"] ["var s = S(Res(1), [Res(2)])", "print(s.r.id)"]
  ["1"]

-- A struct declared copyable is copyable to the structs that hold it, even
-- when its own fields are the error.
#guard runLines (decls ++ ["@fieldwise_init", "struct Outer(Copyable):", "    var i: Inner",
    "@fieldwise_init", "struct Inner(Copyable):", "    var r: Res", "def main():",
    "    print(1)"]) == some (.rejected ⟨"Inner", .uncopyableField "Inner" "r" res⟩)
-- A field's struct may be declared after it.
#guard runLines (["@fieldwise_init", "struct Outer(Copyable):", "    var i: Inner",
    "@fieldwise_init", "struct Inner(Movable):", "    var x: Int", "def main():",
    "    print(1)"]) == some (.rejected ⟨"Outer", .uncopyableField "Outer" "i" (.struct "Inner")⟩)

-- A method `copy` that the struct writes does not stand for the copy
-- initializer.
#guard runLines (decls ++ ["@fieldwise_init", "struct S(Copyable):", "    var r: Res",
    "    def copy(self) -> Self:", "        return S(Res(self.r.id))", "def main():",
    "    var s = S(Res(4))", "    var t = s.copy()", "    print(t.r.id)"]) ==
  some (.rejected ⟨"S", .uncopyableField "S" "r" res⟩)

-- The compiler reports the error after the first-pass errors of `main`'s
-- body, which comes later, and before the struct is used.
#guard rejectsAt "Copyable" ["r: Res"] ["print(y)"] "main" (.unknownVariable "y")
#guard rejectsAt "Copyable" ["r: Res"] ["var s = S(Res(1))", "var t = s", "print(t.r.id)"] "main"
  (.implicitCopy (.struct "S"))
#guard rejectsAt "Copyable" ["r: Res"] ["var s = S(Res(1))", "var t = s.copy()", "print(t.r.id)"]
  "S" (.uncopyableField "S" "r" res)
-- It comes before a program with no `main` is rejected.
#guard runLines (decls ++ ["@fieldwise_init", "struct S(Copyable):", "    var r: Res",
    "def f():", "    print(1)"]) == some (.rejected ⟨"S", .uncopyableField "S" "r" res⟩)

-- `TrivialRegisterPassable` implies `ImplicitlyCopyable`.
private def trp : List String :=
  ["@fieldwise_init", "struct R(TrivialRegisterPassable):", "    var x: Int"]

#guard runLines (trp ++ ["@fieldwise_init", "struct S(ImplicitlyCopyable):", "    var r: R",
    "def main():", "    var s = S(R(1))", "    var t = s", "    print(t.r.x, s.r.x)"]) ==
  some (.finished ["1 1"])
#guard runLines (trp ++ ["@fieldwise_init", "struct S(Copyable):", "    var rs: List[R]",
    "def main():", "    var s = S([R(1)])", "    var t = s.copy()", "    print(len(t.rs))"]) ==
  some (.finished ["1"])
#guard runLines (trp ++ ["def main():", "    var a = R(1)", "    var b = a", "    b.x = 2",
    "    print(a.x, b.x)"]) == some (.finished ["1 2"])
#guard runLines (trp ++ ["def main():", "    var a = R(1)", "    var b = a.copy()", "    b.x = 2",
    "    print(a.x, b.x)"]) == some (.finished ["1 2"])
#guard runLines (trp ++ ["def take(var r: R):", "    r.x = 5", "    print(r.x)", "def main():",
    "    var a = R(1)", "    take(a)", "    print(a.x)"]) == some (.finished ["5", "1"])

end MojoGrimoireTest.Parse.CopyableFields
