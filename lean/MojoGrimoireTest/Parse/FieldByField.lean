import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a struct variable declared without a value and built field by
field (#51). Each expected outcome is the pinned compiler's, except where
the compiler destroys a variable with a field never assigned, a compiler
bug (D-0003): there the model rejects the program, as the compiler does
when the field was moved out (R, ruled on 2026-11-19, provisional). The
programs are parsed from text, one line per string, after the shared
declarations.
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
    "    t.a = Pt(7, 8)", "    t.b = Pt(1, 2)", "    print(t.a.x)"] == some (.finished ["5 6", "7"])

-- A variable, or a part assigned whole, may not end with a field never
-- assigned while it holds another (D-0003): the compiler destroys it whole,
-- and prints `drop 0` for `t.b`, `o.w.r` and the old `o.w.r`. It is so even
-- when every field is an `Int`, where the compiler's output shows nothing.
#guard destroyed "t" ["    var t: Two", "    t.a = Res(1)", "    print(t.a.id)"]
#guard destroyed "o" ["    var o: Outer", "    o.z = 3", "    print(o.z)"]
#guard destroyed "o" ["    var o: Outer", "    o.w.k = 1", "    print(o.w.k)",
    "    o.w = Wrap(Res(5), 2)", "    print(o.w.k)"]
#guard destroyed "t" ["    var t: Two", "    t.a = Res(1)", "    t = Two(Res(2), Res(3))",
    "    print(t.a.id)"]
#guard destroyed "t" ["    var t: Line", "    t.a.x = 5", "    print(t.a.x)"]
#guard destroyed "p" ["    var p: Pt", "    p.x = 1", "    print(p.x)"]

-- On some path is enough, as the compiler counts a field moved out on one
-- path only: built in one branch only, or in a loop, even wholly, or built
-- in one branch and moved out in the other. Assigned whole in one branch
-- only, it may end.
#guard destroyed "t" ["    var c = True", "    var t: Two", "    if c:", "        t.a = Res(1)",
    "        t.b = Res(2)", "    print(c)"]
#guard destroyed "t" ["    var c = True", "    var t: Two", "    if c:", "        t.b = Res(2)",
    "        t.a = Res(1)", "    else:", "        t.a = Res(3)", "        var s = t.a^",
    "        print(s.id)", "    print(c)"]
#guard destroyed "t" ["    var i = 0", "    var t: Line", "    while i < 2:", "        t.a = Pt(i, i)",
    "        i = i + 1", "    print(i)"]
#guard destroyed "t" ["    var i = 0", "    var t: Line", "    while i < 2:", "        t.a = Pt(i, i)",
    "        t.b = Pt(i, i)", "        i = i + 1", "    print(i)"]
#guard inMain ["    var c = True", "    var t: Two", "    if c:", "        t = Two(Res(1), Res(2))",
    "    print(c)"] == some (.finished ["drop 1", "drop 2", "True"])
-- So may one held whole on one path, with a field moved out and assigned
-- again, and moved out whole on the other.
#guard inMain ["    var c = True", "    var t = Two(Res(1), Res(2))", "    var y = t.a^",
    "    t.a = Res(3)", "    print(y.id)", "    if c:", "        var z = t^",
    "        print(z.a.id)", "    t = Two(Res(4), Res(5))", "    print(t.b.id)"] ==
  some (.finished ["1", "drop 1", "3", "drop 3", "drop 2", "5", "drop 4", "drop 5"])

-- Each field of the `self` of `__deinit__` is a value of its own: one may
-- stay moved out, but not end partly built.
#guard inMain ["    var k = Keep(Pt(5, 6), Pt(7, 8))", "    print(k.b.y)"] [
    "@fieldwise_init",
    "struct Keep(Movable):",
    "    var a: Pt",
    "    var b: Pt",
    "    def __deinit__(deinit self):",
    "        var k = self.a^",
    "        self.a.x = 1",
    "        print(k.x, self.a.x)"] ==
  some (.rejected ⟨"Keep.__deinit__", .partiallyDestroyed "self"⟩)
#guard inMain ["    var k = Keep(Two(Res(1), Res(2)), 1)", "    print(k.n)"] [
    "@fieldwise_init",
    "struct Keep(Movable):",
    "    var a: Two",
    "    var n: Int",
    "    def __deinit__(deinit self):",
    "        var c = self.n > 0",
    "        if c:",
    "            var k = self.a^",
    "            print(k.a.id)",
    "        else:",
    "            var y = self.a.a^",
    "            print(y.id)",
    "            self.a.a = Res(9)",
    "        print(\"keep\")"] == some (.finished ["1", "1", "drop 1", "drop 2", "keep"])

-- A struct with a destructor of its own runs it once every field is
-- assigned, and may not end with a field never assigned.
#guard inMain ["    var b: Box", "    b.a = Res(1)", "    b.b = Res(2)", "    print(b.a.id)"] ==
  some (.finished ["1", "drop 1", "drop 2", "box"])
#guard destroyed "b" ["    var b: Box", "    b.a = Res(1)", "    print(b.a.id)"]
#guard destroyed "b" ["    var c = True", "    var b: Box", "    if c:", "        b.a = Res(1)",
    "    print(c)"]
#guard destroyed "b" ["    var c = True", "    var b: Box", "    while c:", "        b.a = Res(1)",
    "        c = False", "    print(c)"]

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
    "    t.a = Pt(5, 6)", "    t.b = Pt(7, 8)", "    print(s.x, t.a.x)"] == some (.finished ["3 5"])
#guard destroyed "o" ["    var o = Outer(Wrap(Res(1), 2), 3)", "    var s = o.w.r^",
    "    o.w = Wrap(Res(4), 5)", "    print(s.id, o.z)"]
#guard inMain ["    var t = Line(Pt(1, 2), Pt(3, 4))", "    t.a.x = 9", "    var u = t^",
    "    t.a = Pt(5, 6)", "    var s = t.a^", "    print(u.a.x, s.y)"] == some (.finished ["9 6"])
#guard inMain ["    var i = 0", "    var t: Line", "    while i < 2:", "        t.a = Pt(i, i)",
    "        var s = t.a^", "        print(s.x)", "        i = i + 1"] ==
  some (.finished ["0", "1"])
#guard destroyed "t" ["    var c = True", "    var t: Line", "    t.a = Pt(1, 2)", "    while c:",
    "        t.a.x = 3", "        c = False", "    var s = t.a^", "    print(s.x)"]

-- What a loop body moves out counts after the loop, and in the next
-- iteration: a field moved out while another part is held, a whole move
-- followed by a field, and an overwrite of a part with a field moved out.
#guard destroyed "t" ["    var i = 0", "    var t: Line", "    while i < 2:", "        t.a = Pt(i, i)",
    "        t.b = Pt(i, 7)", "        var s = t.a^", "        print(s.x)", "        i = i + 1"]
#guard destroyed "t" ["    var i = 0", "    var t: Line", "    while i < 2:",
    "        t = Line(Pt(i, i), Pt(i, i))", "        var u = t^", "        t.a = Pt(5, i)",
    "        print(u.a.x)", "        i = i + 1"]
#guard destroyed "t" ["    var i = 0", "    var t: Two", "    while i < 2:",
    "        t = Two(Res(i), Res(i + 10))", "        var s = t.a^", "        print(s.id)",
    "        i = i + 1", "    t.a = Res(7)"]

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
#guard inMain ["    var t: Line", "    t.a.x = 1", "    var u = t.a.x", "    t.a.y = 2",
    "    t.b = Pt(3, 4)", "    print(u)"] == some (.finished ["1"])
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
-- A `mut` parameter left uninitialized is reported before a variable that
-- may not end, as the compiler reports it first.
#guard inMain ["    var q = Two(Res(3), Res(4))", "    takeA(q)"] [
    "def takeA(mut q: Two):",
    "    var t: Two",
    "    t.b = Res(2)",
    "    var j = q.a^",
    "    print(t.b.id, j.id)"] ==
  some (.rejected ⟨"takeA", .uninitializedAtExit "q"⟩)
#guard inMain ["    var m = Pt(1, 2)", "    half(m)", "    print(m.x)"] [
    "def half(mut p: Pt):",
    "    var q = p^",
    "    p.x = q.y"] ==
  some (.rejected ⟨"half", .uninitializedAtExit "p"⟩)
#guard inMain ["    var w = Redo(4)", "    print(w.a.x)"] [
    "struct Redo(Movable):",
    "    var a: Pt",
    "    var b: Pt",
    "    def __init__(out self, n: Int):",
    "        self.a = Pt(n, n)",
    "        self.b = Pt(n, n)",
    "        var c = self^",
    "        self.a = Pt(c.a.x + 1, 0)",
    "        self.b = Pt(0, 0)"] ==
  some (.rejected ⟨"Redo.__init__", .uninitializedUse (.var "self")⟩)
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
