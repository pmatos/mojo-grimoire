import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a place reached through `p^` passed to a `ref` parameter or a
`ref self` receiver (#91). The compiler borrows such a place as a value that
cannot be changed, so a reference that the call returns through it cannot be
changed either, and the call changes nothing. A `ref` binding to the place
itself, `ref r = p^.f`, may still change it. Each expected outcome is the
compiler's. The programs are parsed from text, one line per string, after
the shared declarations.
-/

namespace MojoGrimoireTest.Parse.TransferRef

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  "@fieldwise_init",
  "struct Pair(Movable):",
  "    var r: Res",
  "    var k: Int",
  "    def me(ref self) -> ref [self] Pair:",
  "        return self",
  "    def mine(mut self) -> ref [self] Pair:",
  "        return self",
  "@fieldwise_init",
  "struct H(Movable):",
  "    var l: List[Int]",
  "    var k: Int",
  "    def peek(ref self) -> Int:",
  "        return self.k",
  "def pick(ref x: Int) -> ref [x] Int:",
  "    return x",
  "def touch(ref x: List[Int]):",
  "    print(\"touch\", len(x))",
  "def setk(mut x: Int):",
  "    x = 9"]

/-- Parses, checks and runs the program whose `main` has the body `ls`. -/
private def inMain (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ "def main():" :: ls))).toOption.map (run · 100000)

/-- The rejection of `main` with the error `e`. -/
private def rejects (e : CheckError) : Option Outcome := some (.rejected ⟨"main", e⟩)

private def a : Place := .var "a"
private def r : Place := .var "r"

-- A reference returned through `a^` passed `ref self` or `ref`, at any
-- depth, cannot be changed: not by assignment, and not passed `mut`.
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a^.me()", "    r.k = 5",
    "    print(a.k)"] == rejects (.immutablePlace (.field r "k"))
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a^.me()", "    setk(r.k)",
    "    print(a.k)"] == rejects (.immutablePlace (.field r "k"))
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = pick(a^.k)", "    r = 5",
    "    print(a.k)"] == rejects (.immutablePlace r)
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = pick(pick(a^.k))", "    r = 5",
    "    print(a.k)"] == rejects (.immutablePlace r)
#guard inMain ["    var a = Pair(Res(1), 7)", "    setk(pick(a^.k))", "    print(a.k)"] ==
  rejects (.immutablePlace (.field (.transferred a) "k"))

-- It may still be read, and a method whose `self` is `mut` stays rejected.
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a^.me()", "    print(r.k)"] ==
  some (.finished ["7", "drop 1"])
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a^.mine()", "    r.k = 5"] ==
  rejects (.immutablePlace (.transferred a))

-- Without `^` the reference may be changed, and so may a `ref` binding to a
-- place reached through `a^`.
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a.me()", "    r.k = 5",
    "    print(a.k)"] == some (.finished ["5", "drop 1"])
#guard inMain ["    var a = Pair(Res(1), 7)", "    ref r = a^.k", "    r = 5",
    "    print(a.k)"] == some (.finished ["5", "drop 1"])

-- A call that borrows a place through `h^` changes nothing, so a reference
-- into an element of the list it holds stays valid. Without `^` the call may
-- change the list, and the reference is invalidated.
#guard inMain ["    var h = H([1, 2], 3)", "    ref e = h.l[0]", "    touch(h^.l)",
    "    print(e)"] == some (.finished ["touch 2", "1"])
#guard inMain ["    var h = H([1, 2], 3)", "    ref e = h.l[0]", "    print(h^.peek())",
    "    print(e)"] == some (.finished ["3", "1"])
#guard inMain ["    var h = H([1, 2], 3)", "    ref e = h.l[0]", "    touch(h.l)",
    "    print(e)"] ==
  rejects (.invalidatedReference (.var "e"))
#guard inMain ["    var h = H([1, 2], 3)", "    ref e = h.l[0]", "    print(h.peek())",
    "    print(e)"] ==
  rejects (.invalidatedReference (.var "e"))

end MojoGrimoireTest.Parse.TransferRef
