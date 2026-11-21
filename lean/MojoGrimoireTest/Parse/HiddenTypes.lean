import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the types whose name a variable hides (#193). Inside its scope, a
variable or a parameter named `Int`, `Bool`, like a struct, or like any
name used as a type, makes that type a value where the compiler expects a
type: `valueAsType`, in a declaration, a parameter, a result, and inside
`List[…]` and `Array[…]`, also in `List[u]()` and `List[u](…)`.
-/

namespace MojoGrimoireTest.Parse.HiddenTypes

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

private def decls : List String := [
  "@fieldwise_init", "struct P(Copyable, Movable):", "    var x: Int",
  "def mk() -> P:", "    return P(4)"]

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

/-- Whether the program of `decls`, `pre` and the body `body` of `main` is
rejected with `e` in `d`. -/
private def rejectsIn (d : Name) (pre body : List String) (e : CheckError) : Bool :=
  runLines (decls ++ pre ++ inMain body) == some (.rejected ⟨d, e⟩)

private def rejects (body : List String) (e : CheckError) : Bool := rejectsIn "main" [] body e

/-- Whether the program of `decls`, `pre` and the body `body` of `main`
prints `out`. -/
private def prints (pre body : List String) (out : List String) : Bool :=
  runLines (decls ++ pre ++ inMain body) == some (.finished out)

-- The pass marks each name of a type that a variable in scope has, inside
-- lists and arrays too, but not `List`, `Array`, `None` or `Self`.
#guard Ty.markHidden ["Int"] (.list (.array .int 2)) == .list (.array (hiddenTy "Int") 2)
#guard Ty.markHidden ["P", "Bool"] (.list (.struct "P")) == .list (hiddenTy "P")
#guard Ty.markHidden ["Bool"] .bool == hiddenTy "Bool"
#guard Ty.markHidden ["List", "Array", "None", "Self"] (.list (.array (.struct "Self") 1)) ==
  .list (.array (.struct "Self") 1)
#guard Ty.markHidden ["None"] .noneType == .noneType
#guard Ty.markHidden ["Q"] (.struct "P") == .struct "P"
#guard (Ty.list (.array (hiddenTy "P") 3)).hidden == some "P"
#guard (Ty.list (.struct "P")).hidden == none

-- A variable hides a struct, `Int`, `Bool` or any other name in a type
-- annotation, also with no initializer.
#guard rejects ["var P = 5", "var q: P = mk()", "print(q.x, P)"] (.valueAsType "P")
#guard rejects ["var Int = 5", "var x: Int = 3", "print(x, Int)"] (.valueAsType "Int")
#guard rejects ["var Bool = 5", "var b: Bool = True", "print(b, Bool)"] (.valueAsType "Bool")
#guard rejects ["var Nope = 5", "var q: Nope = mk()", "print(q.x)"] (.valueAsType "Nope")
#guard rejects ["var P = 5", "var q: P", "q = mk()", "print(q.x, P)"] (.valueAsType "P")
-- Inside `List[…]` and `Array[…]`, at any depth.
#guard rejects ["var Int = 5", "var ys: List[Int] = [1, 2]", "print(len(ys))"] (.valueAsType "Int")
#guard rejects ["var Int = 5", "var a: Array[Int, 2] = [1, 2]", "print(a[0])"] (.valueAsType "Int")
#guard rejects ["var P = 5", "var a: Array[P, 1] = [mk()]", "print(a[0].x)"] (.valueAsType "P")
#guard rejects ["var Int = 5", "var a: List[List[Int]] = []", "print(len(a))"] (.valueAsType "Int")
-- In `List[u]()` and `List[u](…)`, wherever they stand, before the
-- arguments are checked.
#guard rejects ["var P = 5", "var ys = List[P]()", "print(len(ys), P)"] (.valueAsType "P")
#guard rejects ["var Int = 5", "var ys = List[Int]([1, 2])", "print(len(ys))"] (.valueAsType "Int")
#guard rejects ["var Int = 5", "var ys = List[Int](nope)", "print(len(ys))"] (.valueAsType "Int")
#guard rejects ["var Int = 5", "print(len(List[Int](range(3))))"] (.valueAsType "Int")
#guard rejects ["var P = 5", "print(len(List[P]()), P)"] (.valueAsType "P")
#guard rejects ["var P = 5", "var ys: List[Int] = []", "ys = List[P]()"] (.valueAsType "P")
#guard rejectsIn "main" ["def h(xs: List[P]) -> Int:", "    return len(xs)"]
  ["var P = 5", "print(h(List[P]()))"] (.valueAsType "P")
-- A variable of any type hides, bound with `ref`, uninitialized or moved
-- out too.
#guard rejects ["var P = mk()", "var q: P = mk()", "print(q.x)"] (.valueAsType "P")
#guard rejects ["var p = 5", "ref P = p", "var q: P = mk()", "print(q.x)"] (.valueAsType "P")
#guard rejects ["var P: Int", "var q: P = mk()", "print(q.x)"] (.valueAsType "P")
#guard rejects ["var P = 5", "var z = P^", "var q: P = mk()", "print(q.x, z)"] (.valueAsType "P")

-- A parameter hides the types of the parameters after it, the result and
-- the body, whatever its convention.
#guard rejectsIn "f" ["def f(P: Int, q: P):", "    print(P)"] ["f(5, mk())"] (.valueAsType "P")
#guard rejectsIn "f" ["def f(P: Int) -> P:", "    return mk()"] ["print(1)"] (.valueAsType "P")
#guard rejectsIn "g" ["def g(ref a: P, P: Int) -> ref[a] P:", "    return a"] ["print(1)"]
  (.valueAsType "P")
#guard rejectsIn "f" ["def f(mut P: Int):", "    var q: P = mk()", "    print(q.x)"] ["print(1)"]
  (.valueAsType "P")
#guard rejectsIn "f" ["def f(Int: Bool, x: Int):", "    print(x)"] ["f(True, 3)"]
  (.valueAsType "Int")
#guard rejectsIn "f" ["def f(Int: Bool) -> Int:", "    var xs = List[Int]()", "    return len(xs)"]
  ["print(f(True))"] (.valueAsType "Int")
-- But not an earlier parameter's type, nor its own.
#guard prints ["def f(q: P, P: Int):", "    print(q.x, P)"] ["f(mk(), 5)"] ["4 5"]
#guard prints ["def f(P: P) -> Int:", "    return P.x"] ["print(f(mk()))"] ["4"]
#guard prints ["def f(Int: Int):", "    print(Int)"] ["f(3)"] ["3"]

-- A variable hides from its declaration to the end of its block, not in its
-- own type, not before, and not in another function.
#guard prints [] ["var P: P = mk()", "print(P.x)"] ["4"]
#guard prints [] ["var Int: Int = 3", "print(Int)"] ["3"]
#guard prints [] ["var q: P = mk()", "var P = 5", "print(q.x, P)"] ["4 5"]
#guard prints [] ["if True:", "    var P = 5", "    print(P)", "var q: P = mk()", "print(q.x)"]
  ["5", "4"]
#guard prints ["def h(x: Int) -> Int:", "    var P = x", "    return P"]
  ["var q: P = mk()", "print(q.x, h(2))"] ["4 2"]
#guard rejects ["var P = 5", "if P > 3:", "    print(P)", "else:", "    var q: P = mk()"]
  (.valueAsType "P")
#guard rejects ["var n = 0", "while n < 1:", "    var P = 5", "    var q: P = mk()", "    n += 1"]
  (.valueAsType "P")
-- A literal's type is inferred, so no variable hides it; a field hides
-- nothing; `Self` is not hidden by a variable named like its struct.
#guard prints [] ["var P = 5", "var xs = [mk()]", "print(len(xs), P)"] ["1 5"]
#guard prints [] ["var Int = 5", "var x = 3", "print(x + Int)"] ["8"]
#guard runLines (decls ++ ["@fieldwise_init", "struct Q(Copyable, Movable):", "    var P: Int",
  "    var y: P"] ++ inMain ["var q = Q(1, mk())", "print(q.P, q.y.x)"]) == some (.finished ["1 4"])
#guard runLines (decls ++ ["@fieldwise_init", "struct Q(Copyable, Movable):", "    var x: Int",
  "    def m(self, Q: Int, o: Self) -> Int:", "        return o.x + Q"] ++
  inMain ["var a = Q(1)", "print(a.m(2, Q(3)))"]) == some (.finished ["5"])
-- Calling the variable still names its missing `__call__` (#176).
#guard rejects ["var P = 5", "var q = P(4)", "print(q.x)"] (.missingMethod .int "__call__")

-- The error comes in program order: after an earlier error, before the
-- declaration's own initializer and its reuse of a name.
#guard rejects ["print(zz)", "var P = 5", "var q: P = mk()"] (.unknownVariable "zz")
#guard rejects ["var P = 5", "var q: P = zz"] (.valueAsType "P")
#guard rejects ["var P = 5", "var P: P = mk()"] (.valueAsType "P")
-- Inside a struct's method, initializer or destructor, it comes after the
-- functions' bodies, before that struct's copyability check, and the
-- methods of later structs are not checked.
private def method (body : List String) : List String :=
  ["@fieldwise_init", "struct Q(Copyable, Movable):", "    var x: Int",
   "    def m(self, P: Int, q: P) -> Int:", "        return self.x"] ++ body
#guard rejectsIn "main" (method []) ["print(zz)"] (.unknownVariable "zz")
#guard rejectsIn "Q.m" (method ["    def n(self) -> Int:", "        return zz"]) ["print(1)"]
  (.valueAsType "P")
#guard rejectsIn "Q.m" (method ["@fieldwise_init", "struct R(Copyable, Movable):",
  "    var x: Int", "    def n(self) -> Int:", "        return zz"]) ["print(1)"]
  (.valueAsType "P")
#guard rejectsIn "R" (["@fieldwise_init", "struct R(ImplicitlyCopyable):", "    var xs: List[Int]"] ++
  method []) ["print(1)"] (.uncopyableField "R" "xs" (.list .int))
#guard rejectsIn "main" ["struct R(Movable):", "    var q: Int", "    def __init__(out self):",
  "        self.q = 1", "    def __deinit__(deinit self):", "        var P = 1",
  "        var z: P = mk()"] ["print(zz)"] (.unknownVariable "zz")

end MojoGrimoireTest.Parse.HiddenTypes
