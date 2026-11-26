import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of printing a list or an array: `print` reads it by reference, with
no copy, and writes it as `[e₁, e₂]`, nested lists included, when it can
write its elements (#41).
-/

namespace MojoGrimoireTest.Parse.PrintLists

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The class of error that rejects the program `ls`, in `main`. -/
private def rejects (ls : List String) (e : CheckError) : Bool :=
  runLines ls == some (.rejected ⟨"main", e⟩)

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

/-- `@fieldwise_init struct Token(Movable): var id: Int`, then `main`. -/
private def withToken (body : List String) : List String :=
  ["@fieldwise_init", "struct Token(Movable):", "    var id: Int", ""] ++ inMain body

-- How `print` writes a value.
#guard Value.show (.list [.int 1, .int (-2)]) == "[1, -2]"
#guard Value.show (.list [.list [.bool true], .list []]) == "[[True], []]"
#guard Value.show (.list []) == "[]"

-- Lists and arrays of `Int` and `Bool`, nested, and empty.
#guard runLines (inMain [
  "var xs: List[Int] = [1, 2]",
  "var nested: List[List[Int]] = [[1, 2], [3]]",
  "var e: List[Bool] = []",
  "var a = [3, 4]",
  "print(xs, nested, e, a, [True, False], [[1], [2]])"]) ==
  some (.finished ["[1, 2] [[1, 2], [3]] [] [3, 4] [True, False] [[1], [2]]"])

-- A list is read once every value is evaluated, by reference.
#guard runLines (inMain ["var xs: List[Int] = [1, 2]", "print(xs, xs.pop())", "print(xs)"]) ==
  some (.finished ["[1] 2", "[1]"])

-- Through a `read` or `mut` parameter, a `ref` binding, a field and a
-- returned reference.
#guard runLines [
  "@fieldwise_init",
  "struct Bag(Movable):",
  "    var items: List[Int]",
  "",
  "def show(xs: List[Int]):",
  "    print(xs)",
  "",
  "def grow(mut xs: List[Int]):",
  "    print(xs)",
  "    xs.append(9)",
  "",
  "def pick(ref a: List[Int], ref b: List[Int], first: Bool) -> ref[a, b] List[Int]:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def main():",
  "    var xs: List[Int] = [7]",
  "    show(xs)",
  "    grow(xs)",
  "    ref r = xs",
  "    print(r)",
  "    var bag = Bag([4, 5])",
  "    print(bag.items, pick(xs, bag.items, False))"] ==
  some (.finished ["[7]", "[7]", "[7, 9]", "[4, 5] [4, 5]"])

-- A value whose elements `print` cannot write, a struct included.
#guard rejects (withToken ["var ts = [Token(1), Token(2)]", "print(ts)"])
  (.notPrintable (.array (.struct "Token") 2))
#guard rejects (withToken ["var ts: List[Token] = []", "print(ts)"])
  (.notPrintable (.list (.struct "Token")))
#guard rejects (withToken ["var t = Token(1)", "print(t)"]) (.notPrintable (.struct "Token"))

-- The own expressions of `print`'s arguments come before an argument that
-- it cannot write, but a literal argument is not built before it, as the
-- pin orders them (#96 part 4c).
#guard rejects (withToken ["var t = Token(1)", "var u = Token(2)", "print(t, [u])"])
  (.notPrintable (.struct "Token"))
#guard rejects (withToken ["var t = Token(1)", "print(t, [1, True])"]) (.notPrintable (.struct "Token"))
#guard rejects (withToken ["var t = Token(1)", "print(t, [])"]) (.notPrintable (.struct "Token"))
#guard rejects (withToken ["var t = Token(1)", "print(t, [nope])"]) (.unknownVariable "nope")
-- A moved list cannot be printed.
#guard rejects (inMain ["var xs: List[Int] = [1]", "var ys = xs^", "print(xs)"])
  (.uninitializedUse (.var "xs"))

end MojoGrimoireTest.Parse.PrintLists
