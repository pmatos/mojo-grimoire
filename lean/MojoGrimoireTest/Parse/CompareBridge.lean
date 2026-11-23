import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the bridge to `main`'s order within a statement
(`MojoGrimoire.Check.bridged`, #166): a statement that `main` rejected
with the compiler's class, by the error of a comparison with a literal
that part 2 of #166 now converts, keeps that class while the model
orders the statement's other errors otherwise than the compiler (#96,
#170). A comparison's own error, when it is the statement's only error,
stands. Each verdict is the pinned compiler's for the program, probed on
the nightly 1.3.0.dev2026111905, but where a comment says otherwise.
-/

namespace MojoGrimoireTest.Parse.CompareBridge

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations before `main`. -/
private def pre : List String :=
  ["@fieldwise_init", "struct H(Movable):", "    var y: List[Int]", "    var x: Int"]

/-- The declarations at the start of `main`. -/
private def decls : List String :=
  ["var x = 1", "var y: List[Int] = [1]", "var rl: List[List[Int]] = [[1]]",
   "var al: Array[List[Int], 1] = [[1]]", "var h = H([1], 1)", "var a = [1, 2]",
   "var n = [[1], [2]]", "var xs = [1, 2]"]

/-- Parses and runs the program of `pre` and a `main` of `decls` and
`body`; a syntax error gives `none`. -/
private def runMain (body : List String) : Option Outcome :=
  match parse ("\n".intercalate (pre ++ "def main():" :: (decls ++ body).map ("    " ++ ·))) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- Whether `main` is rejected with the error that `cls` matches. -/
private def rejects (body : List String) (cls : CheckError → Bool) : Bool :=
  match runMain body with
  | some (.rejected ⟨"main", e⟩) => cls e
  | _ => false

-- `main` agreed with the compiler, by the error of the comparison that
-- #166 now converts; the model reports the other comparison's error in
-- another order than the compiler (#96), so `main`'s class stays.
#guard rejects ["print([x] != [[1]], [[1], y] >= rl)"] (· matches .typeMismatch ..)
#guard rejects ["print([y^] == rl, [h.y] <= al)"] (· matches .implicitCopy _)
#guard rejects ["print([y^] != rl, [y, [x]] != rl)"] (· matches .implicitCopy _)
#guard rejects ["print(al == [[x]], [y] > al)"] (· matches .implicitCopy _)
-- The second comparison alone is another class on both models than on
-- the compiler, which gives the class `main` gave for the first.
#guard rejects ["print(a == [[1], [2]], [a] == n)"] (· matches .implicitCopy _)
#guard rejects ["print((a == [[1], [2]]) != ([a] == n))"] (· matches .implicitCopy _)
#guard rejects ["print([1, [2]] == xs, False == [])"] (· matches .typeMismatch ..)
#guard rejects ["print([1, 2] == [[1], [2]], [List[Int](), [a[-1]]] != [3, 1])"]
  (· matches .typeMismatch ..)
-- A comparison's own error, the statement's only one, stands.
#guard rejects ["print([1] < [[1, 2]], 1)"] (· matches .noMatchingInit _)
-- With another error, `main`'s is reported, here the compiler's (#170).
#guard rejects ["print([1] < [[1, 2]], x - [True])"] (· matches .typeMismatch ..)
-- `main`'s class stays where `main` was wrong too: the compiler reports
-- the missing method first (`missingMethod`), an order that waits for #96.
#guard rejects ["print([y^] != rl, rl < rl)"] (· matches .implicitCopy _)
-- A statement with no error runs as part 2 of #166 has it.
#guard runMain ["print(al == [[x]], [[x]] != al)"] == some (.finished ["True False"])

end MojoGrimoireTest.Parse.CompareBridge
