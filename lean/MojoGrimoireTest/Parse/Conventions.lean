import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the argument conventions as the parser reads them (#68). The
compiler spells the immutable convention `imm`, rejects `read` with
"'read' was removed; use 'imm'", and reads `owned` as an ordinary name.
The suite cannot compare the model's syntax error with the compiler's parse
error, so the rejections are pinned here. Each program is written one line
per string.
-/

namespace MojoGrimoireTest.Parse.Conventions

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

/-- The function `f` with the parameters `ps`, which returns `r`, and a
`main` that prints `f(a)`. -/
private def withF (ps r a : String) : Ran :=
  runLines ["def f(" ++ ps ++ ") -> Int:", "    return " ++ r, "def main():",
    "    var x = 7", "    print(f(" ++ a ++ "))"]

/-- A struct `S` whose method `get` takes `self` with the convention `c`. -/
private def withSelf (c : String) : Ran :=
  runLines ["@fieldwise_init", "struct S(Movable):", "    var a: Int",
    "    def get(" ++ c ++ " self) -> Int:", "        return self.a",
    "def main():", "    var s = S(1)", "    print(s.get())"]

private def removed : String := "`read` was removed; use `imm`"

/-- Whether a run was rejected by the checker. -/
private def rejected : Ran → Bool
  | .ok (.rejected _) => true
  | _ => false

-- `imm` is the immutable convention, before a parameter and before `self`.
#guard withF "imm xs: Array[Int, 2]" "xs[1]" "[1, 2]" == .ok (.finished ["2"])
#guard withF "imm xs: List[Int]" "xs[0] + xs[1]" "[3, 4]" == .ok (.finished ["7"])
#guard withSelf "imm" == .ok (.finished ["1"])

-- After a convention, `imm`, `read` and `owned` are parameter names.
#guard withF "imm imm: Int" "1" "x" == .ok (.finished ["1"])
#guard withF "imm read: Int" "read" "x" == .ok (.finished ["7"])
#guard withF "imm owned: Int" "owned" "x" == .ok (.finished ["7"])
#guard withF "mut imm: Int" "1" "x" == .ok (.finished ["1"])
#guard withF "var imm: Int" "1" "x" == .ok (.finished ["1"])
#guard withF "var owned: Int" "owned" "x" == .ok (.finished ["7"])

-- `owned` is a name: a parameter, and a local.
#guard withF "owned: Int" "owned + 1" "x" == .ok (.finished ["8"])
#guard runLines ["def main():", "    var owned = 3", "    print(owned)"] ==
  .ok (.finished ["3"])

-- `read` and `imm` are names outside a parameter list.
#guard runLines ["def main():", "    var read = 3", "    var imm = 4", "    print(read, imm)"] ==
  .ok (.finished ["3 4"])
#guard runLines ["def read() -> Int:", "    return 3", "def imm(x: Int) -> Int:",
  "    return x", "def main():", "    print(read(), imm(4))"] == .ok (.finished ["3 4"])

-- `read` at the start of a parameter is rejected, whatever follows it.
#guard withF "read x: Int" "x" "1" == .error 1 removed
#guard withF "read xs: Array[Int, 2]" "xs[1]" "[1, 2]" == .error 1 removed
#guard withSelf "read" == .error 4 removed
#guard withF "read: Int" "1" "x" == .error 1 removed
#guard withF "read" "1" "x" == .error 1 removed
#guard withF "x: Int, read y: Int" "1" "x, x" == .error 1 removed

-- `imm` with no name after it is rejected, as the compiler's "expected
-- argument name".
#guard withF "imm: Int" "1" "x" == .error 1 "expected a name"
#guard withF "imm" "1" "x" == .error 1 "expected a name"

-- `owned` is not a convention: `owned xs: T` is a parameter `owned` with no
-- type, where the compiler expects `)`.
#guard withF "owned xs: Int" "xs" "x" == .error 1 "the parameter `owned` has no type"

-- An `imm` parameter cannot be assigned, as one with no convention cannot.
#guard rejected (runLines ["def f(imm x: Int) -> Int:", "    x = 2", "    return x",
  "def main():", "    print(f(7))"])
#guard runLines ["def f(imm x: Int) -> Int:", "    x = 2", "    return x",
  "def main():", "    print(f(7))"] ==
  runLines ["def f(x: Int) -> Int:", "    x = 2", "    return x",
  "def main():", "    print(f(7))"]

end MojoGrimoireTest.Parse.Conventions
