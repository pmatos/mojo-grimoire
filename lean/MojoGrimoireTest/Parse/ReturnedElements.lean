import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of returning a reference into an element under the origin of the
parameter that holds it. The pinned compiler rejects a returned place that
goes through a list element, or through a field of any element, as
`escapingReference`; an element of an array alone may be returned. Each
verdict and output is the pinned compiler's for the program.
-/

namespace MojoGrimoireTest.Parse.ReturnedElements

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- `P` is a struct of one `Int`, and `H` holds a list. -/
private def lib : List String := [
  "@fieldwise_init",
  "struct P(Copyable):",
  "    var a: Int",
  "",
  "@fieldwise_init",
  "struct H(Movable):",
  "    var xs: List[Int]",
  "",
  "def id(ref x: Int) -> ref [x] Int:",
  "    return x",
  ""]

/-- The program that declares `def get(header) -> ref [arg] Int` with the body
`body`, and a `main` that declares `decl` and prints `get(arg)`. -/
private def prog (header : String) (body : List String) (decl arg : String) :
    List String :=
  lib ++ (s!"def get({header}) -> ref [{arg}] Int:" :: body.map ("    " ++ ·)) ++
    ["", "def main():", s!"    var {decl}", s!"    print(get({arg}))"]

private def escapes (header : String) (body : List String) (decl arg : String) : Bool :=
  runLines (prog header body decl arg) ==
    some (.rejected ⟨"get", .escapingReference "get"⟩)

private def prints (header : String) (body : List String) (decl arg : String)
    (out : List String) : Bool :=
  runLines (prog header body decl arg) == some (.finished out)

private def ints : String := "xs: List[Int] = [1, 2]"
private def arr : String := "xs: Array[Int, 2] = [1, 2]"

-- A list element, through a `ref` or a `mut` parameter.
#guard escapes "ref xs: List[Int]" ["return xs[0]"] ints "xs"
#guard escapes "mut xs: List[Int]" ["return xs[0]"] ints "xs"
-- ... through a `ref` binding, to the element or to the list.
#guard escapes "ref xs: List[Int]" ["ref r = xs[0]", "return r"] ints "xs"
#guard escapes "ref xs: List[Int]" ["ref ys = xs", "return ys[0]"] ints "xs"
-- ... as the origin of a call that returns a reference.
#guard escapes "ref xs: List[Int]" ["return id(xs[0])"] ints "xs"
-- ... of a list held in a field, or in an array.
#guard escapes "ref h: H" ["return h.xs[0]"] "h = H([1, 2])" "h"
#guard escapes "ref xs: Array[List[Int], 2]" ["return xs[0][0]"]
  "xs: Array[List[Int], 2] = [[1], [2]]" "xs"
-- A field of an element, of a list or of an array.
#guard escapes "ref xs: List[P]" ["return xs[0].a"] "xs: List[P] = [P(1)]" "xs"
#guard escapes "ref xs: Array[P, 1]" ["return xs[0].a"] "xs: Array[P, 1] = [P(1)]" "xs"

-- An element of an array may be returned, directly, through a `ref`
-- binding or a call, and in an array of arrays.
#guard prints "ref xs: Array[Int, 2]" ["return xs[0]"] arr "xs" ["1"]
#guard prints "ref xs: Array[Int, 2]" ["ref r = xs[1]", "return r"] arr "xs" ["2"]
#guard prints "ref xs: Array[Int, 2]" ["return id(xs[1])"] arr "xs" ["2"]
#guard prints "ref xs: Array[Array[Int, 2], 2]" ["return xs[1][0]"]
  "xs: Array[Array[Int, 2], 2] = [[1, 2], [3, 4]]" "xs" ["3"]

end MojoGrimoireTest.Parse.ReturnedElements
