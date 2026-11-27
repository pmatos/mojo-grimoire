import MojoGrimoire.Parse.Subset
import MojoGrimoire.Interp.Run

/-!
Tests of the order in which the errors among the arguments of
`List[T](range(…))` are reported (#121): the compiler's order of passes,
each case checked on the nightly 1.3.0.dev2026111905, and the limits of the
model, which the compiler's tiered order leaves to #339. The forms and the
values of the range are tested in `MojoGrimoireTest.Parse.ListRange`.
-/

namespace MojoGrimoireTest.Parse.ListRangeOrder

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- A function that prints its argument, one that changes its argument,
one that takes a `P`, and a struct. -/
private def lib : List String := [
  "def f(x: Int) -> Int:", "    print(\"f\", x)", "    return x",
  "def bump(mut x: Int) -> Int:", "    x += 10", "    return 3",
  "def h(var q: P) -> Int:", "    return q.x",
  "@fieldwise_init", "struct P(Copyable):", "    var x: Int",
  ""]

/-- The outcome of the program of `lib` and the functions `funs` whose
`main` runs `body`, as the driver reads it; a syntax error, or a construct
outside the subset, gives `none`. -/
private def runLines' (funs body : List String) : Option Outcome :=
  match parseSubset ("\n".intercalate (lib ++ funs ++ "def main():" :: body.map ("    " ++ ·))) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The outcome of the program of `lib` whose `main` runs `body`. -/
private def runMain (body : List String) : Option Outcome := runLines' [] body

/-- The construct outside the subset of the program whose lines are `ls`. -/
private def outsideOf (ls : List String) : Option Outside :=
  match parseSubset ("\n".intercalate ls) with
  | .error (.outside o) => some o
  | _ => none

/-- Whether `main`, running `body`, prints the lines `out`. -/
private def prints (body : List String) (out : List String) : Bool :=
  runMain body == some (.finished out)

/-- Whether `main`, running `body`, is rejected with the error `e`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runMain body == some (.rejected ⟨"main", e⟩)

/-- The declarations of `p`, a `P`; `b`, a `Bool`; `u`, an uninitialized
`Int`; and `xs`, a list, before the line that `rejectsWith` runs. -/
private def context : List String :=
  ["var p = P(1)", "var b = True", "var u: Int", "var xs: List[Int] = [1]"]

/-- Whether `main` is rejected with `e` when it runs `context`, then `line`. -/
private def rejectsWith (line : String) (e : CheckError) : Bool :=
  rejects (context ++ [line]) e

/-- Whether the line `line` of `rejectsWith` is outside the subset as the
construct `m`. -/
private def outsideWith (line : String) (m : String) : Bool :=
  outsideOf (lib ++ "def main():" :: (context ++ [line]).map ("    " ++ ·)) ==
    some ⟨lib.length + context.length + 2, m⟩

/-- `List[Int](range(args))` in `main` (`rejectsWith`). -/
private def rangeOf (args : String) : String := s!"print(List[Int](range({args})))"

-- The compiler's order of passes, each case checked on the nightly
-- 1.3.0.dev2026111905. First, typing errors in any argument, also after a
-- misfit of `range`.
#guard rejectsWith (rangeOf "nope") (.unknownVariable "nope")
#guard rejectsWith (rangeOf "b, nope") (.unknownVariable "nope")
#guard rejectsWith (rangeOf "[], nope") (.unknownVariable "nope")
#guard rejectsWith (rangeOf "1, 2, 3, nope") (.unknownVariable "nope")
#guard rejectsWith (rangeOf "[True, nope]") (.unknownVariable "nope")
#guard rejectsWith (rangeOf "xs, p.y") (.unknownAttribute "P" "y")
#guard rejectsWith (rangeOf "[f(True)]") (.typeMismatch .int .bool)
#guard rejectsWith (rangeOf "P(1, 2), nope") (.noMatchingInit (.struct "P"))
#guard rejectsWith (rangeOf "len(List[Int](b)), nope") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[u, nope]") (.unknownVariable "nope")
-- Then the misfits of `range`: an argument of another type, a literal of
-- other elements, a wrong number of arguments, or another element type. A misfit comes before a use
-- of an uninitialized value and a constant index out of range.
#guard rejectsWith (rangeOf "[True, 1]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, True]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[1], [True]]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "u, b") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "u, [True]") (.noMatchingInit (.list .int))
#guard rejectsWith "print(List[Bool](range(u)))" (.noMatchingInit (.list .bool))
-- A place is typed before it is read, and an open literal's elements too.
#guard rejectsWith "var c: Bool\n    print(List[Int](range(c)))" (.noMatchingInit (.list .int))
#guard rejectsWith "var q: P\n    print(List[Int](range(1, q)))" (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[True, u]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[True, xs[-1]]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[True], u]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, [True]], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, [[True]]], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[], [1]], u") (.noMatchingInit (.list .int))
-- A place that is not an `Int`, in a literal or in a range, is a misfit, not
-- an implicit copy.
#guard rejectsWith (rangeOf "[p]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, p], u") (.noMatchingInit (.list .int))
-- Then a use of an uninitialized value, before a literal of `Int`s of the
-- wrong length, or an empty one, and before a constant index out of range.
#guard rejectsWith (rangeOf "[1, 2], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "u, []") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "u, [1, [2]]") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "u, [[1, 2]]") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "xs[-1], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "[1, []], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "[1, [[]]], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "[u, 2]") (.uninitializedUse (.var "u"))
-- A place read late, invalidated by a later argument, comes before the
-- literal and the index.
#guard rejectsWith (rangeOf "xs[0], xs.pop(), [1, 2]")
  (.invalidatedReference (.index (.var "xs") (.int 0)))
#guard rejectsWith (rangeOf "xs[0], xs.pop(), xs[-1]")
  (.invalidatedReference (.index (.var "xs") (.int 0)))
-- Then the literal, before a constant index out of range.
#guard rejectsWith (rangeOf "[1, 2]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, [2]]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "xs[-1], [1, 2]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "xs[-1], []") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[xs[-1], 2]") (.noMatchingInit (.list .int))
-- Since the merge of #171, which types these literals `Int`, checked on the
-- nightly: an uninitialized element is read, a `Bool` element is a misfit,
-- and an empty literal is `noMatchingInit`, as `[1, 2]` is above.
#guard rejectsWith "var z: Int\n    print(List[Int](range([z, 2])))" (.uninitializedUse (.var "z"))
#guard rejectsWith (rangeOf "[1, True]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[]") (.noMatchingInit (.list .int))
-- A literal's elements are read late, as an operation's operands: a later
-- argument that changes the list invalidates an element read before it.
#guard rejectsWith (rangeOf "[xs[0], 1], xs.pop()")
  (.invalidatedReference (.index (.var "xs") (.int 0)))
#guard rejectsWith (rangeOf "[u, xs[-1]]") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "[xs[-1], 1], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "[h(p^), p.x]") (.uninitializedUse (.field (.var "p") "x"))
#guard rejectsWith (rangeOf "[[1, 2], 3]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[], 3]") (.noMatchingInit (.list .int))
-- An index is checked once: `h(p^)` in it moves `p` once.
#guard prints ["var p = P(1)", "var xs: List[Int] = [1, 2]", "print(List[Int](range(xs[h(p^)])))"]
  ["[0, 1]"]
#guard prints ["var p = P(1)", "var xs: List[Int] = [1, 2]",
  "print(List[Int](range(0, xs[h(p^)])))"] ["[0, 1]"]
#guard rejectsWith (rangeOf "[xs[h(p^)], 1]") (.noMatchingInit (.list .int))
-- An argument that is no `Int` is a misfit, though it reads an
-- uninitialized value or has a constant index out of range.
#guard rejectsWith (rangeOf "P(u)") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[P(u)]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "P(xs[-1])") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "b == (u == 1)") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[P(u), 1]") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[1, b == (u == 1)], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "P(u), nope") (.unknownVariable "nope")
-- A non-`Int` argument that is uninitialized, or moved, is a misfit.
#guard rejectsWith "var q: P\n    print(List[Int](range(q^)))" (.noMatchingInit (.list .int))
#guard rejectsWith "var q: P\n    print(List[Int](range(q.copy())))" (.noMatchingInit (.list .int))
-- A literal whose first element, at any depth, is an empty literal fits no
-- form of `range` as the first argument; after it, it is a literal of `Int`s
-- that fails only when the call is instantiated.
#guard rejectsWith (rangeOf "[], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[]], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "[[], 1], [], u") (.noMatchingInit (.list .int))
#guard rejectsWith (rangeOf "1, [], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "u, [[], 1]") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "1, [[], 1], u") (.uninitializedUse (.var "u"))
-- Each element of a literal is read on its own: an index out of range in
-- one does not hide that a later argument invalidates the one before it.
#guard rejectsWith (rangeOf "[xs[0], xs[-1]], xs.pop()")
  (.invalidatedReference (.index (.var "xs") (.int 0)))
-- Inside an operation, the use of `u` uninitialized comes before the
-- index, which instantiation reports (#96 part 7).
#guard rejectsWith (rangeOf "xs[-1] + u") (.uninitializedUse (.var "u"))

-- A literal of `Int`s of the wrong length nested in an argument fails only
-- when the call is instantiated, after a use of an uninitialized value.
#guard rejectsWith (rangeOf "[1, 2] + 2, u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "xs[[1, 2]], u") (.uninitializedUse (.var "u"))
#guard rejectsWith (rangeOf "xs[[1, 2]], nope") (.unknownVariable "nope")

-- A call that returns a reference to a value that is no `Int` is a misfit,
-- before the value would be copied.
#guard runLines' ["def getp(ref q: P) -> ref [q] P:", "    return q"]
  ["var p = P(1)", "var u: Int", "print(List[Int](range(u, getp(p))))"] ==
  some (.rejected ⟨"main", .noMatchingInit (.list .int)⟩)

-- An implicit copy inside an argument is a typing error, before any misfit.
#guard rejectsWith (rangeOf "h(p) + 0, b") (.implicitCopy (.struct "P"))
#guard rejectsWith (rangeOf "1, [h(p) + 0, 1], u") (.implicitCopy (.struct "P"))

-- The order of a literal and a constant index into an array, which the
-- compiler's levels disagree on and #331 rules undefined: the model reports
-- the literal first, `-O0`'s order, and this pins it. At `-O3` the index
-- comes first. An array index beside an index into a list is left to #339.
#guard rejectsWith "var a: Array[Int, 2] = [1, 2]\n    print(List[Int](range([1, 2], a[2])))"
  (.noMatchingInit (.list .int))
-- A nested `List[Int](range(…))` of a literal of `Int`s fails only when
-- the call is instantiated, after the use of `u` (#96 part 7).
#guard rejectsWith (rangeOf "len(List[Int](range([1, 2]))), u") (.uninitializedUse (.var "u"))
-- An argument that holds a string literal or a call of `range`, at any
-- depth, is outside the subset (#180), whatever error the compiler reports
-- first: a string outside `print`, and `range` outside `List[T](…)` by the
-- ruling of 2026-11-19. Among them, an operator over an `Int` and a string
-- or a range, for which the compiler reports the operator's own type
-- mismatch.
#guard outsideWith (rangeOf "\"a\", nope") outsideString
#guard outsideWith (rangeOf "range(3), nope") outsideRange
#guard outsideWith (rangeOf "[1, 2, \"a\"], nope") outsideString
#guard outsideWith (rangeOf "[nope, \"a\"]") outsideString
#guard outsideWith (rangeOf "[\"a\", nope]") outsideString
#guard outsideWith (rangeOf "[u, nope, \"a\"]") outsideString
#guard outsideWith (rangeOf "\"a\" + nope") outsideString
#guard outsideWith (rangeOf "range(nope)") outsideRange
#guard outsideWith (rangeOf "[p.y, \"a\"]") outsideString
#guard outsideWith (rangeOf "\"a\", f(p)") outsideString
#guard outsideWith (rangeOf "\"a\"") outsideString
#guard outsideWith (rangeOf "[[\"a\"]]") outsideString
#guard outsideWith (rangeOf "[[range(3)]]") outsideRange
#guard outsideWith (rangeOf "\"a\" + \"b\"") outsideString
#guard outsideWith (rangeOf "\"a\" == \"b\"") outsideString
#guard outsideWith (rangeOf "not \"a\"") outsideString
#guard outsideWith (rangeOf "1, [range(3)]") outsideRange
#guard outsideWith (rangeOf "u, \"a\"") outsideString
#guard outsideWith (rangeOf "xs[-1], \"a\"") outsideString
#guard outsideWith (rangeOf "[xs, \"a\"]") outsideString
#guard outsideWith (rangeOf "range(xs)") outsideRange
#guard outsideWith (rangeOf "[\"a\", []]") outsideString
#guard outsideWith (rangeOf "[range(3), [True, 1]]") outsideRange
#guard outsideWith (rangeOf "p.x + range(2)") outsideRange
#guard outsideWith (rangeOf "u + \"a\"") outsideString

end MojoGrimoireTest.Parse.ListRangeOrder
