import MojoGrimoire.Check.Program
import MojoGrimoire.Elab.Elaborate

/-!
Tests of references: `ref` bindings and functions that return a reference
with an origin, in the checker and in elaboration. Each is written in Mojo
in its comment. `Res` is a struct with a destructor, and `Box` holds one.
-/

namespace MojoGrimoireTest.Check.Refs

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Elab

private def v (x : Name) : Place := .var x
private def use (x : Name) : Expr := .place (v x)
private def res : Ty := .struct "Res"
private def newRes (x : Name) (n : Int) : Stmt := .decl x res (some (.call "Res" [.int n]))
private def call (f : Name) (args : List Expr) : Stmt := .expr (.call f args)
private def say (s : String) : Stmt := .print [.str s]

/-- `@fieldwise_init struct Res: var id: Int; def __deinit__(deinit self): print(self.id)` -/
private def resDecl : StructDecl :=
  ⟨"Res", [("id", .int)], .none, true, none,
    some [.print [.place (.field (v "self") "id")]], []⟩

/-- `@fieldwise_init struct Box: var r: Res; def get(ref self) -> ref [self] Res: return self.r` -/
private def boxDecl : StructDecl :=
  ⟨"Box", [("r", res)], .none, true, none, none,
    [⟨"get", [⟨.ref, "self", .struct "Box"⟩], res,
      [.ret (some (.place (.field (v "self") "r")))], some ["self"]⟩]⟩

/-- `def pick(ref a: Res, ref b: Res, first: Bool) -> ref [a, b] Res:
if first: return a else: return b` -/
private def pick : FunDecl :=
  ⟨"pick", [⟨.ref, "a", res⟩, ⟨.ref, "b", res⟩, ⟨.read, "first", .bool⟩], res,
    [.ifElse (use "first") [.ret (some (use "a"))] [.ret (some (use "b"))]], some ["a", "b"]⟩

/-- `def left(ref a: Res, ref b: Res) -> ref [a] Res: return a` -/
private def left : FunDecl :=
  ⟨"left", [⟨.ref, "a", res⟩, ⟨.ref, "b", res⟩], res, [.ret (some (use "a"))], some ["a"]⟩

/-- `def look(a: Res) -> ref [a] Res: return a` -/
private def look : FunDecl :=
  ⟨"look", [⟨.read, "a", res⟩], res, [.ret (some (use "a"))], some ["a"]⟩

/-- `def bigger(ref a: Int, ref b: Int) -> ref [a, b] Int` -/
private def bigger : FunDecl :=
  ⟨"bigger", [⟨.ref, "a", .int⟩, ⟨.ref, "b", .int⟩], .int,
    [.ifElse (.binary .gt (use "a") (use "b")) [.ret (some (use "a"))] [.ret (some (use "b"))]],
    some ["a", "b"]⟩

private def lib : List FunDecl :=
  [⟨"show", [⟨.read, "r", res⟩], .noneType, [], none⟩,
   ⟨"bump", [⟨.mutable, "r", res⟩], .noneType, [], none⟩,
   ⟨"consume", [⟨.owned, "r", res⟩], .noneType, [], none⟩,
   ⟨"swapRes", [⟨.mutable, "a", res⟩, ⟨.mutable, "b", res⟩], .noneType, [], none⟩,
   pick, left, look, bigger]

/-- The program with the extra functions `funs` and a `main` whose body is
`body`. -/
private def prog (body : List Stmt) (funs : List FunDecl := []) : Program :=
  ⟨[resDecl, boxDecl], lib ++ funs ++ [⟨"main", [], .noneType, body, none⟩]⟩

private def verdict (p : Program) : Option CheckError :=
  match checkProgram p with
  | .ok () => none
  | .error r => some r.error

private def ab : List Stmt := [newRes "a" 1, newRes "b" 2]
private def pickAB : Expr := .call "pick" [use "a", use "b", .bool true]

-- The declarations above are accepted, and so is `ref r = a; show(r)`.
#guard verdict (prog (ab ++ [.refDecl "r" (use "a"), call "show" [use "r"]])) == none

-- `ref r = pick(a, b, True); bump(r)`: both `ref` arguments may be changed.
#guard verdict (prog (ab ++ [.refDecl "r" pickAB, call "bump" [use "r"]])) == none

-- `ref r = a; r = Res(5)` writes through the reference.
#guard verdict (prog (ab ++ [.refDecl "r" (use "a"), .assign (v "r") (.call "Res" [.int 5])])) ==
  none

-- `ref r = look(a); bump(r)`: a reference through a `read` parameter is immutable.
#guard verdict (prog (ab ++ [.refDecl "r" (.call "look" [use "a"]), call "bump" [use "r"]])) ==
  some (.immutablePlace (v "r"))

-- `ref r = a; consume(a^); show(r)`: `a` is gone when `r` is used.
#guard verdict (prog (ab ++ [.refDecl "r" (use "a"), call "consume" [.transfer (v "a")],
  call "show" [use "r"]])) == some (.uninitializedUse (v "a"))

-- `ref r = a; consume(r^)`: a value cannot be moved out through a reference.
#guard verdict (prog (ab ++ [.refDecl "r" (use "a"), call "consume" [.transfer (v "r")]])) ==
  some (.transferFromBorrowed (v "r"))

-- `ref r = a; swapRes(r, a)`: `r` and `a` are the same location.
#guard verdict (prog (ab ++ [.refDecl "r" (use "a"), call "swapRes" [use "r", use "a"]])) ==
  some (.argumentExclusivity (v "r"))

-- `ref r = Res(1)`: a value is not a location.
#guard verdict (prog [.refDecl "r" (.call "Res" [.int 1])]) == some .notAReference

-- `ref r = pick(Res(1), b, True)`: an origin argument must be a place.
#guard verdict (prog (ab ++ [.refDecl "r" (.call "pick" [.call "Res" [.int 1], use "b",
  .bool true])])) == some (.notAPlace "pick")

-- `var c = pick(a, b, True)`: reading the reference copies a `Res` implicitly.
#guard verdict (prog (ab ++ [.decl "c" res (some pickAB)])) == some (.implicitCopy res)

-- `var n = bigger(i, j)` copies the `Int` it points to.
#guard verdict (prog [.decl "i" .int (some (.int 1)), .decl "j" .int (some (.int 2)),
  .decl "n" .int (some (.call "bigger" [use "i", use "j"])), .print [use "n"]]) == none

-- `def wrong(ref a: Res, ref b: Res) -> ref [a] Res: return b`
#guard verdict (prog [] [⟨"wrong", [⟨.ref, "a", res⟩, ⟨.ref, "b", res⟩], res,
  [.ret (some (use "b"))], some ["a"]⟩]) == some (.escapingReference "wrong")

-- `def owned(var a: Res) -> ref [a] Res`: a `var` parameter dies with the call.
#guard verdict (prog [] [⟨"owned", [⟨.owned, "a", res⟩], res,
  [.ret (some (use "a"))], some ["a"]⟩]) == some (.invalidOrigin "owned")

/-- The body of `main` once elaborated. -/
private def elabMain (body : List Stmt) : List Stmt :=
  (elabFun (prog body) ⟨"main", [], .noneType, body, none⟩).body

-- `ref r = pick(a, b, True); print("x"); show(r)`: `a` and `b` live until the
-- last use of `r`.
#guard elabMain (ab ++ [.refDecl "r" pickAB, say "x", call "show" [use "r"]]) ==
  ab ++ [.refDecl "r" pickAB, say "x", call "show" [use "r"], .drop (v "a"), .drop (v "b")]

-- `ref r = left(a, b)`: only `a` is in the origin, so `b` dies at once.
#guard
  let lr := Expr.call "left" [use "a", use "b"]
  elabMain (ab ++ [.refDecl "r" lr, say "x", call "show" [use "r"]]) ==
    ab ++ [.refDecl "r" lr, .drop (v "b"), say "x", call "show" [use "r"], .drop (v "a")]

-- `var bx = Box(Res(1)); ref r = bx.get(); print("x"); show(r)`: the box
-- lives as long as the reference into it.
#guard
  let bx := Stmt.decl "bx" (.struct "Box") (some (.call "Box" [.call "Res" [.int 1]]))
  let get := Stmt.refDecl "r" (.method (v "bx") "get" [])
  elabMain [bx, get, say "x", call "show" [use "r"]] ==
    [bx, get, say "x", call "show" [use "r"], .drop (v "bx")]

end MojoGrimoireTest.Check.Refs
