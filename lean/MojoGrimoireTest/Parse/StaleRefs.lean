import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of references into the elements of a list once the list changes.
Changing a list as a whole, by assigning it, passing it `mut` or `ref`, or
calling `append` or `pop` on it, invalidates every reference into its
elements: a `ref` binding, or an operand located before a later operand
changed the list. Assigning into an element the result of a call that is
passed the list `mut` is rejected too. Each verdict and output is the
pinned compiler's for the program.
-/

namespace MojoGrimoireTest.Parse.StaleRefs

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The declarations the programs share: `S` holds a list, `R` has a method
that changes it and one that builds an `R`, and the functions take a list
`mut`, `ref` or `read`. -/
private def lib : List String := [
  "@fieldwise_init",
  "struct R(Movable):",
  "    var v: Int",
  "    def make(mut self) -> R:",
  "        return R(self.v)",
  "    def bump(mut self) -> Int:",
  "        self.v += 1",
  "        return self.v",
  "",
  "@fieldwise_init",
  "struct S(Movable):",
  "    var xs: List[Int]",
  "    var rs: List[R]",
  "    var r: R",
  "    def build(mut self) -> R:",
  "        return R(len(self.rs))",
  "",
  "def grow(mut xs: List[Int]) -> Int:",
  "    xs.append(7)",
  "    return 1",
  "",
  "def touch(ref xs: List[Int]):",
  "    pass",
  "",
  "def touchS(mut s: S):",
  "    pass",
  "",
  "def peek(xs: List[Int]) -> Int:",
  "    return xs[0]",
  "",
  "def two(a: Int, b: Int) -> Int:",
  "    return a + b",
  "",
  "def mk(mut rs: List[R]) -> R:",
  "    return R(len(rs))",
  "",
  "def mkRead(rs: List[R]) -> R:",
  "    return R(len(rs))",
  ""]

/-- The program whose `main` starts with the variables every test uses,
then runs `body`. -/
private def prog (body : List String) : List String :=
  lib ++ "def main():" :: ([
    "var xs: List[Int] = [1, 2]",
    "var xss: List[List[Int]] = [[1], [2]]",
    "var rs: List[R] = [R(1), R(2)]",
    "var s = S([1, 2], [R(1), R(2)], R(0))",
    "var arr = [1, 2]"] ++ body).map ("    " ++ ·)

private def stale (body : List String) (p : Place) : Bool :=
  runLines (prog body) == some (.rejected ⟨"main", .invalidatedReference p⟩)

private def aliased (body : List String) (p : Place) : Bool :=
  runLines (prog body) == some (.rejected ⟨"main", .argumentExclusivity p⟩)

private def prints (body : List String) (out : List String) : Bool :=
  runLines (prog body) == some (.finished out)

private def e : Place := .var "e"
private def x (n : Name) : Place := .var n
private def at_ (p : Place) (i : Int) : Place := .index p (.int i)

-- A `ref` binding into an element is invalidated by a change to the list.
#guard stale ["ref e = xs[1]", "xs.append(3)", "print(e)"] e
#guard stale ["ref e = xs[1]", "print(xs.pop())", "print(e)"] e
#guard stale ["ref e = xs[1]", "print(grow(xs))", "print(e)"] e
#guard stale ["ref e = xs[0]", "touch(xs)", "print(e)"] e
#guard stale ["ref e = xs[0]", "xs = [9]", "print(e)"] e
#guard stale ["ref e = xs[1]", "xs.append(3)", "e = 4"] e
-- ... or by a change to a place that holds the list.
#guard stale ["ref e = s.xs[0]", "s.xs.append(1)", "print(e)"] e
#guard stale ["ref e = s.xs[0]", "touchS(s)", "print(e)"] e
#guard stale ["ref e = s.xs[0]", "s = S([3], [R(0)], R(1))", "print(e)"] e
-- ... through another reference to the list.
#guard stale ["ref e = xs[0]", "ref ys = xs", "ys.append(1)", "print(e)"] e
#guard stale ["ref ys = xs", "ref e = ys[0]", "xs.append(1)", "print(e)"] e
-- Any element of a list of lists may be the one that changed.
#guard stale ["ref e = xss[0][0]", "xss[1].append(5)", "print(e)"] e
#guard stale ["ref e = xss[0][0]", "xss[0].append(5)", "print(e)"] e
-- On some path: after an `if`, or on the next iteration of a loop.
#guard stale ["ref e = xs[0]", "if len(xs) > 5:", "    xs.append(1)", "print(e)"] e
#guard stale ["ref e = xs[0]", "var i = 0", "while i < 2:", "    print(e)",
  "    xs.append(i)", "    i += 1"] e
#guard stale ["ref e = xs[0]", "var i = 0", "while e < 2:",
  "    xs.append(i)", "    i += 1"] e

-- An element operand located before a later operand changes its list.
#guard stale ["print(xs[1], xs.pop())"] (at_ (x "xs") 1)
#guard stale ["var y = xs[1] + xs.pop()"] (at_ (x "xs") 1)
#guard stale ["print(xs[0] + grow(xs))"] (at_ (x "xs") 0)
#guard stale ["print(two(xs[0], grow(xs)))"] (at_ (x "xs") 0)
#guard stale ["print(xs[0], len(xs), xs.pop())"] (at_ (x "xs") 0)
#guard stale ["ref e = xs[0]", "print(e, xs.pop())"] e

-- What keeps a reference valid: changing one element, reading the list,
-- changing another field, changing an element of the list, or an array.
#guard prints ["ref e = xs[1]", "xs[0] = 5", "xs[1] = 6", "print(e)"] ["6"]
#guard prints ["ref e = xs[1]", "print(peek(xs), len(xs))", "var t = xs.copy()", "print(e)"]
  ["1 2", "2"]
#guard prints ["ref e = s.xs[0]", "s.r = R(5)", "print(e)"] ["1"]
#guard prints ["ref e = xs", "xs.append(3)", "print(len(e))"] ["3"]
#guard prints ["ref e = xss[0]", "xss[0].append(5)", "print(len(e))"] ["2"]
#guard prints ["ref e = rs[0]", "print(e.v, rs[1].bump())"] ["1 3"]
#guard prints ["ref e = rs[0].v", "print(rs[0].bump())", "print(e)"] ["2", "2"]
#guard prints ["ref e = arr[0]", "arr = [7, 8]", "print(e)"] ["7"]
#guard prints ["ref e = xs[0]", "print(e)", "xs.append(3)", "ref f = xs[0]", "print(f)"]
  ["1", "1"]
-- A change made before the element operand is located, or inside its index.
#guard prints ["print(grow(xs), xs[0])"] ["1 1"]
#guard prints ["print(xs[xs.pop() - 2])"] ["1"]

-- An element assigned the result of a call that builds it in place, and is
-- passed `mut` the list or a place that holds it.
#guard aliased ["xs[0] = xs.pop()"] (x "xs")
#guard aliased ["xss[0][0] = xss[1].pop()"] (at_ (x "xss") 1)
#guard aliased ["rs[0] = mk(rs)"] (x "rs")
#guard aliased ["s.xs[0] = s.xs.pop()"] (.field (x "s") "xs")
#guard aliased ["s.rs[0] = mk(s.rs)"] (.field (x "s") "rs")
#guard aliased ["s.rs[0] = s.build()"] (x "s")
#guard aliased ["ref e = xs[0]", "e = xs.pop()"] (x "xs")
#guard aliased ["ref ys = xs", "ys[0] = xs.pop()"] (x "xs")
-- Not when the result is an `Int` of a call, the place is not an element,
-- the call is passed another list or reads it, or is nested.
#guard prints ["rs[0].v = rs[1].bump()", "print(rs[0].v)"] ["3"]
#guard prints ["s.r = s.rs.pop()", "print(s.r.v)"] ["2"]
#guard prints ["rs[0] = rs[1].make()", "print(rs[0].v)"] ["2"]
#guard prints ["rs[0] = s.rs.pop()", "print(rs[0].v)"] ["2"]
#guard prints ["rs[0] = mkRead(rs)", "print(rs[0].v)"] ["2"]
#guard prints ["xs[0] = two(xs.pop(), 1)", "print(xs[0])"] ["3"]
#guard prints ["xs[0] = xs.pop() + 1", "print(xs[0])"] ["3"]

end MojoGrimoireTest.Parse.StaleRefs
