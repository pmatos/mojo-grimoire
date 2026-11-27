import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the routes to a temporary origin argument that the checker keeps
rejected (#80): the compiler accepts each one, but the model would either
read a temporary after it is destroyed, or destroy it twice. Each test
names the issue that will make the model accept the program, and gives the
compiler's output (nightly 1.3.0.dev2026111905) in its comment. Then come
the aliases through a temporary, which the compiler rejects too. Each
program is parsed from text, one line per string, after the shared
declarations.
-/

namespace MojoGrimoireTest.Check.TempRefs

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations every program starts with. `S2` has a subscript that
Mojo reads late, since it declares `__setitem__` (#191). -/
private def decls : List String := [
  "@fieldwise_init",
  "struct T(Movable):",
  "    var v: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.v)",
  "@fieldwise_init",
  "struct P(ImplicitlyCopyable):",
  "    var v: Int",
  "    def __deinit__(deinit self):",
  "        print(\"pdrop\", self.v)",
  "struct S2(Movable):",
  "    var n: Int",
  "    def __init__(out self):",
  "        self.n = 0",
  "    def __getitem__(self, i: Int) -> P:",
  "        print(\"get\", i)",
  "        return P(i + 7)",
  "    def __setitem__(mut self, i: Int, v: Int):",
  "        print(\"set\", i)",
  "def same(ref x: T) -> ref [x] T:",
  "    return x",
  "def psame(ref x: P) -> ref [x] P:",
  "    return x",
  "def pick(ref a: T, ref b: T, first: Bool) -> ref [a, b] T:",
  "    if first:",
  "        return a",
  "    return b",
  "def rpick(a: P, b: P, first: Bool) -> ref [a, b] P:",
  "    if first:",
  "        return a",
  "    return b",
  "def rd(x: P) -> Int:",
  "    print(\"rd\", x.v)",
  "    return x.v",
  "def vv(ref x: T) -> Int:",
  "    return x.v",
  "def pz(x: T) -> Int:",
  "    print(\"pz\", x.v)",
  "    return x.v",
  "def mk(v: Int) -> T:",
  "    print(\"mk\", v)",
  "    return T(v)",
  "def pmk(v: Int) -> P:",
  "    print(\"pmk\", v)",
  "    return P(v)"]

/-- The error that rejects the program whose functions after the
declarations are the lines `ls`, and the function it is in. -/
private def rejection (ls : List String) : Option (Name × CheckError) :=
  match parse ("\n".intercalate (decls ++ ls)) with
  | .ok p => match run p 100000 with
    | .rejected r => some (r.decl, r.error)
    | _ => none
  | .error _ => none

-- A late subscript as an origin argument of a `ref` binding (#378). The
-- compiler prints `get 1`, `mid`, `rd 8`, `pdrop 8`, `pdrop 5`, `8`.
#guard rejection ["def main():", "    var s = S2()", "    ref r = rpick(s[1], P(5), True)",
    "    print(\"mid\")", "    print(rd(r))"] == some ("main", .notAPlace "rpick")

-- The same inside a function, whose other origin argument is a parameter.
-- The compiler prints `get 2`, `mid`, `rd 9`, `pdrop 9`, `pdrop 1`, `9`.
#guard rejection ["def g(ref y: P) -> Int:", "    var s = S2()",
    "    ref r = rpick(s[2], y, True)", "    print(\"mid\")", "    return rd(r)",
    "def main():", "    var a = P(1)", "    print(g(a))"] == some ("g", .notAPlace "rpick")

-- A temporary origin argument in a read place's index (#377). The compiler
-- prints `mk 1`, `pz 1`, `drop 1`, `20`.
#guard rejection ["def main():", "    var xs = [10, 20, 30]", "    print(xs[pz(same(mk(1)))])"] ==
  some ("main", .implicitCopy (.struct "T"))

-- The same in the index of a place bound with `ref`. The compiler prints
-- `mk 2`, `pz 2`, `drop 2`, `2`, `drop 0`, `drop 1`, `drop 2`.
#guard rejection ["def main():", "    var ts = [T(0), T(1), T(2)]",
    "    ref e = ts[pz(same(mk(2)))]", "    print(e.v)"] == some ("main", .implicitCopy (.struct "T"))

-- An expression statement that returns a reference through one bound to a
-- temporary (#379). The compiler prints `pmk 1`, `1`, `pdrop 1`.
#guard rejection ["def main():", "    ref r = psame(pmk(1))", "    psame(r)", "    print(r.v)"] ==
  some ("main", .notAPlace "psame")

-- A reference into a temporary and a place it aliases, passed mutably to
-- the other `ref` parameter: the compiler reports the aliasing (#381).
#guard rejection ["def main():", "    var y = T(5)", "    ref r = pick(y, T(1), True)",
    "    print(vv(pick(r, y, False)))"] == some ("main", .argumentExclusivity (.var "y"))

#guard rejection ["def main():", "    var y = T(5)",
    "    print(vv(pick(pick(y, T(1), True), y, False)))"] ==
  some ("main", .argumentExclusivity (.var "y"))

end MojoGrimoireTest.Check.TempRefs
