import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a struct variable declared without a value and built field by
field (#51). Each expected outcome is the pinned compiler's, except where
the compiler destroys a field that was never assigned, a compiler bug
(D-0003): there the model destroys only the fields assigned. The programs
are parsed from text, one line per string, after the shared declarations.
-/

namespace MojoGrimoireTest.Parse.FieldByField

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  "@fieldwise_init",
  "struct Two(Movable):",
  "    var a: Res",
  "    var b: Res",
  "@fieldwise_init",
  "struct Box(Movable):",
  "    var a: Res",
  "    var b: Res",
  "    def __deinit__(deinit self):",
  "        print(\"box\")",
  "@fieldwise_init",
  "struct Pt(Movable):",
  "    var x: Int",
  "    var y: Int",
  "@fieldwise_init",
  "struct Line(Movable):",
  "    var a: Pt",
  "    var b: Pt",
  "@fieldwise_init",
  "struct Wrap(Movable):",
  "    var r: Res",
  "    var k: Int",
  "@fieldwise_init",
  "struct Outer(Movable):",
  "    var w: Wrap",
  "    var z: Int",
  "def showPt(p: Pt):",
  "    print(p.x, p.y)"]

/-- Parses, checks and runs a `main` whose body is the lines `ls`, after
the shared declarations and the declarations `more`. -/
private def inMain (ls : List String) (more : List String := []) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ more ++ "def main():" :: ls))).toOption.map (run · 100000)

/-- Whether `main`, whose body is the lines `ls`, is rejected as
`partiallyDestroyed` of `x`. -/
private def destroyed (x : Name) (ls : List String) : Bool :=
  inMain ls == some (.rejected ⟨"main", .partiallyDestroyed x⟩)

/-- Whether `main`, whose body is the lines `ls`, is rejected as a use of
the uninitialized place `p`. -/
private def unused (p : Place) (ls : List String) : Bool :=
  inMain ls == some (.rejected ⟨"main", .uninitializedUse p⟩)

private def fld (x f : Name) : Place := .field (.var x) f

-- The fields hold what was assigned to them, nested ones included.
#guard inMain ["    var p: Pt", "    p.x = 1", "    p.y = 2", "    print(p.x, p.y)"] ==
  some (.finished ["1 2"])
#guard inMain ["    var t: Line", "    t.a.x = 5", "    t.a.y = 6", "    print(t.a.x, t.a.y)",
    "    t.a = Pt(7, 8)", "    print(t.a.x)"] == some (.finished ["5 6", "7"])

-- Only the fields assigned are destroyed (D-0003): the compiler also prints
-- `drop 0` for `t.b`, `o.w.r` and the old `o.w.r`.
#guard inMain ["    var t: Two", "    t.a = Res(1)", "    print(t.a.id)"] ==
  some (.finished ["1", "drop 1"])
#guard inMain ["    var o: Outer", "    o.z = 3", "    print(o.z)"] == some (.finished ["3"])
#guard inMain ["    var o: Outer", "    o.w.k = 1", "    print(o.w.k)", "    o.w = Wrap(Res(5), 2)",
    "    print(o.w.k)"] == some (.finished ["1", "2", "drop 5"])
#guard inMain ["    var t: Two", "    t.a = Res(1)", "    t = Two(Res(2), Res(3))",
    "    print(t.a.id)"] == some (.finished ["drop 1", "2", "drop 2", "drop 3"])

-- A struct with a destructor of its own runs it once every field is
-- assigned, and may not end with a field never assigned.
#guard inMain ["    var b: Box", "    b.a = Res(1)", "    b.b = Res(2)", "    print(b.a.id)"] ==
  some (.finished ["1", "drop 1", "drop 2", "box"])
#guard destroyed "b" ["    var b: Box", "    b.a = Res(1)", "    print(b.a.id)"]

-- A field moved out of a struct that holds nothing else does not stop it
-- from ending; nothing of it is destroyed, its destructor included.
#guard inMain ["    var t: Line", "    t.a = Pt(1, 2)", "    var s = t.a^", "    print(s.x)"] ==
  some (.finished ["1"])
#guard inMain ["    var t: Two", "    t.b = Res(2)", "    t.a = Res(1)", "    var s = t.b^",
    "    var u = t.a^", "    print(s.id, u.id)"] == some (.finished ["2 1", "drop 1", "drop 2"])
#guard inMain ["    var b: Box", "    b.a = Res(1)", "    var s = b.a^", "    print(s.id)"] ==
  some (.finished ["1", "drop 1"])
#guard inMain ["    var t: Line", "    t.a = Pt(1, 2)", "    var s = t.a^",
    "    t = Line(Pt(5, 6), Pt(7, 8))", "    print(s.x, t.a.x)"] == some (.finished ["1 5"])
#guard inMain ["    var t = Line(Pt(1, 2), Pt(3, 4))", "    var u = t^", "    t.a = Pt(5, 6)",
    "    var s = t.a^", "    print(u.a.x, s.x)"] == some (.finished ["1 5"])

-- It does when the struct still holds a part, when the struct was held
-- whole on some path, or when the field's inside was assigned.
#guard destroyed "t" ["    var t: Line", "    t.a = Pt(1, 2)", "    var s = t.a^",
    "    t.b = Pt(3, 4)", "    print(s.x)"]
#guard destroyed "t" ["    var c = True", "    var t: Line", "    if c:",
    "        t = Line(Pt(1, 2), Pt(3, 4))", "    else:", "        t.a = Pt(5, 6)",
    "    var s = t.a^", "    print(s.x)"]
#guard destroyed "t" ["    var t = Line(Pt(1, 2), Pt(3, 4))", "    var s = t.a^",
    "    t.a = Pt(5, 6)", "    var m = t.a^", "    var h = t.b^", "    print(s.x, m.x, h.x)"]
#guard destroyed "t" ["    var t: Line", "    t.a = Pt(1, 2)", "    t.a.x = 3", "    var s = t.a^",
    "    print(s.x)"]
#guard inMain ["    var t: Line", "    t.a = Pt(1, 2)", "    t.a.x = 3", "    var s = t.a^",
    "    t.a = Pt(5, 6)", "    print(s.x, t.a.x)"] == some (.finished ["3 5"])

-- A variable moved out whole and given some of its fields, and a part moved
-- out and given some of its fields then assigned whole, are rejected.
#guard destroyed "p" ["    var p = Pt(1, 2)", "    var q = p^", "    p.x = 3", "    print(q.x, p.x)"]
#guard destroyed "t" ["    var t = Line(Pt(1, 2), Pt(3, 4))", "    var s = t.a^",
    "    t.a.x = 5", "    t.a = Pt(7, 8)", "    print(t.a.x, s.y)"]
#guard destroyed "t" ["    var t: Line", "    t.a = Pt(1, 2)", "    var s = t.a^",
    "    t.a.x = 7", "    t.a = Pt(8, 9)", "    print(s.x, t.a.x)"]

-- A struct, or a part, built field by field is never whole, even once every
-- field is assigned. The `self` of `__init__` is whole once its fields are.
#guard unused (.var "p") ["    var p: Pt", "    p.x = 1", "    p.y = 2", "    var q = p^",
    "    print(q.x)"]
#guard unused (.var "p") ["    var p: Pt", "    p.x = 1", "    p.y = 2", "    showPt(p)"]
#guard unused (fld "t" "a") ["    var t: Line", "    t.a.x = 1", "    t.a.y = 2", "    showPt(t.a)"]
#guard unused (.var "t") ["    var t: Line", "    t.a = Pt(1, 2)", "    t.b = Pt(3, 4)",
    "    var u = t^", "    print(u.a.x)"]
#guard inMain ["    var t: Line", "    t.a.x = 1", "    var u = t.a.x", "    print(u)"] ==
  some (.finished ["1"])
-- A part of `self` built field by field in `__init__` is not whole at its
-- return, nor is a `mut` parameter, or a part of one, built so.
#guard inMain ["    var m = Made()", "    print(m.b.y)"] [
    "struct Made(Movable):",
    "    var a: Pt",
    "    var b: Pt",
    "    def __init__(out self):",
    "        self.a.x = 1",
    "        self.a.y = 2",
    "        self.b = Pt(3, 4)"] ==
  some (.rejected ⟨"Made.__init__", .uninitializedAtExit "self"⟩)
#guard inMain ["    var m = Pt(1, 2)", "    flipPt(m)", "    print(m.x)"] [
    "def flipPt(mut p: Pt):",
    "    var q = p^",
    "    p.x = q.y",
    "    p.y = q.x"] ==
  some (.rejected ⟨"flipPt", .uninitializedUse (.var "p")⟩)
#guard inMain ["    var m = Line(Pt(1, 2), Pt(3, 4))", "    flipA(m)", "    print(m.a.x)"] [
    "def flipA(mut l: Line):",
    "    var q = l.a^",
    "    l.a.x = q.y",
    "    l.a.y = q.x"] ==
  some (.rejected ⟨"flipA", .uninitializedAtExit "l"⟩)
#guard inMain ["    var w = Whole()", "    print(w.get())"] [
    "struct Whole(Movable):",
    "    var x: Int",
    "    var y: Int",
    "    def __init__(out self):",
    "        self.x = 1",
    "        self.y = 2",
    "    def get(self) -> Int:",
    "        return self.x + self.y"] == some (.finished ["3"])

end MojoGrimoireTest.Parse.FieldByField
