import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of `^` after a place followed by another token (#54). The compiler
reads `^` as binary XOR when the next token, in the same statement, can
start an expression and is not `.`; otherwise `^` is a transfer. XOR is
outside the subset, so the parser rejects the first reading with a syntax
error. Each program is written one line per string.
-/

namespace MojoGrimoireTest.Parse.XorCaret

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

/-- `def main():`, `var x = 3`, the line `l`, and `print(x)`. -/
private def withX (l : String) : Ran :=
  runLines ["def main():", "    var x = 3", "    " ++ l, "    print(x)"]

private def xor : String := "a binary `^` (XOR), which is outside the subset"

-- An operand after `^` makes it XOR: the compiler prints `2` for `x^ + 1`
-- and `-4` for `x^ - 1`, and rejects `x^ * 2` and `x^ == 3`.
#guard withX "var y = x^ + 1" == .error 3 xor
#guard withX "var y = x^ - 1" == .error 3 xor
#guard withX "var y = x^ (1)" == .error 3 xor
#guard withX "var y = x^ [1]" == .error 3 xor
#guard withX "var y = x^ * 2" == .error 3 xor
#guard withX "var y = x^ == 3" == .error 3 xor
#guard withX "var y = x^ 5" == .error 3 xor
#guard withX "var y = x^ \"a\"" == .error 3 xor
#guard withX "var y = x^ x" == .error 3 xor
#guard withX "var y = x^ True" == .error 3 xor
#guard withX "var y = x^ not True" == .error 3 xor

-- XOR is decided before the term is checked to be a place.
#guard withX "var y = (x)^ + 1" == .error 3 xor

-- The lexer ignores line breaks inside brackets. The compiler reads XOR in
-- call arguments and on a deeper-indented line, and fails to parse a
-- parenthesized expression whose next line is at the statement's column.
#guard runLines ["def main():", "    var x = 3", "    var y = (x^", "        + 1)", "    print(y)"] ==
  .error 4 xor
#guard runLines ["def f(a: Int) -> Int:", "    return a", "def main():", "    var x = 3",
  "    var y = f(x^", "+ 1)", "    print(y)"] == .error 6 xor
#guard runLines ["def main():", "    var x = 3", "    var y = (x^", "    + 1)", "    print(y)"] ==
  .error 4 xor

-- `^` at the end of an expression is a transfer.
#guard withX "var y = x^" == .ok (.finished ["3"])
#guard runLines ["def f(a: Int) -> Int:", "    return a", "def main():", "    var x = 3",
  "    print(f(x^))"] == .ok (.finished ["3"])
#guard runLines ["def main():", "    var x = 3", "    var y = (x^)", "    print(y)"] ==
  .ok (.finished ["3"])

-- A token that cannot start an expression leaves `^` a transfer: `<`, `and`,
-- `or`, `if`, `in` and `is` are binary operators or keywords.
#guard withX "print(x^ < 4)" == .ok (.finished ["True", "3"])
#guard runLines ["def main():", "    var b = True", "    print(b^ and True, b^ or False)"] ==
  .ok (.finished ["True True"])

-- `.` is excluded on purpose: `s^.f` is a transfer and then a field, which
-- the compiler reads as the field `s.f` (#66; more in `TransferField`).
#guard runLines ["@fieldwise_init", "struct S(Movable):", "    var f: Int", "def main():",
  "    var s = S(4)", "    var y = s^.f", "    print(y)"] == .ok (.finished ["4"])

-- A deeper-indented next line continues the statement for the compiler,
-- which reads `x^` and `+ 1` below as XOR. The model's lexer ends the
-- logical line, and the indented line is a syntax error.
#guard runLines ["def main():", "    var x = 3", "    var y = x^", "        + 1", "    print(y)"] ==
  .error 4 "expected a name"

end MojoGrimoireTest.Parse.XorCaret
