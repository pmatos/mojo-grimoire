import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the bridge to `main`'s order within a statement
(`MojoGrimoire.Check.bridgedToTwin`, #166): a statement that `main` rejected
with the compiler's class, by the error of a comparison with a literal
that part 2 of #166 now converts, keeps that class while the model
orders the statement's other errors otherwise than the compiler (#96,
#170). When `main`'s check of the statement passes, the statement's own
error stands. Each verdict is the pinned compiler's for the program, probed on
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
-- So do comparisons inside a compared literal, and inside an operand.
#guard rejects ["print([a == [[1], [2]], [a] == n] == [True, True])"] (· matches .implicitCopy _)
#guard rejects ["print([1, 2] == [[1], [len([xs == [1]])]], [List[Int](), [a[-1]]] != [3, 1])"]
  (· matches .typeMismatch ..)
-- A condition is bridged with the test that it is a `Bool`, in an `if`,
-- an `elif` and a loop. The compiler runs these; `main` gave
-- `implicitCopy`, which the bridge keeps until #96 part 4.
#guard rejects ["if len([a == [[1], [2]]]):", "    print(1)"] (· matches .implicitCopy _)
#guard rejects ["if False:", "    print(0)", "elif len([a == [[1], [2]]]):", "    print(1)"]
  (· matches .implicitCopy _)
#guard rejects ["while len([a == [[1], [2]]]):", "    return"] (· matches .implicitCopy _)
-- With another error, `main`'s is reported, here the compiler's (#170).
#guard rejects ["print([1] < [[1, 2]], x - [True])"] (· matches .typeMismatch ..)
-- `main`'s class stays where `main` was wrong too: the compiler reports
-- the missing method first (`missingMethod`), an order that waits for #96.
#guard rejects ["print([y^] != rl, rl < rl)"] (· matches .implicitCopy _)
-- A statement with no error runs as part 2 of #166 has it.
#guard runMain ["print(al == [[x]], [[x]] != al)"] == some (.finished ["True False"])

/-- Whether the program `src` is rejected in `where_` with the error that
`cls` matches. -/
private def rejectsIn (src : String) (where_ : String) (cls : CheckError → Bool) : Bool :=
  match parse src with
  | .ok prog =>
    match run prog 100000 with
    | .rejected ⟨w, e⟩ => w == where_ && cls e
    | _ => false
  | .error _ => false

/-- A method `S.m` and a free function `m(self: S)`, with the same name
and parameters: each is checked beside its own twin. -/
private def shadow : String :=
  "\n".intercalate ["@fieldwise_init", "struct S(Movable):", "    var a: Array[Int, 2]",
    "    def m(self):", "        var z = 5", "        print([[1]] == [1], z)",
    "def m(self: S):", "    var w = 5", "    var z = w", "    print(z)",
    "def main():", "    var s = S([1, 2])", "    s.m()", "    m(s)"]

-- The method's error is `main`'s, and the compiler's, `typeMismatch`, not
-- one from the free function's body.
#guard rejectsIn shadow "S.m" (· matches .typeMismatch ..)

/-- A struct test beside a comparison that part 2 converts, in one test:
`main` rejected the comparison (`implicitCopy`); the compiler runs it
(`arrays/compare_literal_beside_struct_test`). -/
private def structTest : String :=
  "\n".intercalate ["struct T(ImplicitlyCopyable):", "    var n: Int",
    "    def __init__(out self, n: Int):", "        self.n = n",
    "    def __bool__(self) -> Bool:", "        print(\"bool\", self.n)", "        return self.n != 0",
    "def main():", "    var pi = T(1)", "    var a = [1, 2]", "    var zz = True",
    "    var r = pi and (a == [[1], [2]]) and zz", "    print(r)",
    "    var s = (a < [1, [3]]) or T(0)", "    print(s)",
    "    if not T(0) and a != [[2], [2]]:", "        print(\"yes\")"]

#guard (match parse structTest with
  | .ok prog => run prog 100000 == .finished ["bool 1", "True", "True", "bool 0", "yes"]
  | .error _ => false)

end MojoGrimoireTest.Parse.CompareBridge
