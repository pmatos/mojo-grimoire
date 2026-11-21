import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of an index into an `Int` (#127). Mojo's `Int` is `SIMD[DType.int, 1]`,
whose `__getitem__` and `__setitem__` read and write its one element, at
index 0, which is the `Int` itself. The pinned nightly ignores any other
index, a compiler bug (D-0009): the model checks an `Int`'s index as an
array's of length 1. The element has no memory origin, so no reference may
point into it, and passed to a `ref` parameter it cannot be changed.
-/

namespace MojoGrimoireTest.Parse.IntIndex

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- Functions that take an `Int` by each convention, one that returns a
reference to its `ref` parameter, and a struct with an `Int` field. -/
private def lib : List String := [
  "def three() -> Int:", "    return 3",
  "def inc(mut x: Int):", "    x += 1",
  "def rd(x: Int) -> Int:", "    return x[0]",
  "def same(ref a: Int) -> ref [a] Int:", "    return a",
  "def one(mut a: Int, b: Int):", "    a += 1", "    print(b)",
  "def pr(n: Int) -> Int:", "    print(\"eval\", n)", "    return n",
  "@fieldwise_init", "struct S(Copyable, Movable):", "    var k: Int",
  ""]

/-- The program of `lib` whose `main` declares `k = 7`, then runs `body`. -/
private def inMain (body : List String) : List String :=
  lib ++ "def main():" :: ("var k = 7" :: body).map ("    " ++ ·)

/-- Whether `main`, running `body`, prints the lines `out`. -/
private def prints (body : List String) (out : List String) : Bool :=
  runLines (inMain body) == some (.finished out)

/-- Whether `main`, running `body`, is rejected with the error `e`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runLines (inMain body) == some (.rejected ⟨"main", e⟩)

/-- Whether `main`, running `body`, prints the lines `out` and then fails
with an index out of bounds. -/
private def failsAfter (body : List String) (out : List String) : Bool :=
  runLines (inMain body) == some (.failed .indexOutOfBounds out)

/-- The place `k[i]`. -/
private def kAt (i : Int) : Place := .index (.var "k") (.int i)

-- Index 0 reads and writes the `Int`, also through a field, an element of
-- a list, a parameter, a `ref` binding and another index.
#guard prints ["print(k[0])"] ["7"]
#guard prints ["k[0] = 5", "print(k)"] ["5"]
#guard prints ["k[0] += 1", "print(k, k[0][0])"] ["8 8"]
#guard prints ["var s = S(7)", "s.k[0] = 9", "print(s.k[0])"] ["9"]
#guard prints ["var xs: List[Int] = [3, 4]", "xs[1][0] = 9", "print(xs)"] ["[3, 9]"]
#guard prints ["print(rd(4))"] ["4"]
#guard prints ["ref r = k", "r[0] = 3", "print(k)"] ["3"]
#guard prints ["var i = 0", "k[i] = 2", "print(k[i], k[1 - 1])"] ["2 2"]
#guard prints ["var j = k[0]^", "print(j)"] ["7"]
-- `k[i] = v` evaluates `i` before `v`, as `__setitem__` takes them, also
-- below an element of a list.
#guard prints ["k[pr(0)] = pr(5)", "print(k)"] ["eval 0", "eval 5", "5"]
#guard prints ["var xs: List[Int] = [1]", "xs[pr(0)][pr(0)] = pr(6)", "print(xs)"]
  ["eval 0", "eval 0", "eval 6", "[6]"]
-- Passed `mut`, it is changed; passed `read`, it is copied.
#guard prints ["inc(k[0])", "print(k)"] ["8"]
#guard prints ["one(k[0], k)", "print(k)"] ["7", "8"]
-- Passed `ref`, it gives an immutable reference.
#guard prints ["print(same(k[0]))"] ["7"]
#guard rejects ["ref r = same(k[0])", "r = 3"] (.immutablePlace (.var "r"))

-- Any other index is checked as an array's of length 1 (D-0009): a
-- constant one out of range or negative is rejected, a computed one fails
-- at run time.
#guard rejects ["print(k[1])"] (.constantIndexOutOfBounds (kAt 1))
#guard rejects ["k[1] = 5"] (.constantIndexOutOfBounds (kAt 1))
#guard rejects ["print(k[-1])"] (.negativeIndex (kAt (-1)))
#guard rejects ["k[-1] = 5"] (.negativeIndex (kAt (-1)))
#guard rejects ["print(k[0][1])"] (.constantIndexOutOfBounds (.index (kAt 0) (.int 1)))
#guard failsAfter ["print(k[0])", "print(k[three()])"] ["7"]
#guard failsAfter ["k[three()] = 5"] []
#guard failsAfter ["var xs: List[Int] = [0, 2]", "print(k[xs.pop()])"] []

-- The element has no memory origin: no reference may point into it.
#guard rejects ["ref r = k[0]"] (.escapingReference "main")
#guard rejects ["ref r = k", "ref q = r[0]"] (.escapingReference "main")
#guard runLines (lib ++ ["def f(ref k: Int) -> ref [k] Int:", "    return k[0]",
    "def main():", "    var k = 7", "    print(f(k))"]) ==
  some (.rejected ⟨"f", .escapingReference "f"⟩)
-- So is a reference returned through a `ref` parameter given `k[0]`.
#guard runLines (lib ++ ["def f(ref k: Int) -> ref [k] Int:", "    return same(k[0])",
    "def main():", "    var k = 7", "    print(f(k))"]) ==
  some (.rejected ⟨"f", .escapingReference "f"⟩)
-- The compiler finds that once it has typed the place, and, in a return,
-- compared its type with the result's, before a later error, but after an
-- unknown name in its index.
#guard runLines (lib ++ ["def f(ref k: Int) -> ref [k] Bool:", "    return k[0]",
    "def main():", "    var k = 7", "    print(f(k))"]) ==
  some (.rejected ⟨"f", .typeMismatch .bool .int⟩)
#guard rejects ["ref r = k[-1]"] (.escapingReference "main")
#guard rejects ["ref r = k[zz]"] (.unknownVariable "zz")
-- An index out of range is reported late: an unknown function in the
-- value assigned comes first.
#guard rejects ["k[0][1] = zz()"] (.unknownFunction "zz")

-- Inference, too, takes `k[0]` passed `ref` for a reference that cannot
-- change: `pick(k[0], s) + t` calls `T.__radd__`, not `S.__add__`, which
-- takes `mut self`.
#guard runLines (["@fieldwise_init", "struct S(Copyable, Movable):", "    var v: Int",
    "    def __add__(mut self, o: T) -> Int:", "        return self.v + o.w",
    "@fieldwise_init", "struct T(Copyable, Movable):", "    var w: Int",
    "    def __radd__(self, o: S) -> Int:", "        return o.v * 100 + self.w",
    "def pick(ref a: Int, ref s: S) -> ref [a, s] S:", "    return s",
    "def main():", "    var k = 7", "    var s = S(1)", "    print(pick(k[0], s) + T(2))"]) ==
  some (.finished ["102"])

-- An index must be an `Int`; `__getitem__` of an `Int` has one overload.
#guard rejects ["print(k[True])"] (.typeMismatch .int .bool)
#guard rejects ["k[0] = True"] (.typeMismatch .int .bool)
-- `k` must be initialized, and may be changed only where it may.
#guard rejects ["var u: Int", "print(u[0])"] (.uninitializedUse (.index (.var "u") (.int 0)))
#guard runLines (lib ++ ["def f(k: Int):", "    k[0] = 5", "def main():", "    f(1)"]) ==
  some (.rejected ⟨"f", .immutablePlace (.index (.var "k") (.int 0))⟩)

end MojoGrimoireTest.Parse.IntIndex
