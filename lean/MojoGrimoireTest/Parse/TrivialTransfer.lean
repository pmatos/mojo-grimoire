import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of `^` on a value of type `Int` or `Bool`. The compiler does not move
such a value: it warns that the transfer has no effect, and treats `p^` as
the place `p`. Inference does the same, so these programs are parsed from
text, then checked and run. Each program is written one line per string.
The last tests show that `^` on an element of any other type, even an
implicitly copyable or copyable struct or a list, stays a transfer, which the
checker rejects as the compiler does.
-/

namespace MojoGrimoireTest.Parse.TrivialTransfer

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses, checks and runs the program whose lines are `ls`, after the
shared declarations. -/
private def go (ls : List String) : Option Outcome :=
  (parse ("\n".intercalate (decls ++ ls))).toOption.map (run · 100000)
where
  decls := [
    "@fieldwise_init",
    "struct Res:",
    "    var id: Int",
    "    fn __deinit__(deinit self):",
    "        print(\"drop\", self.id)",
    "@fieldwise_init",
    "struct Flags:",
    "    var on: Bool",
    "    var n: Int",
    "def take(var r: Res) -> Int:",
    "    return r.id",
    "def two(x: Int, y: Int):",
    "    print(x, y)",
    "def bump(mut x: Int) -> Int:",
    "    x += 10",
    "    return x",
    "def show(x: Int):",
    "    var y = x^",
    "    print(\"show\", x, y)"]

-- A variable, a `Bool`, a field, a `read` parameter and a reference keep
-- their values, and a struct whose `Int` field was transferred stays whole.
#guard go [
  "def main():",
  "    var x = 1",
  "    var y = x^",
  "    var b = True",
  "    var c = b^",
  "    var f = Flags(False, 2)",
  "    var n = f.n^",
  "    show(x^)",
  "    ref r = x",
  "    var z = r^",
  "    print(x, y, b, c, f.on, f.n, n, z)"] ==
  some (.finished ["show 1 1", "1 1 True True False 2 2 1"])

-- `x^` of a `Res`'s `Int` field leaves the `Res` whole, though it has a
-- `__deinit__`.
#guard go ["def main():", "    var a = Res(1)", "    var n = a.id^", "    print(n, a.id)"] ==
  some (.finished ["1 1", "drop 1"])

-- `two(a.id^, take(a^))`: `a.id^` is the place `a.id`, read once every
-- argument is evaluated, after `a` was moved.
#guard go ["def main():", "    var a = Res(1)", "    two(a.id^, take(a^))"] ==
  some (.rejected ⟨"main", .uninitializedUse (.field (.var "a") "id")⟩)

-- `two(z^, bump(z))`: `z^` is read after `bump` changed `z`.
#guard go ["def main():", "    var z = 1", "    two(z^, bump(z))"] == some (.finished ["11 11"])

-- `bump(x^)`: the place is passed to the `mut` parameter.
#guard go ["def main():", "    var x = 1", "    var y = bump(x^)", "    print(x, y)"] ==
  some (.finished ["11 11"])

-- The place must still be initialized.
#guard go ["def main():", "    var x: Int", "    var y = x^"] ==
  some (.rejected ⟨"main", .uninitializedUse (.var "x")⟩)

-- An `Int` element of a list is the place `xs[0]`, which keeps its value
-- (#43).
#guard go ["def main():", "    var xs: List[Int] = [1, 2]", "    var y = xs[0]^",
  "    print(y, xs[0])"] == some (.finished ["1 1"])

-- So is a `Bool` element.
#guard go ["def main():", "    var bs: List[Bool] = [True, False]", "    var c = bs[1]^",
  "    print(c, bs[1])"] == some (.finished ["False False"])

-- So is an element of an array.
#guard go ["def main():", "    var a = [5, 6]", "    var c = a[1]^", "    print(c, a[1])"] ==
  some (.finished ["6 6"])

-- `xs[0].id^`: an `Int` field of an element leaves the element whole, and the
-- array is destroyed after its last use.
#guard go ["def main():", "    var xs = [Res(1), Res(2)]", "    var n = xs[0].id^",
  "    print(n)"] == some (.finished ["drop 1", "drop 2", "1"])

-- An element of a `read` parameter, and of a list through a reference.
#guard go ["def first(xs: List[Int]) -> Int:", "    return xs[0]^", "def main():",
  "    var xs: List[Int] = [4, 5]", "    ref r = xs", "    var k = r[1]^",
  "    print(first(xs), k, xs[1])"] == some (.finished ["4 5 5"])

-- `bump(xs[0]^)`: the element is passed to the `mut` parameter.
#guard go ["def main():", "    var xs: List[Int] = [1, 2]", "    var y = bump(xs[0]^)",
  "    print(y, xs[0])"] == some (.finished ["11 11"])

-- An element of struct type stays a transfer, which the checker rejects.
#guard go ["def main():", "    var rs: List[Res] = [Res(1)]", "    var r = rs[0]^"] ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "rs") (.int 0))⟩)

-- So does one of an `ImplicitlyCopyable` struct, of a list or an array (#105),
-- also passed to a `var` parameter, or followed by a field.
private def tok := ["@fieldwise_init", "struct Tok(ImplicitlyCopyable):", "    var id: Int",
  "    def __deinit__(deinit self):", "        print(\"drop\", self.id)"]
#guard go (tok ++ ["def main():", "    var ts: List[Tok] = [Tok(1), Tok(2)]",
  "    var t = ts[0]^"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ts") (.int 0))⟩)
#guard go (tok ++ ["def main():", "    var ts = [Tok(1), Tok(2)]", "    var t = ts[1]^"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ts") (.int 1))⟩)
#guard go (tok ++ ["def eat(var t: Tok) -> Int:", "    return t.id", "def main():",
  "    var ts: List[Tok] = [Tok(1), Tok(2)]", "    print(eat(ts[0]^))"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ts") (.int 0))⟩)
#guard go (tok ++ ["def main():", "    var ts: List[Tok] = [Tok(1), Tok(2)]",
  "    print(ts[0]^.id)"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ts") (.int 0))⟩)

-- Even with no `__deinit__`, like `Int`.
#guard go ["@fieldwise_init", "struct Tok(ImplicitlyCopyable):", "    var id: Int",
  "def main():", "    var ts: List[Tok] = [Tok(1), Tok(2)]", "    var t = ts[0]^"] ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ts") (.int 0))⟩)

-- And one of a `Copyable` struct.
private def point := ["@fieldwise_init", "struct Point(Copyable):", "    var x: Int",
  "    var y: Int"]
#guard go (point ++ ["def main():", "    var ps: List[Point] = [Point(1, 2)]",
  "    var p = ps[0]^"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ps") (.int 0))⟩)
#guard go (point ++ ["def main():", "    var ps = [Point(1, 2), Point(3, 4)]",
  "    var p = ps[1]^"]) ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "ps") (.int 1))⟩)

-- And a `List[Int]` element of a list or an array.
#guard go ["def main():", "    var xss: List[List[Int]] = [[1], [2, 3]]",
  "    var ys = xss[1]^"] ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "xss") (.int 1))⟩)
#guard go ["def main():", "    var xss: Array[List[Int], 2] = [[1], [2, 3]]",
  "    var ys = xss[1]^"] ==
  some (.rejected ⟨"main", .transferFromElement (.index (.var "xss") (.int 1))⟩)

end MojoGrimoireTest.Parse.TrivialTransfer
