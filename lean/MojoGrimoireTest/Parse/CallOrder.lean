import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the order of a call's errors (#89, #96 part 9): each argument's own
expression first, then the number of arguments, then each argument's type
and mutability, left to right, then the implicit copies, and last the
exclusivity of the arguments passed by reference. Each program is one of
`tests/conformance/order/call_*`, whose result the compiler gave.
-/

namespace MojoGrimoireTest.Parse.CallOrder

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- A struct that is copyable but not implicitly, with a method that takes
a `Bool` and an `Int`, and functions that take the struct `var` or `mut`. -/
private def lib : List String := [
  "@fieldwise_init", "struct S(Copyable):", "    var k: Int",
  "    def m(self, a: Bool, b: Int) -> Int:", "        return b",
  "    def mm(mut self, a: Int) -> Int:", "        return a",
  "def f(a: Bool, b: Int) -> Int:", "    return b",
  "def fv(var s: S, a: Bool) -> Int:", "    return 1",
  "def gm(mut a: S, b: Int) -> Int:", "    return 1",
  "def g(mut a: List[Int], b: List[Int]) -> Int:", "    return 1",
  "def gx(mut a: S, mut b: S, c: Bool) -> Int:", "    return 1",
  "def h(s: S, xs: List[Int]):", "    var u = s.copy()"]

/-- Whether `body`, the rest of `h`, whose parameters may not change, is
rejected in `h` with an error that `p` accepts. -/
private def rejects (body : List String) (p : CheckError → Bool) : Bool :=
  match runLines (lib ++ body.map ("    " ++ ·) ++
      ["def main():", "    var xs: List[Int] = [1]", "    h(S(1), xs)"]) with
  | some (.rejected ⟨"h", e⟩) => p e
  | _ => false

-- An argument's own expression comes before every misfit of the call.
#guard rejects ["print(f(1, nope))"] (· matches .unknownVariable _)
#guard rejects ["print(f(True, 2, nope))"] (· matches .unknownVariable _)
#guard rejects ["print(s.m(1, nope))"] (· matches .unknownVariable _)
#guard rejects ["print(f(s, 1 + True))"] (· matches .noMatchingMethod _)
#guard rejects ["xs.append(nope)"] (· matches .unknownVariable _)
#guard rejects ["print(fv(u, nope))"] (· matches .unknownVariable _)
-- The number of arguments comes before their types and the receiver.
#guard rejects ["print(f(1))"] (· matches .arityMismatch ..)
#guard rejects ["print(s.mm(1, 2))"] (· matches .arityMismatch ..)
#guard rejects ["xs.append(1, 2)"] (· matches .arityMismatch ..)
-- Types and mutability, left to right, the receiver first.
#guard rejects ["print(gm(s, True))"] (· matches .immutablePlace _)
#guard rejects ["print(s.mm(True))"] (· matches .immutablePlace _)
#guard rejects ["xs.append(True)"] (· matches .immutablePlace _)
-- The implicit copies after every misfit, and exclusivity last.
#guard rejects ["print(fv(u, 1))"] (· matches .typeMismatch ..)
#guard rejects ["print(gx(u, u, 1))"] (· matches .typeMismatch ..)
#guard rejects ["var v = u.copy()", "print(gx(v, v, True))"] (· matches .argumentExclusivity _)

end MojoGrimoireTest.Parse.CallOrder
