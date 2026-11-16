import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the new value of an assignment whose right-hand side destroys or
consumes the old value of the same variable (#92): `s = s^.consume()`
consumes the old value of `s`, and the new one still dies as soon as it is
dead, as the compiler destroys it. Each expected outcome is the compiler's.
The programs are parsed from text, one line per string, after the shared
declarations.
-/

namespace MojoGrimoireTest.Elab.NewValue

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp
open MojoGrimoire.Elab

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  "    def consume(var self) -> Res:",
  "        print(\"consume\", self.id)",
  "        return Res(self.id + 100)",
  "def ident(var r: Res) -> Res:",
  "    return r^",
  "def eat(var r: Res) -> Res:",
  "    print(\"eat\", r.id)",
  "    return Res(r.id + 100)"]

/-- Parses a `main` whose body is the lines `ls`, after the declarations. -/
private def prog (ls : List String) : Option Program :=
  (parse ("\n".intercalate (decls ++ "def main():" :: ls))).toOption

/-- Parses, checks and runs a `main` whose body is the lines `ls`. -/
private def inMain (ls : List String) : Option Outcome := (prog ls).map (run · 100000)

/-- The elaborated body of a `main` whose body is the lines `ls`. -/
private def elabMain (ls : List String) : Option (List Stmt) :=
  (prog ls).bind fun p => (findFun (elabProgram p) "main").map (·.body)

private def s : Place := .var "s"
private def newS : Stmt := .decl "s" (.struct "Res") (some (.call "Res" [.int 1]))
private def consumeS : Expr := .method (.transferred s) "consume" []
private def after : Stmt := .print [.str "after"]

-- `s = s^.consume()`: the consumed value is not destroyed by `main`, and the
-- new one, never used, dies right after the assignment.
#guard elabMain ["    var s = Res(1)", "    s = s^.consume()", "    print(\"after\")"] ==
  some [newS, .assign s consumeS, .drop s, after]
#guard inMain ["    var s = Res(1)", "    s = s^.consume()", "    print(\"after\")"] ==
  some (.finished ["consume 1", "drop 1", "drop 101", "after"])

-- The same through a call that takes the consumed result.
#guard elabMain ["    var s = Res(1)", "    s = ident(s^.consume())", "    print(\"after\")"] ==
  some [newS, .assign s (.call "ident" [consumeS]), .drop s, after]
#guard inMain ["    var s = Res(1)", "    s = ident(s^.consume())", "    print(\"after\")"] ==
  some (.finished ["consume 1", "drop 1", "drop 101", "after"])

-- Twice in a row: the first new value is consumed by the second assignment,
-- and only the second one dies after it.
#guard elabMain ["    var s = Res(1)", "    s = s^.consume()", "    s = s^.consume()",
    "    print(\"after\")"] ==
  some [newS, .assign s consumeS, .assign s consumeS, .drop s, after]
#guard inMain ["    var s = Res(1)", "    s = s^.consume()", "    s = s^.consume()",
    "    print(\"after\")"] ==
  some (.finished ["consume 1", "drop 1", "consume 101", "drop 101", "drop 201", "after"])

-- A new value used later dies after its last use, as before.
#guard inMain ["    var s = Res(1)", "    s = s^.consume()", "    print(\"after\", s.id)"] ==
  some (.finished ["consume 1", "drop 1", "after 101", "drop 101"])
#guard inMain ["    var s = Res(1)", "    s = ident(s^.consume())", "    print(\"after\", s.id)"] ==
  some (.finished ["consume 1", "drop 1", "after 101", "drop 101"])

-- `s = eat(s^)`, which moves the old value away, is unchanged.
#guard elabMain ["    var s = Res(1)", "    s = eat(s^)", "    print(\"after\")"] ==
  some [newS, .assign s (.call "eat" [.transfer s]), .drop s, after]
#guard inMain ["    var s = Res(1)", "    s = eat(s^)", "    print(\"after\")"] ==
  some (.finished ["eat 1", "drop 1", "drop 101", "after"])

end MojoGrimoireTest.Elab.NewValue
