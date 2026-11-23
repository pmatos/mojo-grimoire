import MojoGrimoire.Core.Program

/-!
Tests of the abstract syntax: a small program, written as a term, and checks
that equality of terms is decidable and structural.

The program, in Mojo:

```
@fieldwise_init
struct Counter(Copyable):
    var count: Int

    def bump(mut self, by: Int):
        self.count = self.count + by

    def __deinit__(deinit self):
        print("done", self.count)

def main():
    var c: Counter = Counter(1)
    c.bump(2)
    var d: Counter = c.copy()
    if c.count < 10 and d.count > 0:
        print(c.count)
```
-/

namespace MojoGrimoireTest.Core

open MojoGrimoire.Core

private def self_ : Place := .var "self"

private def bump : FunDecl where
  name := "bump"
  params := [⟨.mutable, "self", .struct "Counter"⟩, ⟨.read, "by", .int⟩]
  result := .noneType
  body := [.assign (.field self_ "count")
    (.binary .add (.place (.field self_ "count")) (.place (.var "by")))]

private def counter : StructDecl where
  name := "Counter"
  fields := [("count", .int)]
  copying := .explicit
  fieldwiseInit := true
  init := none
  deinit := some [.print [.str "done", .place (.field self_ "count")]]
  methods := [bump]

private def mainFun : FunDecl where
  name := "main"
  params := []
  result := .noneType
  body := [
    .decl "c" (.struct "Counter") (some (.call "Counter" [.int 1])),
    .expr (.method (.var "c") "bump" [.int 2]),
    .decl "d" (.struct "Counter") (some (.copy (.var "c"))),
    .ifElse
      (.binary .and
        (.binary .lt (.place (.field (.var "c") "count")) (.int 10))
        (.binary .gt (.place (.field (.var "d") "count")) (.int 0)))
      [.print [.place (.field (.var "c") "count")]]
      []]

private def program : Program := { structs := [counter], funs := [mainFun] }

#guard program == program
#guard program != { structs := [counter], funs := [] }
#guard (program.structs.map (·.name)) == ["Counter"]
#guard Place.field (.var "c") "count" != Place.var "c"
#guard Expr.transfer (.var "c") != Expr.copy (.var "c")
#guard Stmt.ifElse (.bool true) [] [] != Stmt.whileLoop (.bool true) []

/-- Two places are equal only when they are the same tree. -/
example : (Place.field (.var "a") "f" == Place.field (.var "b") "f") = false := by decide

#guard Place.index (.var "xs") (.int 0) == Place.index (.var "xs") (.int 0)
#guard Place.index (.var "xs") (.int 0) != Place.index (.var "xs") (.int 1)
#guard Expr.list (.list .int) [.int 1] != Expr.list (.array .int 1) [.int 1]

end MojoGrimoireTest.Core
