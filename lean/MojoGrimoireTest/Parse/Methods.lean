import MojoGrimoire.Parse.Subset
import MojoGrimoire.Interp.Run

/-!
Tests of the two errors found from the types of a call's or an
operator's operands (`MojoGrimoire.Check.Methods`): a method or an
operator with several overloads, none of which fits, `noMatchingMethod`
(#88, #169), and a method that a type lacks, `missingMethod`, of an
operator's operand or of a variable that is called (#176). Each verdict
is the pinned compiler's for the program, probed on the nightly
1.3.0.dev2026111905.
-/

namespace MojoGrimoireTest.Parse.Methods

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`, as the driver does; a
syntax error, or a construct outside the subset, gives `none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parseSubset ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The construct outside the subset of the program whose lines are `ls`,
which the driver reports with exit 3. -/
private def outsideOf (ls : List String) : Option Outside :=
  match parseSubset ("\n".intercalate ls) with
  | .error (.outside o) => some o
  | _ => none

/-- A struct `S` that has no methods, then `main`, whose body is `body`. -/
private def withS (body : List String) : List String :=
  ["@fieldwise_init", "struct S(Movable):", "    var n: Int", "def main():"] ++
    body.map ("    " ++ ·)

/-- Whether the line `i` of `main`'s body `body`, from 1, is outside the
subset as the construct `m`. -/
private def outside (body : List String) (i : Nat) (m : String) : Bool :=
  outsideOf (withS body) == some ⟨4 + i, m⟩

private def prints (body : List String) (out : List String) : Bool :=
  runLines (withS body) == some (.finished out)

/-- The class of error that rejects `main`, whose body is `body`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runLines (withS body) == some (.rejected ⟨"main", e⟩)

-- An integer literal's operator: a right operand that is no `Int` fits no
-- overload, a struct one too, which is not read.
#guard rejects ["print(1 + True)"] (.noMatchingMethod "__add__")
#guard rejects ["var b = True", "print(-1 < b)"] (.noMatchingMethod "__lt__")
#guard rejects ["var s = S(1)", "print((2 * 3) % s)"] (.noMatchingMethod "__mod__")
#guard rejects ["print(1 + [2, True])"] (.noMatchingMethod "__add__")
-- An `Int` that is not a literal has one overload: a type mismatch.
#guard rejects ["var x = 1", "print(x + True)"] (.typeMismatch .int .bool)
-- A literal of `Int`s of the wrong length still fails its SIMD constraint.
#guard rejects ["print(1 + [2, 3])"] (.noMatchingInit .int)

-- An index of a list or an array, and `pop`: any misfit.
#guard rejects ["var xs: List[Int] = [1]", "var s = S(0)", "print(xs[s].n)"]
  (.noMatchingMethod "__getitem__")
#guard rejects ["var a = [1, 2]", "a[False] = 3", "print(a[0])"] (.noMatchingMethod "__getitem__")
-- A string literal as the index is outside the subset (#180).
#guard outside ["var xs: List[Int] = [1]", "print(xs[\"a\"])"] 2 outsideString
#guard rejects ["var xs: List[Int] = [1]", "print(xs[[0, 1]])"] (.noMatchingInit .int)
#guard rejects ["var xs: List[Int] = [1]", "print(xs.pop(0, True))"] (.noMatchingMethod "pop")
#guard rejects ["var xs: List[Int] = [1]", "print(xs.pop([0, 1]))"] (.noMatchingInit .int)
-- A list that may not change fits no overload of `pop` either.
#guard runLines ["def f(xs: List[Int]):", "    print(xs.pop(0))", "def main():",
  "    var xs: List[Int] = [1]", "    f(xs)"] == some (.rejected ⟨"f", .noMatchingMethod "pop"⟩)
-- An error inside an argument of `pop` comes before its receiver's misfit.
#guard runLines ["def f(xs: List[Int]):", "    print(xs.pop(nope))", "def main():",
  "    var xs: List[Int] = [1]", "    f(xs)"] == some (.rejected ⟨"f", .unknownVariable "nope"⟩)
#guard rejects ["var xs: List[Int] = [1]", "print(xs^.pop(True + 1))"]
  (.missingMethod .bool "__add__")
-- `append` has one overload: its misfit is named.
#guard rejects ["var xs: List[Int] = [1]", "xs.append(True)", "print(len(xs))"]
  (.typeMismatch .int .bool)

-- An operator's method that its operand's type lacks, found before the
-- operand is read, also when it is uninitialized.
#guard rejects ["var b = True", "print(b * 2)"] (.missingMethod .bool "__mul__")
#guard rejects ["var s = S(1)", "print(s + 1)"] (.missingMethod (.struct "S") "__add__")
#guard rejects ["var s: S", "print(s + 1)"] (.missingMethod (.struct "S") "__add__")
#guard rejects ["var s = S(1)", "print(True and s)"] (.missingMethod (.struct "S") "__bool__")
#guard rejects ["var xs: List[Int] = [1]", "print(xs // xs)"]
  (.missingMethod (.list .int) "__floordiv__")
#guard rejects ["var b = True", "print([2] + b)"] (.missingMethod (.array .int 1) "__add__")
#guard rejects ["var a = [1]", "print(not a)"] (.missingMethod (.array .int 1) "__bool__")
#guard rejects ["var s = S(1)", "s -= 1", "print(s.n)"] (.missingMethod (.struct "S") "__isub__")
-- An error inside an operand comes first, a literal whose elements differ
-- too.
#guard rejects ["print(-[1, True])"] (.typeMismatch .int .bool)
#guard rejects ["var b = True", "print(b or [1, True])"] (.typeMismatch .int .bool)
-- A literal of `Int`s, one a call of `len`, is an array before it is read.
#guard rejects ["var xs: List[Int]", "print(-[1, len(xs)])"] (.missingMethod (.array .int 2) "__neg__")
-- A call of a variable gives no type: the literal is left to checking.
#guard runLines ["@fieldwise_init", "struct C(Copyable):", "    var a: Int",
  "    def __call__(self, x: List[Int]) -> Int:", "        return 1", "def main():",
  "    var len = C(1)", "    var xs: List[Int] = [1]", "    print(-[True, len(xs)])"] ==
  some (.rejected ⟨"main", .typeMismatch .bool .int⟩)
#guard rejects ["var s = S(1)", "print(s + nope)"] (.unknownVariable "nope")
#guard rejects ["print(True + (1 + True))"] (.noMatchingMethod "__add__")

-- A variable or a parameter hides a function, `len`, `range` or a struct
-- of its name within its scope: it has no `__call__`. Its arguments are
-- typed first.
#guard rejects ["var len = 5", "var ys: List[Int] = [1]", "print(len(ys))"]
  (.missingMethod .int "__call__")
#guard rejects ["var S = True", "var s = S(1)", "print(s.n)"] (.missingMethod .bool "__call__")
#guard rejects ["var range = 5", "print(range(3))"] (.missingMethod .int "__call__")
#guard rejects ["var len = 5", "print(len(nope))"] (.unknownVariable "nope")
#guard rejects ["var print = 3", "print(5)"] (.missingMethod .int "__call__")
-- A hidden call passed `mut` is still checked as a call.
#guard runLines ["def g(mut k: Int):", "    k = 1", "def f() -> Int:", "    return 1",
  "def main():", "    var f = 1", "    g(f())"] ==
  some (.rejected ⟨"main", .missingMethod .int "__call__"⟩)
-- The hidden function's signature types no argument: `[True]` stays an array.
#guard runLines ["def f(xs: List[Int]) -> Int:", "    return len(xs)", "def main():",
  "    var f = 1", "    print(f([True]))"] ==
  some (.rejected ⟨"main", .missingMethod .int "__call__"⟩)
-- A function of the program named `range` is typed as any other: the error
-- inside the operand comes first.
#guard runLines ["def range(n: List[Int]) -> Int:", "    return 1", "def main():",
  "    var b = True", "    print(b + range(1))"] ==
  some (.rejected ⟨"main", .typeMismatch (.list .int) .int⟩)
#guard runLines ["def f(k: Int) -> Int:", "    return k", "def g(f: Int) -> Int:",
  "    return f(f)", "def main():", "    print(g(1))"] ==
  some (.rejected ⟨"g", .missingMethod .int "__call__"⟩)
-- Outside its scope, and before it is declared, the name is the function.
#guard prints ["var ys: List[Int] = [1, 2]", "print(len(ys))", "if True:", "    var len = 5",
  "    print(len)", "print(len(ys))"] ["2", "5", "2"]

end MojoGrimoireTest.Parse.Methods
