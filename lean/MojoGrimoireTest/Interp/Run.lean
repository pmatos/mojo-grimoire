import MojoGrimoire.Interp.Run

/-!
Tests of the interpreter: small programs, run to the lines they print and
how they end. Each is written in Mojo in its comment. `Res` prints when it
is destroyed, which shows where elaboration put each destruction.
-/

namespace MojoGrimoireTest.Interp

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Interp

private def v (x : Name) : Place := .var x
private def fld (x f : Name) : Place := .field (.var x) f
private def use (x : Name) : Expr := .place (v x)
private def res : Ty := .struct "Res"
private def newRes (x : Name) (n : Int) : Stmt := .decl x res (some (.call "Res" [.int n]))
private def call (f : Name) (args : List Expr) : Stmt := .expr (.call f args)
private def say (s : String) : Stmt := .print [.str s]

/-- `@fieldwise_init struct Res: var id: Int;
def __deinit__(deinit self): print("drop", self.id)` -/
private def resDecl : StructDecl :=
  ⟨"Res", [("id", .int)], .none, true, none,
    some [.print [.str "drop", .place (fld "self" "id")]], []⟩

/-- `@fieldwise_init struct Pair: var a: Res; var b: Res`, with the
destructor body `deinit` when it is given. -/
private def pairDecl (deinit : Option (List Stmt)) : StructDecl :=
  ⟨"Pair", [("a", res), ("b", res)], .none, true, none, deinit, []⟩

/-- `struct Counter: var count: Int; def __init__(out self, start: Int):
self.count = start; def get(self) -> Int: return self.count` -/
private def counterDecl : StructDecl :=
  ⟨"Counter", [("count", .int)], .explicit, false,
    some ⟨"__init__", [⟨.out, "self", .struct "Counter"⟩, ⟨.read, "start", .int⟩], .noneType,
      [.assign (fld "self" "count") (use "start")], none⟩, none,
    [⟨"get", [⟨.read, "self", .struct "Counter"⟩], .int,
      [.ret (some (.place (fld "self" "count")))], none⟩]⟩

private def lib : List FunDecl :=
  [⟨"show", [⟨.read, "r", res⟩], .noneType, [.print [.place (fld "r" "id")]], none⟩,
   ⟨"consume", [⟨.owned, "r", res⟩], .noneType,
     [.print [.str "consumed", .place (fld "r" "id")]], none⟩,
   ⟨"bump", [⟨.mutable, "r", res⟩], .noneType,
     [.assign (fld "r" "id") (.binary .add (.place (fld "r" "id")) (.int 10))], none⟩,
   ⟨"make", [⟨.read, "n", .int⟩], res, [newRes "r" 0,
     .assign (fld "r" "id") (use "n"), .ret (some (use "r"))], none⟩,
   ⟨"pick", [⟨.ref, "a", res⟩, ⟨.ref, "b", res⟩, ⟨.read, "first", .bool⟩], res,
     [.ifElse (use "first") [.ret (some (use "a"))] [.ret (some (use "b"))]], some ["a", "b"]⟩,
   ⟨"bumpGet", [⟨.mutable, "r", res⟩], .int,
     [.assign (fld "r" "id") (.binary .add (.place (fld "r" "id")) (.int 10)),
      .ret (some (.int 0))], none⟩,
   ⟨"two", [⟨.read, "x", .int⟩, ⟨.read, "y", .int⟩], .noneType,
     [.print [use "x", use "y"]], none⟩]

/-- Runs a program whose `main` has the body `body`, where `Pair` has the
destructor body `pairDeinit`, if one is given. -/
private def go (body : List Stmt) (pairDeinit : Option (List Stmt) := none)
    (fuel : Nat := 10000) : Outcome :=
  run ⟨[resDecl, pairDecl pairDeinit, counterDecl],
    lib ++ [⟨"main", [], .noneType, body, none⟩]⟩ fuel

-- `print("hi", 1 + 2, True, 7 // -2, -7 % 3)`
#guard go [.print [.str "hi", .binary .add (.int 1) (.int 2), .bool true,
  .binary .floorDiv (.int 7) (.int (-2)), .binary .mod (.int (-7)) (.int 3)]] ==
  .finished ["hi 3 True -4 2"]

-- `var a = Res(1); var b = Res(2); print("x"); show(a); print("y")`: `b` is
-- never used and dies at once; `a` dies after its last use.
#guard go [newRes "a" 1, newRes "b" 2, say "x", call "show" [use "a"], say "y"] ==
  .finished ["drop 2", "x", "1", "drop 1", "y"]

-- `consume(a^)`: the callee owns `a` and destroys it.
#guard go [newRes "a" 1, call "consume" [.transfer (v "a")], say "end"] ==
  .finished ["consumed 1", "drop 1", "end"]

-- `bump(a); show(a)`: a `mut` argument is changed in place.
#guard go [newRes "a" 1, call "bump" [use "a"], call "show" [use "a"]] ==
  .finished ["11", "drop 11"]

-- `show(Res(4))`: a temporary passed to a borrowing parameter dies after the call.
#guard go [call "show" [.call "Res" [.int 4]], say "end"] == .finished ["4", "drop 4", "end"]

-- `var r = make(5); show(r)`: the returned value is moved out of the callee.
#guard go [.decl "r" res (some (.call "make" [.int 5])), call "show" [use "r"]] ==
  .finished ["5", "drop 5"]

-- `var p = Pair(Res(1), Res(2)); print("x")`: a struct without a destructor
-- has its fields destroyed in order.
#guard go [.decl "p" (.struct "Pair") (some (.call "Pair" [.call "Res" [.int 1],
  .call "Res" [.int 2]])), say "x"] == .finished ["drop 1", "drop 2", "x"]

-- The same with `def __deinit__(deinit self): show(self.b); print("pair")`:
-- `self.a` dies before the body, `self.b` after its last use.
#guard go [.decl "p" (.struct "Pair") (some (.call "Pair" [.call "Res" [.int 1],
  .call "Res" [.int 2]])), say "x"]
  (some [call "show" [.place (fld "self" "b")], say "pair"]) ==
  .finished ["drop 1", "2", "drop 2", "pair", "x"]

-- `var c = Counter(3); print(c.get())`: `__init__` initializes `out self`.
#guard go [.decl "c" (.struct "Counter") (some (.call "Counter" [.int 3])),
  .print [.method (v "c") "get" []]] == .finished ["3"]

-- `var i = 0; var s = 0; while i < 4: s = s + i; i = i + 1; print(s)`
#guard go [.decl "i" .int (some (.int 0)), .decl "s" .int (some (.int 0)),
  .whileLoop (.binary .lt (use "i") (.int 4))
    [.assign (v "s") (.binary .add (use "s") (use "i")),
     .assign (v "i") (.binary .add (use "i") (.int 1))],
  .print [use "s"]] == .finished ["6"]

-- `var xs: List[Int] = [1, 2]; xs.append(3); xs[0] = 9;
-- print(len(xs), xs[len(xs) - 1], xs[0])`
#guard go [.decl "xs" (.list .int) (some (.list .int [.int 1, .int 2])),
  .expr (.method (v "xs") "append" [.int 3]),
  .assign (.index (v "xs") (.int 0)) (.int 9),
  .print [.call "len" [use "xs"],
    .place (.index (v "xs") (.binary .sub (.call "len" [use "xs"]) (.int 1))),
    .place (.index (v "xs") (.int 0))]] == .finished ["3 3 9"]

-- `var i = -1; print(xs[i])`: a negative index known only at run time is out
-- of bounds.
#guard go [.decl "xs" (.list .int) (some (.list .int [.int 1])),
  .decl "i" .int (some (.int (-1))), say "x",
  .print [.place (.index (v "xs") (use "i"))]] == .failed .indexOutOfBounds ["x"]

-- `print(xs[5])` stops the run.
#guard go [.decl "xs" (.list .int) (some (.list .int [.int 1])), say "x",
  .print [.place (.index (v "xs") (.int 5))]] == .failed .indexOutOfBounds ["x"]

-- `var rs = [Res(1), Res(2)]; print("x")`: a list destroys its elements in order.
#guard go [.decl "rs" (.list res) (some (.list res [.call "Res" [.int 1], .call "Res" [.int 2]])),
  say "x"] == .finished ["drop 1", "drop 2", "x"]

-- `ref r = pick(a, b, False); bump(r); print("x"); show(b)`: `r` points into `b`,
-- and both values live until its last use.
#guard go [newRes "a" 1, newRes "b" 2,
  .refDecl "r" (.call "pick" [use "a", use "b", .bool false]),
  call "bump" [use "r"], say "x", call "show" [use "r"]] ==
  .finished ["x", "12", "drop 12", "drop 1"]

-- `two(a.id, bumpGet(a)); print(a.id + bumpGet(a), a.id)`: an operand that is
-- a place is read once every operand has been evaluated, so it sees the
-- change that a later operand makes.
#guard go [newRes "a" 1,
  call "two" [.place (fld "a" "id"), .call "bumpGet" [use "a"]],
  .print [.binary .add (.place (fld "a" "id")) (.call "bumpGet" [use "a"]),
    .place (fld "a" "id")]] == .finished ["11 0", "21 21", "drop 21"]

-- `print(9223372036854775807 + 1)`: `Int` wraps around.
#guard go [.print [.binary .add (.int 9223372036854775807) (.int 1)]] ==
  .finished ["-9223372036854775808"]

-- `print(1 // 0, -7 % 0)`: a zero divisor gives 0.
#guard go [.print [.binary .floorDiv (.int 1) (.int 0), .binary .mod (.int (-7)) (.int 0)]] ==
  .finished ["0 0"]

-- `while True: pass` runs out of fuel.
#guard go [.whileLoop (.bool true) [.pass]] (fuel := 100) == .failed .outOfFuel []

-- `consume(a^); show(a)` is rejected before it runs.
#guard go [newRes "a" 1, call "consume" [.transfer (v "a")], call "show" [use "a"]] ==
  .rejected ⟨"main", .uninitializedUse (v "a")⟩

end MojoGrimoireTest.Interp
