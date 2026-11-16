import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the parser: Mojo programs, as text, parsed and run to the lines
they print. Each program is written one line per string.
-/

namespace MojoGrimoireTest.Parse

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- What parsing and running a program gives: its outcome, or the line
and message of a syntax error. -/
private inductive Ran where
  | ok (o : Outcome)
  | error (line : Nat) (message : String)
  deriving BEq

/-- Parses and runs the program whose lines are `ls`. -/
private def runLines (ls : List String) : Ran :=
  match parse ("\n".intercalate ls) with
  | .ok prog => .ok (run prog 100000)
  | .error e => .error e.line e.message

private def res : List String := [
  "@fieldwise_init",
  "struct Res:",
  "    var id: Int",
  "",
  "    fn __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  ""]

#guard runLines ["def main():", "    print(\"hi\", 1 + 2 * 3, True)"] == .ok (.finished ["hi 7 True"])

-- Precedence, comparisons, `and`, `or`, `not`, and augmented assignment.
#guard runLines [
  "def main():",
  "    var x = 7 // 2 - -1  # 4",
  "    x += 1",
  "    print(x, x % 3 == 2 and not x < 0, (1 + 2) * 2, False or x >= 5)"] ==
  .ok (.finished ["5 True 6 True"])

-- ASAP destruction, moves, and `if`/`elif`/`else` and `while`.
#guard runLines (res ++ [
  "def consume(var r: Res):",
  "    print(\"consumed\", r.id)",
  "",
  "def main():",
  "    var a = Res(1)",
  "    var b = Res(2)",
  "    var i = 0",
  "    while i < 3:",
  "        i += 1",
  "    if i == 1:",
  "        print(\"one\")",
  "    elif i == 3:",
  "        consume(a^)",
  "    else:",
  "        pass",
  "    print(\"end\", b.id)"]) ==
  .ok (.finished ["consumed 1", "drop 1", "end 2", "drop 2"])

-- Methods, `__init__`, `mut`, conformances and `.copy()`.
#guard runLines [
  "struct Counter(Copyable, Movable):",
  "    \"\"\"A counter.\"\"\"",
  "    var count: Int",
  "",
  "    fn __init__(out self, start: Int):",
  "        self.count = start",
  "",
  "    def bump(mut self, by: Int):",
  "        self.count += by",
  "",
  "    def get(self) -> Int:",
  "        return self.count",
  "",
  "def main():",
  "    var c = Counter(3)",
  "    c.bump(4)",
  "    var d = c.copy()",
  "    d.bump(1)",
  "    print(c.get(), d.get())"] == .ok (.finished ["7 8"])

-- Lists: literals, `List[T]()`, `append`, `len` and indexing.
#guard runLines [
  "def main():",
  "    var xs: List[Int] = [1, 2]",
  "    var ys = List[Int]()",
  "    var zs: List[Int] = []",
  "    xs.append(3)",
  "    ys.append(xs[0] + xs[2])",
  "    xs[1] = 20",
  "    print(len(xs), xs[1], ys[0], len(zs))"] == .ok (.finished ["3 20 4 0"])

-- References with an origin keep their values alive.
#guard runLines (res ++ [
  "def pick(ref a: Res, ref b: Res, first: Bool) -> ref [a, b] Res:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def main():",
  "    var a = Res(1)",
  "    var b = Res(2)",
  "    ref r = pick(a, b, False)",
  "    r.id = 12",
  "    print(\"x\")",
  "    print(r.id)"]) == .ok (.finished ["x", "12", "drop 12", "drop 1"])

-- A rejected program reports its class of error.
#guard runLines (res ++ [
  "def main():",
  "    var a = Res(1)",
  "    var b = a",
  "    print(b.id)"]) == .ok (.rejected ⟨"main", .implicitCopy (.struct "Res")⟩)

-- Syntax errors name their line.
#guard runLines ["def main():", "    print(1 +)"] == .error 2 "expected a name"
#guard runLines ["def main():", "  print(1)", " print(2)"] ==
  .error 3 "a dedent to no enclosing indentation"

end MojoGrimoireTest.Parse
