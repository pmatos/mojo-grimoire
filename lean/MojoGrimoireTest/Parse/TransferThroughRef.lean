import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a transfer through a reference bound with `ref` (#85). The compiler
rejects `t^`, `t.f^`, `t^.f` and `t^.m(…)` on such a reference `t` as an
expression that does not designate a value with an origin, the class
`transferFromElement`, whether `t` is bound to a place or to a call that
returns a reference, and whether it may be changed or not. A `ref` or a
`read` parameter stays `transferFromBorrowed`. `t^` of type `Int` is the
place `t` (#50). Each expected outcome is the compiler's. The programs are
parsed from text, one line per string, after the shared declarations.
-/

namespace MojoGrimoireTest.Parse.TransferThroughRef

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct S(Movable):",
  "    var k: Int",
  "    def take(var self) -> Int:",
  "        return self.k",
  "    def get(self) -> Int:",
  "        return self.k",
  "@fieldwise_init",
  "struct O(Movable):",
  "    var inner: S",
  "def same(ref x: S) -> ref [x] S:",
  "    return x",
  "def samei(ref x: Int) -> ref [x] Int:",
  "    return x"]

/-- Parses, checks and runs the program whose lines are `ls`, after the
declarations. -/
private def go (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)

/-- Parses a `main` whose body is the lines `ls`, and runs it. -/
private def inMain (ls : List String) : Option Outcome := go ("def main():" :: ls)

/-- The rejection of the function `f` with the error `e`. -/
private def rejectsIn (f : Name) (e : CheckError) : Option Outcome :=
  some (.rejected ⟨f, e⟩)

private def t : Place := .var "t"

-- `t^` and `t^.k` on a reference bound to a place.
#guard inMain ["    var s = S(7)", "    ref t = s", "    var u = t^", "    print(u.k)"] ==
  rejectsIn "main" (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.k)"] ==
  rejectsIn "main" (.transferFromElement t)

-- A reference that may be changed is no different.
#guard inMain ["    var s = S(7)", "    ref t = s", "    t = S(3)", "    var u = t^",
    "    print(u.k)"] == rejectsIn "main" (.transferFromElement t)

-- Nor is one bound to a `read` parameter, which cannot be changed.
#guard go ["def f(s: S):", "    ref t = s", "    var u = t^", "    print(u.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejectsIn "f" (.transferFromElement t)
#guard go ["def f(s: S):", "    ref t = s", "    print(t^.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejectsIn "f" (.transferFromElement t)

-- A reference bound to a call that returns a reference.
#guard inMain ["    var s = S(7)", "    ref t = same(s)", "    var u = t^", "    print(u.k)"] ==
  rejectsIn "main" (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = same(s)", "    print(t^.k)"] ==
  rejectsIn "main" (.transferFromElement t)

-- A field of a reference, and a method on `t^`, whatever its `self`.
#guard inMain ["    var o = O(S(7))", "    ref t = o", "    var u = t.inner^", "    print(u.k)"] ==
  rejectsIn "main" (.transferFromElement (.field t "inner"))
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.get())"] ==
  rejectsIn "main" (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.take())"] ==
  rejectsIn "main" (.transferFromElement t)

-- `t^` of type `Int` is the place `t`, so it is not a transfer.
#guard inMain ["    var i = 7", "    ref t = i", "    var u = t^", "    print(u)"] ==
  some (.finished ["7"])
#guard inMain ["    var i = 7", "    ref t = samei(i)", "    var u = t^", "    print(u)"] ==
  some (.finished ["7"])

-- A `ref` or a `read` parameter cannot give its value away.
#guard go ["def f(ref t: S):", "    var u = t^", "    print(u.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejectsIn "f" (.transferFromBorrowed t)
#guard go ["def f(ref t: S):", "    print(t^.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejectsIn "f" (.transferFromBorrowed t)
#guard go ["def f(t: S):", "    var u = t^", "    print(u.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejectsIn "f" (.transferFromBorrowed t)

end MojoGrimoireTest.Parse.TransferThroughRef
