import MojoGrimoire.Interp.Run

/-!
Tests of `^` on a value of type `Int` or `Bool`. The compiler does not move
such a value: it warns that the transfer has no effect, and the place keeps
its value. So `x^` checks and runs as a copy of `x`, from any place that may
be read, including a `read` parameter, a field and a reference. Each program
is written in Mojo in its comment, and is checked and run.
-/

namespace MojoGrimoireTest.Interp.TrivialTransfer

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Interp

private def v (x : Name) : Place := .var x
private def fld (x f : Name) : Place := .field (.var x) f
private def use (x : Name) : Expr := .place (v x)
private def flags : Ty := .struct "Flags"

/-- `@fieldwise_init struct Flags: var on: Bool; var n: Int` -/
private def flagsDecl : StructDecl :=
  ⟨"Flags", [("on", .bool), ("n", .int)], .none, true, none, none, []⟩

/-- Runs a program with `Flags`, the functions `funs`, and a `main` whose
body is `body`. -/
private def go (body : List Stmt) (funs : List FunDecl := []) : Outcome :=
  run ⟨[flagsDecl], funs ++ [⟨"main", [], .noneType, body, none⟩]⟩ 10000

-- `var x = 1; var y = x^; print(x, y)`
#guard go [.decl "x" .int (some (.int 1)), .decl "y" .int (some (.transfer (v "x"))),
  .print [use "x", use "y"]] == .finished ["1 1"]

-- `var b = True; var c = b^; print(b, c)`
#guard go [.decl "b" .bool (some (.bool true)), .decl "c" .bool (some (.transfer (v "b"))),
  .print [use "b", use "c"]] == .finished ["True True"]

-- `var f = Flags(True, 2); var n = f.n^; print(f.on, f.n, n)`: the struct is
-- left whole, so it may end.
#guard go [.decl "f" flags (some (.call "Flags" [.bool true, .int 2])),
  .decl "n" .int (some (.transfer (fld "f" "n"))),
  .print [.place (fld "f" "on"), .place (fld "f" "n"), use "n"]] == .finished ["True 2 2"]

-- `def show(x: Int): var y = x^; print(x, y)`: a `read` parameter may be
-- transferred from, since nothing is taken from it.
#guard go [.expr (.call "show" [.int 4])]
  [⟨"show", [⟨.read, "x", .int⟩], .noneType,
    [.decl "y" .int (some (.transfer (v "x"))), .print [use "x", use "y"]], none⟩] ==
  .finished ["4 4"]

-- `def bump(mut x: Int): var y = x^; x = y + 1`: a `mut` parameter is
-- still initialized when the function returns.
#guard go [.decl "a" .int (some (.int 1)), .expr (.call "bump" [use "a"]), .print [use "a"]]
  [⟨"bump", [⟨.mutable, "x", .int⟩], .noneType,
    [.decl "y" .int (some (.transfer (v "x"))),
     .assign (v "x") (.binary .add (use "y") (.int 1))], none⟩] == .finished ["2"]

-- `var x = 1; ref r = x; var y = r^; print(x, y)`: through a reference too.
#guard go [.decl "x" .int (some (.int 1)), .refDecl "r" (use "x"),
  .decl "y" .int (some (.transfer (v "r"))), .print [use "x", use "y"]] == .finished ["1 1"]

-- `while i < 3: i = i + x^`: a transfer in a loop leaves `x` for the next
-- iteration.
#guard go [.decl "x" .int (some (.int 1)), .decl "i" .int (some (.int 0)),
  .whileLoop (.binary .lt (use "i") (.int 3))
    [.assign (v "i") (.binary .add (use "i") (.transfer (v "x")))],
  .print [use "x", use "i"]] == .finished ["1 3"]

-- `var x: Int; var y = x^`: the place must still be initialized.
#guard go [.decl "x" .int none, .decl "y" .int (some (.transfer (v "x")))] ==
  .rejected ⟨"main", .uninitializedUse (v "x")⟩

end MojoGrimoireTest.Interp.TrivialTransfer
