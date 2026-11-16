import MojoGrimoire.Elab.Strip

/-!
Tests of ASAP elaboration: small bodies, each with the drops that Mojo's
destruction points put in it. Each is written in Mojo in its comment. `Res`
is a struct with a destructor, `Pair` holds two of them, and `show` and
`consume` borrow and take a `Res`.
-/

namespace MojoGrimoireTest.Elab

open MojoGrimoire.Core MojoGrimoire.Elab

private def v (x : Name) : Place := .var x
private def fld (x f : Name) : Place := .field (.var x) f
private def res : Ty := .struct "Res"
private def newRes (x : Name) (n : Int) : Stmt := .decl x res (some (.call "Res" [.int n]))
private def showS (p : Place) : Stmt := .expr (.call "show" [.place p])
private def consumeS (x : Name) : Stmt := .expr (.call "consume" [.transfer (v x)])
private def say (s : String) : Stmt := .print [.str s]

/-- A function body, elaborated with the `var` parameters `params`. -/
private def body (b : List Stmt) (params : List Param := []) : List Stmt :=
  (elabFun ⟨[], []⟩ ⟨"f", params, .noneType, b, none⟩).body

-- `var a = Res(1); print("x")`: `a` is never used, so it dies at once.
#guard body [newRes "a" 1, say "x"] == [newRes "a" 1, .drop (v "a"), say "x"]

-- `var a = Res(1); var b = Res(2); show(a); show(b)`: each dies after its
-- last use.
#guard body [newRes "a" 1, newRes "b" 2, showS (v "a"), showS (v "b")] ==
  [newRes "a" 1, newRes "b" 2, showS (v "a"), .drop (v "a"), showS (v "b"), .drop (v "b")]

-- `both(b, a)` after both: they die together, the last declared first.
#guard body [newRes "a" 1, newRes "b" 2,
    .expr (.call "both" [.place (v "b"), .place (v "a")])] ==
  [newRes "a" 1, newRes "b" 2, .expr (.call "both" [.place (v "b"), .place (v "a")]),
    .drop (v "b"), .drop (v "a")]

-- `consume(a^)`: a moved value is not destroyed here.
#guard body [newRes "a" 1, consumeS "a"] == [newRes "a" 1, consumeS "a"]

-- `a = Res(2)` before any use: the first value dies at its declaration, the
-- second after its last use.
#guard body [newRes "a" 1, .assign (v "a") (.call "Res" [.int 2]), showS (v "a")] ==
  [newRes "a" 1, .drop (v "a"), .assign (v "a") (.call "Res" [.int 2]), showS (v "a"),
    .drop (v "a")]

-- `a = f(a^)`, then nothing: the new value dies at once.
#guard body [newRes "a" 1, .assign (v "a") (.call "f" [.transfer (v "a")])] ==
  [newRes "a" 1, .assign (v "a") (.call "f" [.transfer (v "a")]), .drop (v "a")]

-- `a = f(g(a))`, then nothing: `g` destroys the old value once it is done,
-- and the new value still dies at once (#92).
#guard body [newRes "a" 1, .assign (v "a") (.call "f" [.call "g" [.place (v "a")]])] ==
  [newRes "a" 1,
    .assign (v "a") (.call "f" [.withDrops (.call "g" [.place (v "a")]) [] [v "a"]]),
    .drop (v "a")]

-- `if c: consume(a^) else: print("no")`: the branch that does not use `a`
-- destroys it first.
#guard body [newRes "a" 1, .ifElse (.bool true) [consumeS "a"] [say "no"]] ==
  [newRes "a" 1, .ifElse (.bool true) [consumeS "a"] [.drop (v "a"), say "no"]]

-- `if a.id > 0: print("pos") else: print("neg")`: `a` dies inside the test,
-- once `>` has read `a.id`.
#guard body [newRes "a" 1,
    .ifElse (.binary .gt (.place (fld "a" "id")) (.int 0)) [say "pos"] [say "neg"]] ==
  [newRes "a" 1,
    .ifElse (.withDrops (.binary .gt (.place (fld "a" "id")) (.int 0)) [v "a"] [])
      [say "pos"] [say "neg"]]

-- `if show(a): print("pos")`: a value used by reference in the test dies at
-- the start of each branch.
#guard body [newRes "a" 1, .ifElse (.call "show" [.place (v "a")]) [say "pos"] []] ==
  [newRes "a" 1, .ifElse (.call "show" [.place (v "a")]) [.drop (v "a"), say "pos"]
    [.drop (v "a")]]

-- `print(show(a), b.id)`: `a` dies once `show` returns, before `print`, and
-- `b` once `print` is done.
#guard body [newRes "a" 1, newRes "b" 2,
    .print [.call "show" [.place (v "a")], .place (fld "b" "id")]] ==
  [newRes "a" 1, newRes "b" 2,
    .print [.withDrops (.call "show" [.place (v "a")]) [] [v "a"], .place (fld "b" "id")],
    .drop (v "b")]

-- `while i < 3: show(a); i = i + 1`, then `print(i)`: `a` lives through the
-- loop and dies after it; `i` is an `Int` and is never dropped.
#guard
  let loop := Stmt.whileLoop (.binary .lt (.place (v "i")) (.int 3))
    [showS (v "a"), .assign (v "i") (.binary .add (.place (v "i")) (.int 1))]
  body [newRes "a" 1, .decl "i" .int (some (.int 0)), loop, .print [.place (v "i")]] ==
    [newRes "a" 1, .decl "i" .int (some (.int 0)), loop, .drop (v "a"),
      .print [.place (v "i")]]

-- `while ...: var t = Res(i); show(t)`: a value declared in the loop dies in
-- the same iteration.
#guard
  let c := Expr.binary .lt (.place (v "i")) (.int 3)
  body [.decl "i" .int (some (.int 0)), .whileLoop c [newRes "t" 0, showS (v "t")]] ==
    [.decl "i" .int (some (.int 0)), .whileLoop c [newRes "t" 0, showS (v "t"), .drop (v "t")]]

-- `def f(var r: Res, var s: Res, t: Res): show(s)`: `r` is never used and
-- dies on entry; `t` is borrowed and never dropped.
#guard body [showS (v "s")] [⟨.owned, "r", res⟩, ⟨.owned, "s", res⟩, ⟨.read, "t", res⟩] ==
  [.drop (v "r"), showS (v "s"), .drop (v "s")]

-- `return a.id`: no drop is inserted, since returning destroys what remains.
#guard body [newRes "a" 1, .ret (some (.place (fld "a" "id")))] ==
  [newRes "a" 1, .ret (some (.place (fld "a" "id")))]

/-- `struct Pair: var a: Res; var b: Res; var n: Int` with the destructor
body `deinit`. -/
private def pair (deinit : List Stmt) : StructDecl :=
  ⟨"Pair", [("a", res), ("b", res), ("n", .int)], .none, true, none, some deinit, []⟩

private def deinitOf (sd : StructDecl) : Option (List Stmt) := (elabStruct ⟨[sd], []⟩ sd).deinit

-- `__deinit__`: `print(self.b.id)`. `self.a` is never used and is destroyed
-- before the body; `self.b` after its last use.
#guard deinitOf (pair [.print [.place (.field (fld "self" "b") "id")]]) ==
  some [.drop (fld "self" "a"), .print [.place (.field (fld "self" "b") "id")],
    .drop (fld "self" "b")]

-- `__deinit__`: `show(self.a); print("mid"); show(self.b)`: each field dies
-- after its own last use, not all at the end.
#guard deinitOf (pair [showS (fld "self" "a"), say "mid", showS (fld "self" "b")]) ==
  some [showS (fld "self" "a"), .drop (fld "self" "a"), say "mid", showS (fld "self" "b"),
    .drop (fld "self" "b")]

-- `__deinit__`: `consume(self.a^)`: a field moved away is not destroyed.
#guard deinitOf (pair [.expr (.call "consume" [.transfer (fld "self" "a")])]) ==
  some [.drop (fld "self" "b"), .expr (.call "consume" [.transfer (fld "self" "a")])]

-- Erasing the drops of an elaborated body gives the body back.
#guard
  let b := [newRes "a" 1, .ifElse (.bool true) [consumeS "a"] [say "no"]]
  stripBlock (body b) == b

end MojoGrimoireTest.Elab
