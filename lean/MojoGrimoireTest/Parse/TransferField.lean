import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a field or a method after a transfer, `p^.f` and `p^.m(…)` (#66).
The compiler warns that the transfer has no effect and reads the place `p`,
which it borrows: `p^.f` is the field `p.f`, and `p^.m(…)` a call on `p`.
`p` must be whole and a value that `p^` could transfer, nothing may change
through it, and a method that takes `var self` consumes `p`. Each expected
outcome is the compiler's. The programs are parsed from text, one line per
string, after the shared declarations.
-/

namespace MojoGrimoireTest.Parse.TransferField

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp
open MojoGrimoire.Elab

/-- The declarations every program starts with. -/
private def decls : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  "@fieldwise_init",
  "struct S(Movable):",
  "    var r: Res",
  "    var k: Int",
  "    def m(self) -> Int:",
  "        return self.k + 1",
  "    def bump(mut self):",
  "        self.k += 1",
  "    def take(var self) -> Int:",
  "        return self.k",
  "    def take2(var self, x: Int) -> Int:",
  "        return self.k + x",
  "    def take3(var self, o: S) -> Int:",
  "        return self.k + o.k",
  "@fieldwise_init",
  "struct T(Movable):",
  "    var s: S",
  "    var n: Int",
  "@fieldwise_init",
  "struct C(Copyable):",
  "    var k: Int",
  "def show(x: Int):",
  "    print(\"show\", x)",
  "def own(var x: Int):",
  "    print(\"own\", x)",
  "def inc(mut x: Int):",
  "    x += 1"]

/-- Parses the program whose lines are `ls`, after the declarations. -/
private def prog (ls : List String) : Option Program :=
  (parse ("\n".intercalate (decls ++ ls))).toOption

/-- Parses, checks and runs the program whose lines are `ls`. -/
private def go (ls : List String) : Option Outcome := (prog ls).map (run · 100000)

/-- Parses a `main` whose body is the lines `ls`, and runs it. -/
private def inMain (ls : List String) : Option Outcome := go ("def main():" :: ls)

/-- The rejection of `main` with the error `e`. -/
private def rejects (e : CheckError) : Option Outcome := some (.rejected ⟨"main", e⟩)

/-- The body of `main` as parsed from the lines `ls`. -/
private def mainBody (ls : List String) : Option (List Stmt) :=
  (prog ("def main():" :: ls)).bind fun p => (findFun p "main").map (·.body)

/-- Whether elaborating `main`, whose body is the lines `ls`, inserts no
drop anywhere in it. -/
private def elabSame (ls : List String) : Bool :=
  match prog ("def main():" :: ls) with
  | some p =>
    let body (q : Program) := (findFun q "main").map (·.body)
    body (elabProgram p) == body p && (body p).isSome
  | none => false

private def s : Place := .var "s"
private def sT : Place := .transferred s

-- The parser reads `s^.f` as the field of the place `s^`, with or without a
-- space, and goes on along the chain.
#guard mainBody ["    var s = S(Res(1), 7)", "    print(s^.k, s^ .k)"] ==
  some [.decl "s" (.struct "S") (some (.call "S" [.call "Res" [.int 1], .int 7])),
    .print [.place (.field sT "k"), .place (.field sT "k")]]
#guard mainBody ["    var s = S(Res(1), 7)", "    var a = s^.m()", "    var b = s^.r^",
    "    var c = s^.r.id"] ==
  some [.decl "s" (.struct "S") (some (.call "S" [.call "Res" [.int 1], .int 7])),
    .decl "a" .int (some (.method sT "m" [])),
    .decl "b" (.struct "Res") (some (.transfer (.field sT "r"))),
    .decl "c" .int (some (.place (.field (.field sT "r") "id")))]
#guard mainBody ["    var c = C(7)", "    var d = c^.copy()"] ==
  some [.decl "c" (.struct "C") (some (.call "C" [.int 7])),
    .decl "d" (.struct "C") (some (.copy (.transferred (.var "c"))))]
#guard mainBody ["    var t = T(S(Res(1), 7), 3)", "    print(t.s^.k)"] ==
  some [.decl "t" (.struct "T")
      (some (.call "T" [.call "S" [.call "Res" [.int 1], .int 7], .int 3])),
    .print [.place (.field (.transferred (.field (.var "t") "s")) "k")]]

-- `s^.k` reads `s.k` and leaves `s` whole; `s` is destroyed after its last
-- use, which is `s^.k`.
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s^.k", "    print(\"after\", y)"] ==
  some (.finished ["drop 1", "after 7"])
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s^.k", "    print(y, s.k)"] ==
  some (.finished ["7 7", "drop 1"])
#guard inMain ["    var s = S(Res(1), 7)", "    var z = s^.k + s^.k", "    print(z)"] ==
  some (.finished ["drop 1", "14"])

-- A `mut` parameter may be read through `s^`, and keeps its value.
#guard go ["def g(mut s: S) -> Int:", "    return s^.k", "def main():",
    "    var s = S(Res(1), 7)", "    print(g(s))", "    print(s.k)"] ==
  some (.finished ["7", "7", "drop 1"])

-- Nested fields, and a field of a field as the base.
#guard inMain ["    var t = T(S(Res(1), 7), 3)", "    print(t^.s.k)", "    print(t^.s.r.id)",
    "    print(t.n)"] == some (.finished ["7", "1", "3", "drop 1"])
#guard inMain ["    var t = T(S(Res(1), 7), 3)", "    print(t.s^.k)", "    print(t.n)"] ==
  some (.finished ["7", "3", "drop 1"])

-- `s^.k` passed `read` or `var`, and a `ref` binding to it, which may change
-- `s.k`, as the compiler allows.
#guard inMain ["    var s = S(Res(1), 7)", "    show(s^.k)", "    own(s^.k)", "    print(s.k)"] ==
  some (.finished ["show 7", "own 7", "7", "drop 1"])
#guard inMain ["    var s = S(Res(1), 7)", "    ref q = s^.k", "    q = 9", "    print(s.k)"] ==
  some (.finished ["9", "drop 1"])

-- A method whose `self` is `read` borrows `s`, on `s^` or on a field of it.
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.m())", "    print(s.k)"] ==
  some (.finished ["8", "7", "drop 1"])
#guard inMain ["    var t = T(S(Res(1), 7), 3)", "    print(t^.s.m())", "    print(t.n)"] ==
  some (.finished ["8", "3", "drop 1"])

-- `.copy()` copies a `Copyable` value and leaves it.
#guard inMain ["    var c = C(7)", "    var d = c^.copy()", "    print(d.k, c.k)"] ==
  some (.finished ["7 7"])

-- `s^.r^` moves the field `s.r`, which may be given back.
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s^.r^", "    s.r = Res(2)",
    "    print(\"after\", y.id, s.r.id)"] ==
  some (.finished ["after 1 2", "drop 1", "drop 2"])

-- A method whose `self` is `var` consumes `s`, once the arguments are read,
-- and nothing destroys `s` after it: the method does.
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.take())"] ==
  some (.finished ["drop 1", "7"])
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.take2(s.k))"] ==
  some (.finished ["drop 1", "14"])
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.take2(s^.k))"] ==
  some (.finished ["drop 1", "14"])
#guard elabSame ["    var s = S(Res(1), 7)", "    print(s^.take())"]
#guard elabSame ["    var s = S(Res(1), 7)", "    print(s^.take2(s.k))"]

-- What the compiler rejects. Using `s` after it was consumed, or reading
-- `s^.k` once `s` or a part of it was moved.
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.take())", "    print(s.k)"] ==
  rejects (.uninitializedUse (.field s "k"))
#guard inMain ["    var s = S(Res(1), 7)", "    var t = s^", "    print(s^.k)"] ==
  rejects (.uninitializedUse s)
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s.r^", "    print(s^.k)",
    "    s.r = y^"] == rejects (.uninitializedUse s)

-- Changing anything through `s^`: assigning, `+=`, passing it `mut`, or
-- calling a method whose `self` is `mut`.
#guard inMain ["    var s = S(Res(1), 7)", "    s^.k = 5"] ==
  rejects (.immutablePlace (.field sT "k"))
#guard inMain ["    var s = S(Res(1), 7)", "    s^.k += 1"] ==
  rejects (.immutablePlace (.field sT "k"))
#guard inMain ["    var s = S(Res(1), 7)", "    inc(s^.k)"] ==
  rejects (.immutablePlace (.field sT "k"))
#guard inMain ["    var s = S(Res(1), 7)", "    s^.bump()"] == rejects (.immutablePlace sT)
#guard inMain ["    var t = T(S(Res(1), 7), 3)", "    t^.s.bump()"] ==
  rejects (.immutablePlace (.field (.transferred (.var "t")) "s"))
-- For `xs^.pop()` the compiler finds no `pop` that applies, with the note that
-- the mutating method is used on an rvalue.
#guard inMain ["    var xs: List[Int] = [1, 2]", "    print(xs^.pop())"] ==
  rejects (.immutablePlace (.transferred (.var "xs")))

-- A field read through `s^` is copied implicitly, so it must be implicitly
-- copyable, and so is a receiver below `s^` taken by `var self`.
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s^.r"] ==
  rejects (.implicitCopy (.struct "Res"))
#guard inMain ["    var t = T(S(Res(1), 7), 3)", "    print(t^.s.take())"] ==
  rejects (.implicitCopy (.struct "S"))

-- `s^` must be a value that could be transferred: not a `read` or `ref`
-- parameter, and not an element of a list.
#guard go ["def g(s: S) -> Int:", "    return s^.k", "def main():", "    var s = S(Res(1), 7)",
    "    print(g(s))"] == some (.rejected ⟨"g", .transferFromBorrowed s⟩)
#guard go ["def g(ref s: S) -> Int:", "    return s^.k", "def main():",
    "    var s = S(Res(1), 7)", "    print(g(s))"] ==
  some (.rejected ⟨"g", .transferFromBorrowed s⟩)
#guard inMain ["    var xs: List[S] = [S(Res(1), 7)]", "    print(xs[0]^.k)"] ==
  rejects (.transferFromElement (.index (.var "xs") (.int 0)))

-- A consumed receiver is passed as if `mut`, so it may not alias a borrowed
-- argument; a consumed `mut` parameter is left uninitialized at its return.
#guard inMain ["    var s = S(Res(1), 7)", "    print(s^.take3(s))"] ==
  rejects (.argumentExclusivity s)
#guard go ["def g(mut s: S) -> Int:", "    return s^.take()", "def main():",
    "    var s = S(Res(1), 7)", "    print(g(s))"] ==
  some (.rejected ⟨"g", .uninitializedAtExit "s"⟩)

-- A struct whose field was moved out through `s^` cannot be destroyed.
#guard inMain ["    var s = S(Res(1), 7)", "    var y = s^.r^", "    print(\"after\", y.id)"] ==
  rejects (.partiallyDestroyed "s")

end MojoGrimoireTest.Parse.TransferField
