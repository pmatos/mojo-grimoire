import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a transfer out of an element of a list or an array (#119). The
compiler rejects `l[i]^`, as an expression that does not designate a value
with an origin (`transferFromElement`), once it has typed the place: its
variable, its fields, and each index, whose own type errors, implicit
copies, transfers and exclusivity come first. It rejects it before it looks
at what is initialized or invalidated, the list or an index, and at a
constant index, negative or out of range, also through a reference bound
with `ref`, and when `l[i]^` is passed to a `mut` parameter. A `q^` inside
the place is checked as it is typed. Each expected outcome is the
compiler's, but for the three whose message has no class, marked as the
model's. The programs are parsed from text, one line per string, after
the shared declarations.
-/

namespace MojoGrimoireTest.Parse.TransferElement

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct S(Movable):",
  "    var k: Int",
  "@fieldwise_init",
  "struct O(Movable):",
  "    var inner: S",
  "def g(mut x: S):",
  "    x.k += 1",
  "def consume(var x: S):",
  "    print(x.k)",
  "def own(var x: S) -> Int:",
  "    return x.k",
  "def two(mut a: S, b: S) -> Int:",
  "    return a.k + b.k",
  "struct W(Movable):",
  "    var k: Int",
  "    def __init__(out self, mut x: S):",
  "        self.k = x.k"]

/-- Parses, checks and runs the program whose lines are `ls`, after the
declarations. -/
private def go (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)

/-- Parses a `main` whose body is the lines `ls`, after a list `l` of one
`S`, and runs it. -/
private def inMain (ls : List String) : Option Outcome :=
  go ("def main():" :: "    var l: List[S] = [S(1)]" :: ls)

/-- The rejection of the function `f` with the error `e`. -/
private def rejects (e : CheckError) (f : Name := "main") : Option Outcome :=
  some (.rejected ⟨f, e⟩)

/-- The element `x[k]`. -/
private def at_ (x : Name) (k : Int) : Place := .index (.var x) (.int k)

-- The list is moved away: the transfer is reported, not the list, as a
-- value, through a field and a method, and passed `var` or `mut`, to a
-- function or an initializer.
#guard inMain ["    var m = l^", "    var u = l[0]^", "    print(u.k, len(m))"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard go ["def main():", "    var l: List[O] = [O(S(1))]", "    var m = l^",
    "    var u = l[0].inner^", "    print(u.k, len(m))"] ==
  rejects (.transferFromElement (.field (at_ "l" 0) "inner"))
#guard inMain ["    var m = l^", "    print(l[0]^.k, len(m))"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard inMain ["    var m = l^", "    consume(l[0]^)", "    print(len(m))"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard inMain ["    var m = l^", "    g(l[0]^)", "    print(len(m))"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard inMain ["    var m = l^", "    var w = W(l[0]^)", "    print(w.k, len(m))"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard go ["def main():", "    var a: Array[S, 1] = [S(0)]", "    var b = a^",
    "    var u = a[0]^", "    print(u.k, b[0].k)"] ==
  rejects (.transferFromElement (at_ "a" 0))

-- Passed to a `mut` parameter, an element is no place either, also of a
-- `read` or a `ref` parameter.
#guard inMain ["    g(l[0]^)"] == rejects (.transferFromElement (at_ "l" 0))
#guard go ["def f(x: List[S]):", "    g(x[0]^)", "def main():",
    "    var l: List[S] = [S(1)]", "    f(l)"] == rejects (.transferFromElement (at_ "x" 0)) "f"
#guard go ["def f(ref x: List[S]):", "    g(x[0]^)", "def main():",
    "    var l: List[S] = [S(1)]", "    f(l)"] == rejects (.transferFromElement (at_ "x" 0)) "f"

-- A constant index out of range is reported after the transfer, also
-- through a reference, and passed `mut`.
#guard inMain ["    var u = l[-1]^", "    print(u.k)"] ==
  rejects (.transferFromElement (at_ "l" (-1)))
#guard inMain ["    ref t = l", "    var u = t[-1]^", "    print(u.k)"] ==
  rejects (.transferFromElement (at_ "t" (-1)))
#guard inMain ["    print(l[-1]^.k)"] == rejects (.transferFromElement (at_ "l" (-1)))
#guard inMain ["    g(l[-1]^)"] == rejects (.transferFromElement (at_ "l" (-1)))
#guard go ["def main():", "    var a: Array[S, 2] = [S(1), S(2)]", "    var u = a[5]^",
    "    print(u.k)"] == rejects (.transferFromElement (at_ "a" 5))
#guard go ["def main():", "    var a: Array[S, 2] = [S(1), S(2)]", "    ref t = a",
    "    var u = t[5]^", "    print(u.k)"] == rejects (.transferFromElement (at_ "t" 5))

-- So is an uninitialized or invalidated index.
#guard inMain ["    var i: Int", "    var u = l[i]^", "    print(u.k)"] ==
  rejects (.transferFromElement (.index (.var "l") (.place (.var "i"))))
#guard inMain ["    var n: List[Int] = [0]", "    ref r = n[0]", "    n.append(1)",
    "    var u = l[r]^", "    print(u.k)"] ==
  rejects (.transferFromElement (.index (.var "l") (.place (.var "r"))))

-- The place is typed first, from its variable outward: an unknown name or
-- field comes first, and so does an index's own implicit copy or
-- exclusivity, as a value or passed `mut`.
#guard inMain ["    var u = l[-1].nope^", "    print(u.k)"] == rejects (.unknownAttribute "S" "nope")
#guard inMain ["    var i: Int", "    var u = zz[i]^", "    print(u.k)"] ==
  rejects (.unknownVariable "zz")
#guard inMain ["    var u = l[zz].nope^", "    print(u.k)"] == rejects (.unknownVariable "zz")
#guard inMain ["    g(l[zz].nope^)"] == rejects (.unknownVariable "zz")
#guard inMain ["    var s = S(0)", "    var u = l[own(s)]^", "    print(u.k)"] ==
  rejects (.implicitCopy (.struct "S"))
#guard inMain ["    var s = S(0)", "    g(l[own(s)]^)"] == rejects (.implicitCopy (.struct "S"))
#guard inMain ["    var s = S(0)", "    g(l[two(s, s)]^)"] ==
  rejects (.argumentExclusivity (.var "s"))

-- A `q^` inside the place is checked as it is typed: an element or a
-- reference cannot be transferred, nor a `read` parameter, before a field
-- after it is looked up.
#guard inMain ["    var u = l[0]^.nope^", "    print(u.k)"] ==
  rejects (.transferFromElement (at_ "l" 0))
#guard inMain ["    g(l[0]^.nope^)"] == rejects (.transferFromElement (at_ "l" 0))
#guard go ["def main():", "    var o = O(S(1))", "    ref r = o", "    var u = r^.nope^",
    "    print(u.k)"] == rejects (.transferFromElement (.var "r"))
#guard go ["def f(x: O):", "    var u = x^.nope^", "    print(u.k)", "def main():",
    "    f(O(S(1)))"] == rejects (.transferFromBorrowed (.var "x")) "f"

-- A place that is not a list or an array is reported before its index;
-- the compiler's "not subscriptable" has no class.
#guard inMain ["    var s = S(0)", "    g(s[zz]^)"] == rejects (.notAList (.struct "S"))

-- An inner `q^` of an `Int` is the place `q`, and the compiler types an
-- index into an `Int` before it finds no element (#127).
#guard go ["def main():", "    var n: List[Int] = [1]", "    var u = n[0]^.nope^",
    "    print(u)"] == rejects (.unknownAttribute "Int" "nope")
#guard go ["def f(x: S):", "    var u = x.k^.nope^", "    print(u)", "def main():",
    "    f(S(1))"] == rejects (.unknownAttribute "Int" "nope") "f"
#guard go ["def main():", "    var n = 5", "    var u = n[zz]^", "    print(u)"] ==
  rejects (.unknownVariable "zz")

-- A `Bool` index: the compiler finds no `__getitem__`, a message with no
-- class (#88); the model reports the index's type.
#guard inMain ["    var u = l[True]^", "    print(u.k)"] == rejects (.typeMismatch .int .bool)
#guard inMain ["    g(l[True]^)"] == rejects (.typeMismatch .int .bool)

end MojoGrimoireTest.Parse.TransferElement
