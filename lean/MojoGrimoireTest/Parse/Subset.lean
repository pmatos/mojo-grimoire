import MojoGrimoire.Parse.Subset
import MojoGrimoire.Interp.Run

/-!
Tests of the check of the constructs outside the subset (#180): a string
literal outside the `print` statement, a call of the standard library's
`range` outside `List[T](…)`, and the statements `break` and `continue`
(#268). The driver reports such a program as
`outside the subset: line N: MESSAGE` with exit 3, at the line where the
statement that holds the first construct starts, in the order of the file.
-/

namespace MojoGrimoireTest.Parse.Subset

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- How the driver reads the program whose lines are `ls`. -/
private def readLines (ls : List String) : Except ReadError Program :=
  parseSubset ("\n".intercalate ls)

/-- Why the driver does not read the program whose lines are `ls`. -/
private def readError (ls : List String) : Option ReadError :=
  match readLines ls with
  | .error e => some e
  | .ok _ => none

/-- Whether the program whose lines are `ls` is outside the subset as the
construct `m`, at the line `n`. -/
private def outside (ls : List String) (n : Nat) (m : String) : Bool :=
  readError ls == some (.outside ⟨n, m⟩)

/-- The outcome of a run of the program whose lines are `ls`, once read as
the driver reads it; `none` when it is not read. -/
private def runLines (ls : List String) : Option Outcome :=
  match readLines ls with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- A struct and a function, on lines 1 to 5, then `main`, on line 6,
whose body is `body`, from line 7. -/
private def inMain (body : List String) : List String :=
  ["@fieldwise_init", "struct P(Copyable):", "    var x: Int",
   "def f(x: Int) -> Int:", "    return x",
   "def main():"] ++ body.map ("    " ++ ·)

-- String literals as arguments of the `print` statement are in the subset,
-- also in parentheses; docstrings are skipped by the parser.
#guard runLines (inMain ["\"\"\"Docs.\"\"\"", "print(\"a\", (\"b\"), 1)"]) ==
  some (.finished ["a b 1"])
-- A string literal anywhere else is not: in a declaration, a call, a list
-- literal printed, an index, a condition or a returned value.
#guard outside (inMain ["var s = \"a\""]) 7 outsideString
#guard outside (inMain ["var p = P(\"a\")"]) 7 outsideString
#guard outside (inMain ["print(f(\"a\"))"]) 7 outsideString
#guard outside (inMain ["print([\"a\"])"]) 7 outsideString
#guard outside (inMain ["var xs: List[Int] = [1]", "print(xs.pop(\"a\"))"]) 8 outsideString
#guard outside (inMain ["var xs: List[Int] = [1]", "xs[\"a\"] = 2"]) 8 outsideString
#guard outside (inMain ["while \"a\" == \"b\":", "    pass"]) 7 outsideString
#guard outside ["def g() -> Int:", "    return len(\"ab\")", "def main():", "    pass"]
  2 outsideString

-- A call of `range` is in the subset only as the one argument of
-- `List[T](…)`, where its own arguments are checked too.
#guard runLines (inMain ["print(List[Int](range(f(1), 3)))"]) == some (.finished ["[1, 2]"])
#guard outside (inMain ["var r = range(3)"]) 7 outsideRange
#guard outside (inMain ["print(len(range(3)))"]) 7 outsideRange
#guard outside (inMain ["var xs = List[Int](range(3), 4)"]) 7 outsideRange
#guard outside (inMain ["var xs = List[Int](range(range(3)))"]) 7 outsideRange
#guard outside (inMain ["var xs = List[Int](range(\"a\"))"]) 7 outsideString
#guard outside (inMain ["var x = f(1) + range(2)"]) 7 outsideRange

-- The line is where the statement that holds the construct starts: in an
-- `if`'s condition, a block, an `elif`, an `else`, a `while`, a block on the
-- line of its `:`, and a statement that goes on over several lines.
#guard outside (inMain ["if len(range(2)) == 2:", "    pass"]) 7 outsideRange
#guard outside (inMain ["if True:", "    pass", "elif \"a\" == \"a\":", "    pass"]) 9
  outsideString
#guard outside (inMain ["if True:", "    pass", "elif False:", "    pass", "else:",
  "    var s = \"a\""]) 12 outsideString
#guard outside (inMain ["var i = 0", "while i < 1:", "    i += 1", "    print(f(\"a\"))"]) 10
  outsideString
#guard outside (inMain ["if True: var r = range(1)"]) 7 outsideRange
#guard outside (inMain ["print(1,", "  f(\"a\"))"]) 7 outsideString

-- The first construct in the order of the file is reported: in a method
-- before `main`, or in a destructor that a struct declares before its
-- initializer.
#guard outside ["struct S(Movable):", "    var n: Int", "    def m(self) -> Int:",
  "        return len(range(1))", "    def __init__(out self):", "        self.n = len(\"a\")",
  "def main():", "    var s = \"a\""] 4 outsideRange
#guard outside ["def main():", "    print(1)", "struct S(Movable):", "    var n: Int",
  "    def __deinit__(deinit self):", "        print(f(\"a\"))",
  "    def __init__(out self):", "        self.n = len(range(1))"] 6 outsideString
-- Whatever other error the program has, before the construct or after it.
#guard outside (inMain ["print(nope)", "var s = \"a\"", "var t: Int = True"]) 8 outsideString
-- A syntax error anywhere comes first, since the program is parsed whole.
#guard readError (inMain ["var s = \"a\"", "var = 1"]) == some (.syntax ⟨8, "expected a name"⟩)

-- A variable or a parameter named `print` makes the `print` statement a
-- call of it, whose string literals are outside the subset; without them,
-- the checker reports that an `Int` cannot be called (#176).
#guard outside (inMain ["var print = 5", "print(\"a\")"]) 8 outsideString
#guard outside ["def g(print: Int):", "    print(\"a\")", "def main():", "    g(1)"] 2
  outsideString
#guard runLines (inMain ["var print = 5", "print(1)"]) ==
  some (.rejected ⟨"main", .missingMethod .int "__call__"⟩)
-- A variable is in scope after its declaration in its block only.
#guard runLines (inMain ["print(\"a\")", "var print = 5"]) == some (.finished ["a"])
#guard runLines (inMain ["if True:", "    var print = 5", "print(\"a\")"]) ==
  some (.finished ["a"])

-- A variable, a parameter, a struct or a function named `range` hides the
-- standard library's: the call is the program's own (#176).
#guard runLines (inMain ["var range = 5", "var x = range(3)"]) ==
  some (.rejected ⟨"main", .missingMethod .int "__call__"⟩)
#guard runLines ["def g(range: Int) -> Int:", "    return range(1)", "def main():",
  "    print(g(1))"] == some (.rejected ⟨"g", .missingMethod .int "__call__"⟩)
#guard runLines ["def main():", "    print(range(3))", "def range(n: Int) -> Int:",
  "    return n"] == some (.finished ["3"])
#guard runLines ["@fieldwise_init", "struct range(Copyable):", "    var n: Int", "def main():",
  "    var r = range(3)", "    print(r.n)"] == some (.finished ["3"])
-- A destructor's body has `self` alone in scope, as the checker gives it,
-- whatever parameters it declares.
#guard outside ["struct Foo:", "    var x: Int", "    def __init__(out self):", "        self.x = 1",
  "    def __deinit__(deinit self, range: Int):", "        var y = range(2)", "def main():",
  "    var f = Foo()"] 6 outsideRange
#guard readError ["struct Foo:", "    var x: Int", "    def __init__(out self):",
  "        self.x = 1", "    def __deinit__(deinit self, print: Int):", "        print(\"bye\")",
  "def main():", "    var f = Foo()"] == none
-- A variable hides it after its declaration in its block, not in its own
-- initializer nor after the block.
#guard outside (inMain ["print(len(range(3)))", "var range = 5"]) 7 outsideRange
#guard outside (inMain ["var range = len(range(3))"]) 7 outsideRange
#guard outside (inMain ["if True:", "    var range = 5", "var x = range(3)"]) 9 outsideRange

-- The suite programs that the ruling of 2026-11-21 on #180 removed, since
-- the suite cannot compare exit 3. The compiler rejects each one: the first
-- two as `noMatchingInit`, "no matching function in call to 'range'", and
-- the others as `noMatchingMethod`, "no matching method in call to
-- '__getitem__'" and "… 'pop'". Covering strings (#238) or a range as a
-- value (#239) brings them back.
#guard outside ["def main():", "    var xs = List[Int](range(\"a\"))", "    print(len(xs))"] 2
  outsideString
#guard outside ["def main():", "    var xs = List[Int](range(range(3)))", "    print(len(xs))"] 2
  outsideRange
#guard outside ["def main():", "    var xs: List[Int] = [5, 6]", "    print(xs[\"a\"])"] 3
  outsideString
#guard outside ["def main():", "    var xs: List[Int] = [5, 6]", "    print(xs.pop(\"a\"))"] 3
  outsideString

-- `break` and `continue` are outside the subset wherever they stand, by the
-- human's ruling of 2026-11-22 (#268): in a `while`, in an `if` inside it,
-- in a block on the line of its `:`, outside any loop, in a method and in a
-- destructor. Supporting them is #276.
#guard outside (inMain ["while True:", "    break"]) 8 (outsideLoopExit "break")
#guard outside (inMain ["var i = 0", "while i < 3:", "    i += 1", "    if i == 2:",
  "        continue", "    print(i)"]) 11 (outsideLoopExit "continue")
#guard outside (inMain ["while True: break"]) 7 (outsideLoopExit "break")
#guard outside (inMain ["var i = 0", "while i < 3:", "    i += 1", "    if i == 2: continue"]) 10
  (outsideLoopExit "continue")
#guard outside (inMain ["break"]) 7 (outsideLoopExit "break")
#guard outside (inMain ["if True:", "    pass", "else:", "    continue"]) 10
  (outsideLoopExit "continue")
#guard outside ["struct S(Movable):", "    var n: Int", "    def m(self):", "        while True:",
  "            continue", "    def __init__(out self):", "        self.n = 1", "def main():",
  "    print(1)"] 5 (outsideLoopExit "continue")
#guard outside ["struct S(Movable):", "    var n: Int", "    def __init__(out self):",
  "        self.n = 1", "    def __deinit__(deinit self):", "        break", "def main():",
  "    var s = S()"] 6 (outsideLoopExit "break")
-- The first construct in the order of the file is reported, against a
-- string literal or a call of `range` before it or after it, also on the
-- line of an `if` whose condition holds one.
#guard outside (inMain ["var s = \"a\"", "while True:", "    break"]) 7 outsideString
#guard outside (inMain ["while True:", "    break", "var r = range(3)"]) 8
  (outsideLoopExit "break")
#guard outside (inMain ["while True:", "    if \"a\" == \"b\": break"]) 8 outsideString
#guard outside (inMain ["while True:", "    if True: continue", "    print(len(range(2)))"]) 8
  (outsideLoopExit "continue")
-- Whatever other error the program has, and a syntax error anywhere comes
-- first.
#guard outside (inMain ["print(nope)", "while True:", "    break"]) 9 (outsideLoopExit "break")
#guard readError (inMain ["while True:", "    break", "var = 1"]) ==
  some (.syntax ⟨9, "expected a name"⟩)
#guard readError (inMain ["while True:", "    break 1"]) ==
  some (.syntax ⟨8, "expected the end of the line"⟩)
-- As names, both are keywords: the compiler fails to parse `var break = 1`
-- ("unexpected token in expression") and a parameter named `continue`
-- ("expected argument name"), and the model reads each as a syntax error.
#guard readError (inMain ["var break = 1", "print(break)"]) ==
  some (.syntax ⟨7, "`break` is a keyword"⟩)
#guard readError ["def g(continue: Int):", "    pass", "def main():", "    g(1)"] ==
  some (.syntax ⟨1, "`continue` is a keyword"⟩)
#guard readError (inMain ["var x = 1", "print(x + continue)"]) ==
  some (.syntax ⟨8, "`continue` is a keyword"⟩)
-- So are a function and a field of either name, which the compiler fails to
-- parse ("'break' cannot be used as a function name in this context",
-- "expected name for 'var' declaration").
#guard readError ["def break() -> Int:", "    return 1", "def main():", "    print(1)"] ==
  some (.syntax ⟨1, "`break` is a keyword"⟩)
#guard readError ["struct S(Movable):", "    var break: Int", "def main():", "    pass"] ==
  some (.syntax ⟨2, "`break` is a keyword"⟩)
-- A method's name in a struct, and the name after `.`, may be either word,
-- as in the compiler, which prints `1` for the first program and rejects
-- the second, "'S' value has no attribute 'continue'".
#guard runLines ["struct S(Movable):", "    var n: Int", "    def __init__(out self):",
  "        self.n = 1", "    def break(self) -> Int:", "        return self.n", "def main():",
  "    var s = S()", "    print(s.break())"] == some (.finished ["1"])
#guard runLines ["@fieldwise_init", "struct S(Movable):", "    var n: Int", "def main():",
  "    var s = S(1)", "    print(s.continue)"] ==
  some (.rejected ⟨"main", .unknownAttribute "S" "continue"⟩)
-- The programs of #268, which the pin builds and runs: the first prints
-- `3`, and the second `1`, `2`, `4` and `5`. Main read each word as a name
-- and rejected them as `unknownVariable`.
#guard outside ["def main():", "    var i = 0", "    while i < 5:", "        i += 1",
  "        if i == 3:", "            break", "    print(i)"] 6 (outsideLoopExit "break")
#guard outside ["def main():", "    var i = 0", "    while i < 5:", "        i += 1",
  "        if i == 3:", "            continue", "        print(i)"] 6
  (outsideLoopExit "continue")

end MojoGrimoireTest.Parse.Subset
