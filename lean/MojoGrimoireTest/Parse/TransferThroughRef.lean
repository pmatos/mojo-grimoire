import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a transfer through a reference bound with `ref` (#85). The compiler
rejects `t^`, `t.f^`, `t^.f` and `t^.m(…)` on such a reference `t` as an
expression that does not designate a value with an origin, the class
`transferFromElement`, whether `t` is bound to a place or to a call that
returns a reference, whether it may be changed or not, even when its
origins are moved away or invalidated, and when `t^` is passed to a `mut`
parameter. A `ref` or a `read` parameter stays
`transferFromBorrowed`, also passed to a `mut` parameter. `t^` of type `Int`
is the place `t` (#50). Each expected outcome is the compiler's, but for the
one marked as the model's departure (#81). The programs are parsed from
text, one line per string, after the shared declarations.
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
  "    return x",
  "def bump(mut x: S):",
  "    x.k += 1",
  "struct W(Movable):",
  "    var k: Int",
  "    def __init__(out self, mut x: S):",
  "        self.k = x.k"]

/-- Parses, checks and runs the program whose lines are `ls`, after the
declarations. -/
private def go (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)

/-- Parses a `main` whose body is the lines `ls`, and runs it. -/
private def inMain (ls : List String) : Option Outcome := go ("def main():" :: ls)

/-- The rejection of the function `f` with the error `e`. -/
private def rejects (e : CheckError) (f : Name := "main") : Option Outcome :=
  some (.rejected ⟨f, e⟩)

private def t : Place := .var "t"

-- `t^` and `t^.k` on a reference bound to a place.
#guard inMain ["    var s = S(7)", "    ref t = s", "    var u = t^", "    print(u.k)"] ==
  rejects (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.k)"] ==
  rejects (.transferFromElement t)

-- A reference that may be changed is no different.
#guard inMain ["    var s = S(7)", "    ref t = s", "    t = S(3)", "    var u = t^",
    "    print(u.k)"] == rejects (.transferFromElement t)

-- Nor is one bound to a `read` parameter, which cannot be changed.
#guard go ["def f(s: S):", "    ref t = s", "    var u = t^", "    print(u.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejects (.transferFromElement t) "f"
#guard go ["def f(s: S):", "    ref t = s", "    print(t^.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejects (.transferFromElement t) "f"

-- A reference bound to a call that returns a reference.
#guard inMain ["    var s = S(7)", "    ref t = same(s)", "    var u = t^", "    print(u.k)"] ==
  rejects (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = same(s)", "    print(t^.k)"] ==
  rejects (.transferFromElement t)

-- A field of a reference, and a method on `t^`, whatever its `self`.
#guard inMain ["    var o = O(S(7))", "    ref t = o", "    var u = t.inner^", "    print(u.k)"] ==
  rejects (.transferFromElement (.field t "inner"))
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.get())"] ==
  rejects (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = s", "    print(t^.take())"] ==
  rejects (.transferFromElement t)

-- The compiler rejects the transfer before it looks at the origins, so a
-- reference whose origin is moved away or invalidated is no different.
#guard go ["def consume(var s: S):", "    print(s.k)", "def main():", "    var s = S(7)",
    "    ref t = s", "    consume(s^)", "    var u = t^", "    print(u.k)"] ==
  rejects (.transferFromElement t)
#guard go ["def consume(var s: S):", "    print(s.k)", "def main():", "    var s = S(7)",
    "    ref t = s", "    consume(s^)", "    print(t^.k)"] ==
  rejects (.transferFromElement t)
#guard go ["def consume(var s: S):", "    print(s.k)", "def main():", "    var o = O(S(7))",
    "    ref t = o", "    consume(o.inner^)", "    var u = t.inner^", "    print(u.k)"] ==
  rejects (.transferFromElement (.field t "inner"))
#guard inMain ["    var l: List[S] = [S(1)]", "    ref t = l[0]", "    l.append(S(2))",
    "    var u = t^", "    print(u.k)"] == rejects (.transferFromElement t)

-- Passed to a `mut` parameter, of a function or an initializer, `t^` is
-- rejected so too. `s^` of a value it owns is not a place: the compiler
-- reports it as a value that cannot change (`immutablePlace`), the model's
-- departure (#81).
#guard inMain ["    var s = S(7)", "    ref t = s", "    bump(t^)"] ==
  rejects (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    ref t = s", "    var w = W(t^)", "    print(w.k)"] ==
  rejects (.transferFromElement t)
#guard inMain ["    var s = S(7)", "    bump(s^)"] == rejects (.notAPlace "bump")

-- Passed to a `mut` parameter, an index of another type is reported first,
-- and a constant index out of range only after the transfer.
#guard inMain ["    var l: List[S] = [S(1)]", "    ref t = l", "    bump(t[True]^)"] ==
  rejects (.typeMismatch .int .bool)
#guard inMain ["    var l: List[S] = [S(1)]", "    ref t = l", "    bump(t[-1]^)"] ==
  rejects (.transferFromElement (.index t (.int (-1))))

-- A `read` or a `ref` parameter cannot give its value away to a `mut`
-- parameter either, of a function or an initializer.
#guard go ["def f(t: S):", "    bump(t^)", "def main():", "    var s = S(7)", "    f(s)"] ==
  rejects (.transferFromBorrowed t) "f"
#guard go ["def f(ref t: S):", "    var w = W(t^)", "    print(w.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejects (.transferFromBorrowed t) "f"
#guard go ["def f(t: O):", "    bump(t.inner^)", "def main():", "    var o = O(S(7))", "    f(o)"] ==
  rejects (.transferFromBorrowed (.field t "inner")) "f"

-- `t^` of type `Int` is the place `t`, so it is not a transfer, also through a
-- returned reference.
#guard inMain ["    var i = 7", "    ref t = samei(i)", "    var u = t^", "    print(u)"] ==
  some (.finished ["7"])

-- A `ref` parameter cannot give its value away.
#guard go ["def f(ref t: S):", "    var u = t^", "    print(u.k)",
    "def main():", "    var s = S(7)", "    f(s)"] == rejects (.transferFromBorrowed t) "f"

end MojoGrimoireTest.Parse.TransferThroughRef
