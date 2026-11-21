import MojoGrimoire.Check.Program
import MojoGrimoire.Elab.Elaborate

/-!
Tests of lists: the checker and elaboration on programs that build, index,
grow and pass lists. Each is written in Mojo in its comment. `Res` is a
struct with a destructor; `show` borrows one and `bump` takes one `mut`.
-/

namespace MojoGrimoireTest.Check.Lists

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Elab

private def v (x : Name) : Place := .var x
private def use (x : Name) : Expr := .place (v x)
private def res : Ty := .struct "Res"
private def at_ (x : Name) (i : Int) : Place := .index (v x) (.int i)
private def newRes (n : Int) : Expr := .call "Res" [.int n]

/-- `@fieldwise_init struct Res: var id: Int; def __deinit__(deinit self): print(self.id)` -/
private def resDecl : StructDecl :=
  ⟨"Res", [("id", .int)], .none, true, none,
    some [.print [.place (.field (v "self") "id")]], []⟩

private def lib : List FunDecl :=
  [⟨"show", [⟨.read, "r", res⟩], .noneType, [], none⟩,
   ⟨"bump", [⟨.mutable, "r", res⟩], .noneType, [], none⟩,
   ⟨"swapRes", [⟨.mutable, "a", res⟩, ⟨.mutable, "b", res⟩], .noneType, [], none⟩]

/-- A program whose `main` has the body `body`. -/
private def prog (body : List Stmt) : Program :=
  ⟨[resDecl], lib ++ [⟨"main", [], .noneType, body, none⟩]⟩

private def verdict (p : Program) : Option CheckError :=
  match checkProgram p with
  | .ok () => none
  | .error r => some r.error

private def ints : Stmt := .decl "xs" (.list .int) (some (.list (.list .int) [.int 1, .int 2]))
private def ress : Stmt := .decl "rs" (.list res) (some (.list (.list res) [newRes 1, newRes 2]))

-- `var xs = [1, 2]; xs.append(3); xs[0] = xs[1] + len(xs); print(xs[0])`
#guard verdict (prog [ints, .expr (.method (v "xs") "append" [.int 3]),
  .assign (at_ "xs" 0) (.binary .add (.place (at_ "xs" 1)) (.call "len" [use "xs"])),
  .print [.place (at_ "xs" 0)]]) == none

-- `var rs = [Res(1), Res(2)]; show(rs[0]); bump(rs[1]); print(rs[0].id)`
#guard verdict (prog [ress, .expr (.call "show" [.place (at_ "rs" 0)]),
  .expr (.call "bump" [.place (at_ "rs" 1)]),
  .print [.place (.field (at_ "rs" 0) "id")]]) == none

-- `print(xs[-1])` and `print(xs[1 - 2])`: a negative index that Mojo computes
-- when it compiles the program is rejected.
#guard verdict (prog [ints, .print [.place (at_ "xs" (-1))]]) ==
  some (.negativeIndex (at_ "xs" (-1)))
#guard verdict (prog [ints, .print [.place (.index (v "xs") (.binary .sub (.int 1) (.int 2)))]]) ==
  some (.negativeIndex (.index (v "xs") (.binary .sub (.int 1) (.int 2))))

-- `var i = -1; print(xs[i])`: an index known only at run time is not.
#guard verdict (prog [ints, .decl "i" .int (some (.int (-1))),
  .print [.place (.index (v "xs") (use "i"))]]) == none

-- `rs[0] = Res(3)`: an element is replaced in place.
#guard verdict (prog [ress, .assign (at_ "rs" 0) (newRes 3)]) == none

-- `var r = rs[0]^`: an element cannot be transferred out.
#guard verdict (prog [ress, .decl "r" res (some (.transfer (at_ "rs" 0)))]) ==
  some (.transferFromElement (at_ "rs" 0))

-- `var r = rs[0]`: a `Res` element is not implicitly copyable.
#guard verdict (prog [ress, .decl "r" res (some (.place (at_ "rs" 0)))]) ==
  some (.implicitCopy res)

-- `var ys = xs`: a list is copied only explicitly.
#guard verdict (prog [ints, .decl "ys" (.list .int) (some (use "xs"))]) ==
  some (.implicitCopy (.list .int))

-- `var ys = xs.copy()` is accepted, but a list of `Res` cannot be copied.
#guard verdict (prog [ints, .decl "ys" (.list .int) (some (.copy (v "xs")))]) == none
#guard verdict (prog [ress, .decl "ys" (.list res) (some (.copy (v "rs")))]) ==
  some (.notCopyable (.list res))

-- `xs[True]`: an index is an `Int`, and a list's `__getitem__` has
-- several overloads, none of which fits (#169).
#guard verdict (prog [ints, .print [.place (.index (v "xs") (.bool true))]]) ==
  some (.noMatchingMethod "__getitem__")

-- `swapRes(rs[0], rs[1])`: two `mut` elements of one list overlap.
#guard verdict (prog [ress, .expr (.call "swapRes" [.place (at_ "rs" 0), .place (at_ "rs" 1)])]) ==
  some (.argumentExclusivity (at_ "rs" 0))

-- `xs.insert(0, 1)`: only `append` and `pop` are modelled.
#guard verdict (prog [ints, .expr (.method (v "xs") "insert" [.int 0, .int 1])]) ==
  some (.unknownAttribute "List" "insert")

-- `var n = 1; n[0]`: an `Int` is its own one element (#127), and its index
-- is checked as an array's is.
#guard verdict (prog [.decl "n" .int (some (.int 1)), .print [.place (at_ "n" 0)]]) == none
#guard verdict (prog [.decl "n" .int (some (.int 1)), .print [.place (at_ "n" 1)]]) ==
  some (.constantIndexOutOfBounds (at_ "n" 1))

-- `var rs = [Res(1)]; rs.append(r^)` after `r` is moved in: `r` is not used again.
#guard verdict (prog [.decl "r" res (some (newRes 1)), ress,
  .expr (.method (v "rs") "append" [.transfer (v "r")]),
  .expr (.call "show" [use "r"])]) == some (.uninitializedUse (v "r"))

/-- The body of `main` once elaborated. -/
private def elabMain (body : List Stmt) : List Stmt :=
  (elabFun ⟨[resDecl], lib⟩ ⟨"main", [], .noneType, body, none⟩).body

-- `var i = 0; var rs = [Res(1)]; show(rs[i])`: `rs` dies after its last use;
-- `i` is an `Int`.
#guard
  let s := Stmt.expr (.call "show" [.place (.index (v "rs") (use "i"))])
  elabMain [.decl "i" .int (some (.int 0)), ress, s] ==
    [.decl "i" .int (some (.int 0)), ress, s, .drop (v "rs")]

-- `var r = Res(1); rs[0] = r^`: `r` is moved into the list and not dropped.
#guard
  let s := Stmt.assign (at_ "rs" 0) (.transfer (v "r"))
  elabMain [ress, .decl "r" res (some (newRes 3)), s] ==
    [ress, .decl "r" res (some (newRes 3)), s, .drop (v "rs")]

-- A list of `Int` is never dropped.
#guard elabMain [ints, .print [.place (at_ "xs" 0)]] == [ints, .print [.place (at_ "xs" 0)]]

end MojoGrimoireTest.Check.Lists
