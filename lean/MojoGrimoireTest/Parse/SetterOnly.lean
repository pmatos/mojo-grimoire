import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the assignment of a subscript of a struct that declares
`__setitem__` but not `__getitem__` (#296,
`MojoGrimoire.Check.rejectSetterOnly`). Each verdict is the pinned
compiler's for the program, probed on the nightly 1.3.0.dev2026111905:
"'T' has '__setitem__' but no '__getitem__' method", reported once the
subscript's receiver is typed, before its index, the value assigned and
the errors of a later pass.
-/

namespace MojoGrimoireTest.Parse.SetterOnly

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- A struct `T` with a field `n` and a `__setitem__` but no
`__getitem__`, then `main`, whose body is `body`. -/
private def withSetter (body : List String) : String :=
  "\n".intercalate (["@fieldwise_init", "struct T(Copyable):", "    var n: Int",
    "    def __setitem__(mut self, i: Int, v: Int):", "        self.n = v", "def main():"] ++
    body.map ("    " ++ ·))

private def rejects (body : List String) (e : CheckError) : Bool :=
  match parse (withSetter body) with
  | .ok prog => run prog 100000 == .rejected ⟨"main", e⟩
  | .error _ => false

private def noGetter : CheckError := .missingMethod (.struct "T") "__getitem__"

#guard rejects ["var t = T(1)", "t[0] = 5"] noGetter
#guard rejects ["var t = T(1)", "t[0] += 1"] noGetter
-- Before the index, the value and a later pass's errors.
#guard rejects ["var t = T(1)", "t[nope] = 5"] noGetter
#guard rejects ["var t = T(1)", "t[T(2)] = 5"] noGetter
#guard rejects ["var t = T(1)", "t[0] = nope"] noGetter
#guard rejects ["var t = T(1)", "t[0] = T(2)"] noGetter
#guard rejects ["var t = T(1)", "t[nope] += 1"] noGetter
#guard rejects ["var t = T(1)", "var u = t^", "t[0] = 5"] noGetter
#guard rejects ["var t: T", "t[0] = 5"] noGetter
#guard rejects ["var ts: List[T] = [T(1)]", "ts[[1, 2]][0] = 5"] noGetter
-- Through a reference, and inside a place.
#guard rejects ["var t = T(1)", "ref r = t", "r[0] = 5"] noGetter
#guard rejects ["var ts: List[T] = [T(1)]", "ts[0][0] = 5"] noGetter
-- The receiver's own errors come first.
#guard rejects ["var ts: List[T] = [T(1)]", "ts[nope][0] = 5"] (.unknownVariable "nope")
-- An error of an earlier statement comes first.
#guard rejects ["var t = T(1)", "var b: Int = T(2)", "t[0] = 5"] (.typeMismatch .int (.struct "T"))

end MojoGrimoireTest.Parse.SetterOnly
