import MojoGrimoire.Check.Program

/-!
Tests of the static checker: small programs, each accepted or rejected with
the expected class of error. Each is written in Mojo in its comment. The
shared declarations are a resource `Res`, whose destructor prints, a
copyable `Pt`, and functions that take a `Res` by each convention.
-/

namespace MojoGrimoireTest.Check

open MojoGrimoire.Core MojoGrimoire.Check

private def v (x : Name) : Place := .var x
private def fld (x f : Name) : Place := .field (.var x) f
private def use (x : Name) : Expr := .place (v x)
private def res : Ty := .struct "Res"

/-- `@fieldwise_init struct Res: var id: Int; def __deinit__(deinit self): print("drop", self.id)` -/
private def resDecl : StructDecl :=
  ⟨"Res", [("id", .int)], .none, true, none,
    some [.print [.str "drop", .place (fld "self" "id")]], []⟩

/-- `@fieldwise_init struct Pt(Copyable): var x: Int; var y: Int` -/
private def ptDecl : StructDecl := ⟨"Pt", [("x", .int), ("y", .int)], .explicit, true, none, none, []⟩

/-- `@fieldwise_init struct Pair: var a: Res; var b: Res` -/
private def pairDecl : StructDecl :=
  ⟨"Pair", [("a", res), ("b", res)], .none, true, none, none, []⟩

/-- `def consume(var r: Res): print(r.id)` -/
private def consume : FunDecl := ⟨"consume", [⟨.owned, "r", res⟩], .noneType,
  [.print [.place (fld "r" "id")]], none⟩

/-- `def show(r: Res): print(r.id)` -/
private def showRes : FunDecl := ⟨"show", [⟨.read, "r", res⟩], .noneType,
  [.print [.place (fld "r" "id")]], none⟩

/-- `def bump(mut r: Res, other: Res): r.id = r.id + other.id` -/
private def bump : FunDecl := ⟨"bump", [⟨.mutable, "r", res⟩, ⟨.read, "other", res⟩], .noneType,
  [.assign (fld "r" "id") (.binary .add (.place (fld "r" "id")) (.place (fld "other" "id")))], none⟩

/-- `def addInts(mut a: Int, b: Int): a = a + b` -/
private def addInts : FunDecl := ⟨"addInts", [⟨.mutable, "a", .int⟩, ⟨.read, "b", .int⟩], .noneType,
  [.assign (v "a") (.binary .add (use "a") (use "b"))], none⟩

private def lib : List FunDecl := [consume, showRes, bump, addInts]

/-- A program with the shared declarations, extra functions `funs`, and a
`main` whose body is `body`. -/
private def prog (body : List Stmt) (funs : List FunDecl := []) (structs : List StructDecl := []) :
    Program :=
  ⟨[resDecl, ptDecl, pairDecl] ++ structs, lib ++ funs ++ [⟨"main", [], .noneType, body, none⟩]⟩

private def newRes (x : Name) (n : Int) : Stmt := .decl x res (some (.call "Res" [.int n]))

/-- The class of error a program is rejected with, or `none` if it is
accepted. -/
private def verdict (p : Program) : Option CheckError :=
  match checkProgram p with
  | .ok () => none
  | .error r => some r.error

-- Accepted: transfer, borrows, mutation and an explicit copy.
#guard verdict (prog [newRes "a" 1, newRes "b" 2,
  .expr (.call "bump" [use "a", use "b"]), .expr (.call "show" [use "a"]),
  .expr (.call "consume" [.transfer (v "a")]),
  .decl "p" (.struct "Pt") (some (.call "Pt" [.int 1, .int 2])),
  .decl "q" (.struct "Pt") (some (.copy (v "p"))),
  .print [.str "sum", .binary .add (.place (fld "p" "x")) (.place (fld "q" "y"))]]) == none

-- `consume(a^); print(a.id)`: a use after a transfer.
#guard verdict (prog [newRes "a" 1, .expr (.call "consume" [.transfer (v "a")]),
  .print [.place (fld "a" "id")]]) == some (.uninitializedUse (fld "a" "id"))

-- `var b = a` for a `Res`, which is not implicitly copyable.
#guard verdict (prog [newRes "a" 1, .decl "b" res (some (use "a"))]) == some (.implicitCopy res)

-- `consume(a)` copies `a` implicitly into a `var` parameter.
#guard verdict (prog [newRes "a" 1, .expr (.call "consume" [use "a"])]) ==
  some (.implicitCopy res)

-- `a.copy()` of a `Res`, which is not `Copyable`.
#guard verdict (prog [newRes "a" 1, .decl "b" res (some (.copy (v "a")))]) ==
  some (.notCopyable res)

-- `def take(r: Res): consume(r^)`: a transfer out of a `read` parameter.
#guard verdict (prog [] [⟨"take", [⟨.read, "r", res⟩], .noneType,
  [.expr (.call "consume" [.transfer (v "r")])], none⟩]) == some (.transferFromBorrowed (v "r"))

-- `def set(r: Res): r.id = 0`: an assignment through a `read` parameter.
#guard verdict (prog [] [⟨"set", [⟨.read, "r", res⟩], .noneType,
  [.assign (fld "r" "id") (.int 0)], none⟩]) == some (.immutablePlace (fld "r" "id"))

-- `bump(a, a)`: `a` passed `mut` and also as a location.
#guard verdict (prog [newRes "a" 1, .expr (.call "bump" [use "a", use "a"])]) ==
  some (.argumentExclusivity (v "a"))

-- `addInts(n, n)` is allowed: an `Int` is passed by copy.
#guard verdict (prog [.decl "n" .int (some (.int 1)),
  .expr (.call "addInts" [use "n", use "n"])]) == none

-- `bump(Res(1), a)`: a `mut` argument that is not a place.
#guard verdict (prog [newRes "a" 1, .expr (.call "bump" [.call "Res" [.int 1], use "a"])]) ==
  some (.notAPlace "bump")

-- `while c: consume(a^)`: a move in a loop of a value from before it, which
-- the next iteration would use uninitialized.
#guard verdict (prog [newRes "a" 1, .decl "c" .bool (some (.bool false)),
  .whileLoop (use "c") [.expr (.call "consume" [.transfer (v "a")])]]) ==
  some (.uninitializedUse (v "a"))

-- The same loop is accepted when the body initializes `a` again.
#guard verdict (prog [newRes "a" 1, .decl "c" .bool (some (.bool false)),
  .whileLoop (use "c") [.expr (.call "consume" [.transfer (v "a")]),
    .assign (v "a") (.call "Res" [.int 2])]]) == none

-- `if c: consume(a^)` then `show(a)`: `a` may have been moved.
#guard verdict (prog [newRes "a" 1, .decl "c" .bool (some (.bool true)),
  .ifElse (use "c") [.expr (.call "consume" [.transfer (v "a")])] [],
  .expr (.call "show" [use "a"])]) == some (.uninitializedUse (v "a"))

-- A branch that returns does not count: `a` is initialized after the `if`.
#guard verdict (prog [newRes "a" 1, .decl "c" .bool (some (.bool true)),
  .ifElse (use "c") [.expr (.call "consume" [.transfer (v "a")]), .ret none] [],
  .expr (.call "show" [use "a"])]) == none

-- Moving a field out of a `Pair` is allowed: the rest is destroyed field by field.
#guard verdict (prog [.decl "p" (.struct "Pair") (some (.call "Pair" [.call "Res" [.int 1],
  .call "Res" [.int 2]])), .expr (.call "consume" [.transfer (fld "p" "a")])]) == none

-- Moving `id` out of a `Res`, which has a `__deinit__`, is not.
#guard verdict (prog [newRes "a" 1, .decl "n" .int (some (.transfer (fld "a" "id")))]) ==
  some (.partiallyDestroyed "a")

-- In its own `__deinit__`, a struct may move its fields out.
#guard verdict (prog [] [] [⟨"Holder", [("r", res)], .none, true, none,
  some [.expr (.call "consume" [.transfer (fld "self" "r")])], []⟩]) == none

-- `__init__` must initialize every field of `self`.
#guard verdict (prog [] [] [⟨"Two", [("x", .int), ("y", .int)], .none, false,
  some ⟨"__init__", [⟨.out, "self", .struct "Two"⟩], .noneType,
    [.assign (fld "self" "x") (.int 1)], none⟩, none, []⟩]) == some (.uninitializedAtExit "self")

-- It may initialize them one by one.
#guard verdict (prog [.decl "t" (.struct "Two") (some (.call "Two" []))] []
  [⟨"Two", [("x", .int), ("y", .int)], .none, false,
  some ⟨"__init__", [⟨.out, "self", .struct "Two"⟩], .noneType,
    [.assign (fld "self" "x") (.int 1), .assign (fld "self" "y") (.int 2)], none⟩, none, []⟩]) == none

-- `def f() -> Int: pass`: a function with a result must return.
#guard verdict (prog [] [⟨"f", [], .int, [.pass], none⟩]) == some (.missingReturn "f")

-- Returning an owned local moves it; returning a `read` parameter copies it.
#guard verdict (prog [] [⟨"make", [], res, [newRes "r" 1, .ret (some (use "r"))], none⟩]) == none
#guard verdict (prog [] [⟨"same", [⟨.read, "r", res⟩], res, [.ret (some (use "r"))], none⟩]) ==
  some (.implicitCopy res)

-- Types: `1 + True`, `if 1:`, and `print(a)` of a struct.
#guard verdict (prog [.expr (.binary .add (.int 1) (.bool true))]) ==
  some (.typeMismatch .int .bool)
#guard verdict (prog [.ifElse (.int 1) [] []]) == some (.typeMismatch .bool .int)
#guard verdict (prog [newRes "a" 1, .print [use "a"]]) == some (.implicitCopy res)

-- Names: an unknown variable, a duplicate declaration, a declaration that would
-- hide an outer variable, and a name reused by sibling blocks.
#guard verdict (prog [.print [use "nope"]]) == some (.unknownVariable "nope")
#guard verdict (prog [.decl "x" .int (some (.int 1)), .decl "x" .int (some (.int 2))]) ==
  some (.duplicate "x")
#guard verdict (prog [.decl "x" .int (some (.int 1)),
  .ifElse (.bool true) [.decl "x" .bool (some (.bool true))] [], .print [use "x"]]) ==
  some (.duplicate "x")
#guard verdict (prog [.ifElse (.bool true) [.decl "x" .int (some (.int 1))]
  [.decl "x" .bool (some (.bool true))]]) == none

-- A struct that contains itself, and a program without `main`.
#guard verdict (prog [] [] [⟨"Loop", [("next", .struct "Loop")], .none, true, none, none, []⟩]) ==
  some (.recursiveStruct "Loop")
#guard verdict ⟨[], []⟩ == some .noMain

end MojoGrimoireTest.Check
