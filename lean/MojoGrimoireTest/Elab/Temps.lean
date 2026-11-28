import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the temporaries that a returned reference may point into (#80):
elaboration gives a temporary origin argument a hidden variable, declared
right before its statement, and it dies as a local variable declared there
would, at the last use of the reference. Each expected outcome is the
compiler's (nightly 1.3.0.dev2026111905). The programs are parsed from
text, one line per string, after the shared declarations.
-/

namespace MojoGrimoireTest.Elab.Temps

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp
open MojoGrimoire.Elab

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct P(ImplicitlyCopyable):",
  "    var v: Int",
  "    def __add__(self, o: Self) -> Self:",
  "        print(\"add\", self.v, o.v)",
  "        return P(self.v + o.v)",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.v)",
  "def same(ref x: P) -> ref [x] P:",
  "    return x",
  "def vv(ref x: P) -> Int:",
  "    return x.v",
  "def mk(v: Int) -> P:",
  "    print(\"mk\", v)",
  "    return P(v)",
  "def first(ref xs: List[Int]) -> ref [xs] List[Int]:",
  "    return xs"]

/-- Parses a `main` whose body is the lines `ls`, after the declarations. -/
private def prog (ls : List String) : Option Program :=
  (parse ("\n".intercalate (decls ++ "def main():" :: ls))).toOption

/-- Parses, checks and runs a `main` whose body is the lines `ls`. -/
private def inMain (ls : List String) : Option Outcome := (prog ls).map (run · 100000)

/-- The elaborated body of a `main` whose body is the lines `ls`. -/
private def elabMain (ls : List String) : Option (List Stmt) :=
  (prog ls).bind fun p => (findFun (elabProgram p) "main").map (·.body)

private def t0 : Place := .var (tempName 0)
private def newT0 : Stmt := .decl (tempName 0) (.struct "P") none

-- The temporary gets a hidden variable, declared before its statement, and
-- dies once `vv`, the call that last uses the reference, is done.
#guard elabMain ["    print(vv(same(P(1))))"] ==
  some [newT0, .print [.withDrops (.call "vv" [.call "same" [.temp (tempName 0)
    (.call "P" [.int 1])]]) [] [t0]]]
#guard inMain ["    print(vv(same(P(1))), vv(same(P(2))))"] ==
  some (.finished ["drop 1", "drop 2", "1 2"])

-- Two temporaries borrowed by one call die after it, the last made first.
#guard inMain ["    var q = same(mk(1)) + same(mk(2))", "    print(q.v)"] ==
  some (.finished ["mk 1", "mk 2", "add 1 2", "drop 2", "drop 1", "3", "drop 3"])

-- Read by value, it lives until its operation's operands are read.
#guard inMain ["    var xs: List[P] = [same(mk(1)), same(mk(2))]", "    print(len(xs))"] ==
  some (.finished ["mk 1", "mk 2", "drop 1", "drop 2", "drop 1", "drop 2", "2"])

-- In a `while` condition, it is made and destroyed on each run of it.
#guard inMain ["    var i = 0", "    while vv(same(mk(i))) < 2:", "        i += 1",
    "    print(\"end\")"] ==
  some (.finished ["mk 0", "drop 0", "mk 1", "drop 1", "mk 2", "drop 2", "end"])

-- A temporary whose value is not dropped gets no hidden variable.
#guard elabMain ["    print(len(first([1, 2])))"] ==
  some [.print [.call "len" [.call "first" [.list (.list .int) [.int 1, .int 2]]]]]

end MojoGrimoireTest.Elab.Temps
