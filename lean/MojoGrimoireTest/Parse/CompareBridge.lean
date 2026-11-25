import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of statements that #260's bridge to `main`'s order kept at
`main`'s class, until part 4 of #96 removed it: comparisons with a
literal that part 2 of #166 converts, beside another error of the same
statement. Each verdict is the pinned compiler's for the program, probed on
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

-- Not yet: a literal that holds a place whose value is not implicitly
-- copyable, whose copy the compiler orders against the literal's
-- conversion and misfit (comment 14 on #96, part 9). `main` matched the
-- compiler here only by the first comparison's error, which part 2 of #166
-- corrected. The pin gives `typeMismatch` for the first and
-- `implicitCopy` for the rest, so only the third agrees.
#guard rejects ["print([x] != [[1]], [[1], y] >= rl)"] (· matches .implicitCopy _)
#guard rejects ["print([y^] == rl, [h.y] <= al)"] (· matches .violatedConstraint ..)
#guard rejects ["print([y^] != rl, [y, [x]] != rl)"] (· matches .implicitCopy _)
#guard rejects ["print(al == [[x]], [y] > al)"] (· matches .violatedConstraint ..)
#guard rejects ["print(a == [[1], [2]], [a] == n)"] (· matches .typeMismatch ..)
#guard rejects ["print((a == [[1], [2]]) != ([a] == n))"] (· matches .typeMismatch ..)
#guard rejects ["print([1, [2]] == xs, False == [])"] (· matches .typeMismatch ..)
#guard rejects ["print([1, 2] == [[1], [2]], [List[Int](), [a[-1]]] != [3, 1])"]
  (· matches .typeMismatch ..)
-- So do comparisons inside a compared literal, and inside an operand. The
-- pin gives `implicitCopy` for the first, as above.
#guard rejects ["print([a == [[1], [2]], [a] == n] == [True, True])"] (· matches .typeMismatch ..)
#guard rejects ["print([1, 2] == [[1], [len([xs == [1]])]], [List[Int](), [a[-1]]] != [3, 1])"]
  (· matches .typeMismatch ..)
-- Not yet: an `Int` condition, in an `if`, an `elif` and a loop, which
-- the compiler runs and the model rejects (#195).
#guard rejects ["if len([a == [[1], [2]]]):", "    print(1)"] (· matches .typeMismatch ..)
#guard rejects ["if False:", "    print(0)", "elif len([a == [[1], [2]]]):", "    print(1)"]
  (· matches .typeMismatch ..)
#guard rejects ["while len([a == [[1], [2]]]):", "    return"] (· matches .typeMismatch ..)
-- The type phase reports a type error before the wrong-length literal,
-- which the compiler finds when it instantiates the call (#170); alone,
-- the literal is `noMatchingInit`, as the pin says.
#guard rejects ["print([1] < [[1, 2]], x - [True])"] (· matches .typeMismatch ..)
#guard rejects ["print([1] < [[1, 2]], 1)"] (· matches .noMatchingInit ..)
-- The missing method comes first, as the pin says.
#guard rejects ["print([y^] != rl, rl < rl)"] (· matches .missingMethod ..)
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
and parameters: each is checked on its own. -/
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
