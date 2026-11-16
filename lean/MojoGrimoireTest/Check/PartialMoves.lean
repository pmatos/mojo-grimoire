import MojoGrimoire.Check.Program

/-!
Tests of the checker on fields moved out of a struct with `^`. Each program
is written in Mojo in its comment. The compiler accepts such a move only when
the program assigns that same field again before the struct ends or is
overwritten. A field of type `Int` or `Bool` is the exception: the compiler
does not move it.

The shared declarations are a resource `Res`, whose destructor prints, a
`Pair` of two of them, a `Box` that holds a `Pair` and an `Int`, a copyable
`Pt` of two `Int`s, and functions that take a `Res`.
-/

namespace MojoGrimoireTest.Check.PartialMoves

open MojoGrimoire.Core MojoGrimoire.Check

private def v (x : Name) : Place := .var x
private def fld (x f : Name) : Place := .field (.var x) f
private def fld2 (x f g : Name) : Place := .field (.field (.var x) f) g
private def res : Ty := .struct "Res"
private def pair : Ty := .struct "Pair"
private def newRes (n : Int) : Expr := .call "Res" [.int n]
private def newPair (a b : Int) : Expr := .call "Pair" [newRes a, newRes b]

/-- `@fieldwise_init struct Res: var id: Int; def __deinit__(deinit self): print("drop", self.id)` -/
private def resDecl : StructDecl :=
  ⟨"Res", [("id", .int)], .none, true, none,
    some [.print [.str "drop", .place (fld "self" "id")]], []⟩

/-- `@fieldwise_init struct Pair: var a: Res; var b: Res` -/
private def pairDecl : StructDecl := ⟨"Pair", [("a", res), ("b", res)], .none, true, none, none, []⟩

/-- `@fieldwise_init struct Box: var p: Pair; var n: Int` -/
private def boxDecl : StructDecl :=
  ⟨"Box", [("p", pair), ("n", .int)], .none, true, none, none, []⟩

/-- `@fieldwise_init struct Pt(Copyable): var x: Int; var y: Int` -/
private def ptDecl : StructDecl := ⟨"Pt", [("x", .int), ("y", .int)], .explicit, true, none, none, []⟩

/-- `def consume(var r: Res): print(r.id)` -/
private def consume : FunDecl := ⟨"consume", [⟨.owned, "r", res⟩], .noneType,
  [.print [.place (fld "r" "id")]], none⟩

/-- `def show(r: Res): print(r.id)` -/
private def showRes : FunDecl := ⟨"show", [⟨.read, "r", res⟩], .noneType,
  [.print [.place (fld "r" "id")]], none⟩

/-- A program with the shared declarations, extra functions `funs` and
structs `structs`, and a `main` whose body is `body`. -/
private def prog (body : List Stmt) (funs : List FunDecl := []) (structs : List StructDecl := []) :
    Program :=
  ⟨[resDecl, pairDecl, boxDecl, ptDecl] ++ structs,
    [consume, showRes] ++ funs ++ [⟨"main", [], .noneType, body, none⟩]⟩

/-- The class of error a program is rejected with, or `none` if it is
accepted. -/
private def verdict (p : Program) : Option CheckError :=
  match checkProgram p with
  | .ok () => none
  | .error r => some r.error

private def declPair (x : Name) : Stmt := .decl x pair (some (newPair 1 2))
private def moveOut (p : Place) : Stmt := .expr (.call "consume" [.transfer p])

-- `consume(p.a^)` and `p` ends: its field `a` is still moved out.
#guard verdict (prog [declPair "p", moveOut (fld "p" "a")]) == some (.partiallyDestroyed "p")

-- `consume(p.a^); show(p.b)`: using the other field does not end `p`.
#guard verdict (prog [declPair "p", moveOut (fld "p" "a"), .expr (.call "show" [.place (fld "p" "b")])]) ==
  some (.partiallyDestroyed "p")

-- `consume(p.a^); show(p.b); p.a = Res(3)`: the field is assigned again before
-- `p` ends, so using `p.b` in between is allowed.
#guard verdict (prog [declPair "p", moveOut (fld "p" "a"),
  .expr (.call "show" [.place (fld "p" "b")]), .assign (fld "p" "a") (newRes 3)]) == none

-- Moving every field out still leaves `p` with fields moved out.
#guard verdict (prog [declPair "p", moveOut (fld "p" "a"), moveOut (fld "p" "b")]) ==
  some (.partiallyDestroyed "p")
#guard verdict (prog [declPair "p", moveOut (fld "p" "a"), moveOut (fld "p" "b"),
  .assign (fld "p" "a") (newRes 3), .assign (fld "p" "b") (newRes 4)]) == none

-- `consume(p.a^); p = Pair(...)`: the assignment destroys the old value of `p`,
-- which has a field moved out.
#guard verdict (prog [declPair "p", moveOut (fld "p" "a"), .assign (v "p") (newPair 3 4)]) ==
  some (.partiallyDestroyed "p")

-- A field moved out of a nested struct: `b.p` may not be overwritten, nor may
-- `b` end, until `b.p.a` is assigned again.
#guard verdict (prog [.decl "b" (.struct "Box") (some (.call "Box" [newPair 1 2, .int 3])),
  moveOut (fld2 "b" "p" "a"), .assign (fld "b" "p") (newPair 3 4)]) == some (.partiallyDestroyed "b")
#guard verdict (prog [.decl "b" (.struct "Box") (some (.call "Box" [newPair 1 2, .int 3])),
  moveOut (fld2 "b" "p" "a"), .print [.place (fld "b" "n")],
  .assign (fld2 "b" "p" "a") (newRes 3)]) == none

-- `var q = b.p^; b.p.a = Res(3); b.p.b = Res(4)`: assigning each field of the
-- moved part does not count as assigning the part again.
#guard verdict (prog [.decl "b" (.struct "Box") (some (.call "Box" [newPair 1 2, .int 3])),
  .decl "q" pair (some (.transfer (fld "b" "p"))),
  .assign (fld2 "b" "p" "a") (newRes 3), .assign (fld2 "b" "p" "b") (newRes 4)]) ==
  some (.partiallyDestroyed "b")

-- After an `if`, the field is moved out unless both branches assign it again.
#guard verdict (prog [declPair "p", .decl "c" .bool (some (.bool true)), moveOut (fld "p" "a"),
  .ifElse (.place (v "c")) [.assign (fld "p" "a") (newRes 3)] []]) == some (.partiallyDestroyed "p")
#guard verdict (prog [declPair "p", .decl "c" .bool (some (.bool true)), moveOut (fld "p" "a"),
  .ifElse (.place (v "c")) [.assign (fld "p" "a") (newRes 3)] [.assign (fld "p" "a") (newRes 4)]]) ==
  none

-- A move in an inner block, with `p` used after the block.
#guard verdict (prog [declPair "p", .ifElse (.bool true) [moveOut (fld "p" "a")] [],
  .expr (.call "show" [.place (fld "p" "b")])]) == some (.partiallyDestroyed "p")

-- A loop that moves the field out and assigns it again.
#guard verdict (prog [declPair "p", .decl "c" .bool (some (.bool false)),
  .whileLoop (.place (v "c")) [moveOut (fld "p" "a"), .assign (fld "p" "a") (newRes 3)]]) == none

-- `def f(var p: Pair): consume(p.a^)`: an owned parameter ends like a local.
#guard verdict (prog [] [⟨"f", [⟨.owned, "p", pair⟩], .noneType, [moveOut (fld "p" "a")], none⟩]) ==
  some (.partiallyDestroyed "p")

-- `def f(mut p: Pair): var r = p.a^; show(p.b); p.a = r^`.
#guard verdict (prog [] [⟨"f", [⟨.mutable, "p", pair⟩], .noneType,
  [.decl "r" res (some (.transfer (fld "p" "a"))), .expr (.call "show" [.place (fld "p" "b")]),
   .assign (fld "p" "a") (.transfer (v "r"))], none⟩]) == none

-- In `__init__`, a field of the complete `self` may be moved out and assigned again.
#guard verdict (prog [] [] [⟨"Two", [("a", res), ("b", res)], .none, false,
  some ⟨"__init__", [⟨.out, "self", .struct "Two"⟩], .noneType,
    [.assign (fld "self" "a") (newRes 1), .assign (fld "self" "b") (newRes 2),
     .decl "r" res (some (.transfer (fld "self" "a"))),
     .expr (.call "show" [.place (fld "self" "b")]),
     .assign (fld "self" "a") (.transfer (v "r"))], none⟩, none, []⟩]) == none

-- In `__deinit__`, a field of `self` may stay moved out, but not a field of a field.
#guard verdict (prog [] [] [⟨"Holder", [("p", pair), ("r", res)], .none, true, none,
  some [moveOut (fld "self" "r")], []⟩]) == none
#guard verdict (prog [] [] [⟨"Holder", [("p", pair), ("r", res)], .none, true, none,
  some [moveOut (fld2 "self" "p" "a")], []⟩]) == some (.partiallyDestroyed "self")

-- `var n = p.x^` of an `Int` field: the compiler does not move it, and `p`
-- may end.
#guard verdict (prog [.decl "p" (.struct "Pt") (some (.call "Pt" [.int 1, .int 2])),
  .decl "n" .int (some (.transfer (fld "p" "x")))]) == none

end MojoGrimoireTest.Check.PartialMoves
