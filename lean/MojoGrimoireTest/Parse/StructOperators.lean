import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the operators, `and`, `or` and calls on a struct value, which call
the methods that the struct declares (#191, `MojoGrimoire.Parse.Dispatch`):
which method inference calls, and what running the program gives. Each
verdict is the pinned compiler's for the program, probed on the nightly
1.3.0.dev2026111905.
-/

namespace MojoGrimoireTest.Parse.StructOperators

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- A struct `T` with a field `n` and the methods `ms`, each given by its
lines, then `main`, whose body is `body`. -/
private def withT (ms : List (List String)) (body : List String) : List String :=
  ["@fieldwise_init", "struct T(Copyable):", "    var n: Int"] ++
    ms.flatMap (·.map ("    " ++ ·)) ++ ["def main():"] ++ body.map ("    " ++ ·)

private def prints (ms : List (List String)) (body : List String) (out : List String) : Bool :=
  runLines (withT ms body) == some (.finished out)

private def rejects (ms : List (List String)) (body : List String) (e : CheckError) : Bool :=
  runLines (withT ms body) == some (.rejected ⟨"main", e⟩)

/-- The method `name` of `T` with the parameters `ps` after `self`, the
result `r` and the one line `ret` of its body. -/
private def m (name ps r ret : String) : List String :=
  [s!"def {name}(self{ps}) -> {r}:", s!"    return {ret}"]

-- The callees that inference makes.
#guard calleeMethod (methodCallee "T" "__add__") == some ("T", "__add__", false)
#guard calleeMethod (methodCallee "T" "__radd__" true) == some ("T", "__radd__", true)
#guard calleeMethod "len" == none
#guard inPlaceCallee (methodCallee "T" "__iadd__") && !inPlaceCallee (methodCallee "T" "__add__")

-- Inference calls the method of the left operand's struct, with the
-- operand read by reference.
#guard (parse "@fieldwise_init\nstruct T(Copyable):\n    var n: Int\n    def __add__(self, k: Int) -> Int:\n        return 1\ndef main():\n    var t = T(1)\n    print(t + 1)").toOption.map
    (fun p => (p.funs.head?.map (·.body)) == some [.decl "t" (.struct "T") (some (.call "T" [.int 1])),
      .print [.call "T.__add__" [.place (.var "t"), .int 1]]]) == some true

-- Forward, reflected and in-place operators.
#guard prints [m "__add__" ", k: Int" "Int" "self.n + k"] ["var t = T(1)", "print(t + 1)"] ["2"]
#guard prints [m "__radd__" ", k: Int" "Int" "self.n * 100 + k"] ["var t = T(1)", "print(1 + t)"]
  ["101"]
#guard prints [m "__radd__" ", o: Self" "Int" "7"] ["var t = T(1)", "var u = T(2)", "print(t + u)"]
  ["7"]
#guard prints [m "__add__" ", k: Int" "Int" "1", m "__radd__" ", o: Self" "Int" "7"]
  ["var t = T(1)", "var u = T(2)", "print(t + u)"] ["7"]
#guard prints [m "__lt__" ", o: Self" "Bool" "self.n < o.n"]
  ["var t = T(1)", "var u = T(2)", "print(u > t)"] ["True"]
#guard prints [m "__eq__" ", k: Int" "Bool" "self.n == k"] ["var t = T(2)", "print(2 == t)"]
  ["True"]
#guard prints [m "__lt__" ", o: Self" "Int" "42"] ["var t = T(1)", "print(t < t)"] ["42"]
#guard prints [["def __iadd__(mut self, k: Int):", "    self.n += k"]]
  ["var t = T(1)", "t += 4", "print(t.n)"] ["5"]
#guard prints [["def __neg__(self) -> Self:", "    return T(-self.n)"]]
  ["var t = T(5)", "var u = -(-t)", "print(u.n)"] ["5"]
#guard prints [m "__add__" ", k: Int" "Int" "self.n + k"] ["print(T(5) + 1)"] ["6"]

-- A method whose `mut self` the operand cannot be passed to is not viable.
#guard match runLines (withT [["def __radd__(mut self, k: Int) -> Int:", "    return 1"]]
    ["g(T(1))"] ++ ["def g(t: T):", "    print(1 + t)"]) with
  | some (.rejected ⟨"g", .noMatchingMethod ..⟩) => true
  | _ => false

-- What the operators cannot call.
#guard rejects [m "__add__" ", k: Int" "Int" "1"] ["var t = T(5)", "print(t + True)"]
  (.typeMismatch .int .bool)
#guard rejects [m "__radd__" ", b: Bool" "Int" "7"] ["var t = T(2)", "print(1 + t)"]
  (.noMatchingMethod "__add__")
#guard rejects [m "__radd__" ", k: Int" "Int" "7"] ["var t = T(1)", "var u = T(2)", "print(t + u)"]
  (.missingMethod (.struct "T") "__add__")
#guard rejects [m "__eq__" ", o: Self" "Bool" "True"] ["var t = T(1)", "print(t != t)"]
  (.missingMethod (.struct "T") "__ne__")
#guard rejects [m "__add__" ", o: Self" "Self" "T(1)"] ["var t = T(1)", "t += t"]
  (.missingMethod (.struct "T") "__iadd__")
#guard runLines (withT [["def __iadd__(self, k: Int):", "    pass"]] ["g(T(1))"] ++
    ["def g(t: T):", "    t += 1"]) == some (.rejected ⟨"g", .immutablePlace (.var "t")⟩)
#guard rejects [["def __iadd__(mut self, o: Self):", "    pass"]] ["var t = T(1)", "t += t"]
  (.argumentExclusivity (.var "t"))
-- An operator method takes as many operands as its operator.
#guard runLines (withT [m "__add__" "" "Int" "1"] ["var t = T(1)", "print(t.n)"]) ==
  some (.rejected ⟨"T.__add__", .arityMismatch "__add__" 2 1⟩)
#guard runLines (withT [m "__neg__" ", k: Int" "Int" "1"] ["var t = T(1)", "print(t.n)"]) ==
  some (.rejected ⟨"T.__neg__", .arityMismatch "__neg__" 1 2⟩)
-- A literal passed `ref` to an operator method is a temporary.
#guard prints [["def __add__(mut self, ref o: Int) -> Int:", "    self.n += 1", "    return o"]]
  ["var t = T(2)", "print(t + [t.n])", "print(t.n)"] ["2", "3"]
-- The destination may change, checked before the method is looked up.
#guard runLines (withT [] ["g(T(1))"] ++ ["def g(t: T):", "    t += True"]) ==
  some (.rejected ⟨"g", .immutablePlace (.var "t")⟩)

-- `not`, `and` and `or`: a struct operand is converted with `__bool__`,
-- unless both have its type.
#guard prints [m "__bool__" "" "Bool" "self.n != 0"] ["var t = T(1)", "print(not t, t and True)"]
  ["False True"]
#guard rejects [m "__bool__" "" "Bool" "self.n != 0"] ["var t = T(1)", "var x = t and t", "print(x.n)"]
  (.implicitCopy (.struct "T"))
#guard runLines ["@fieldwise_init", "struct T(ImplicitlyCopyable):", "    var n: Int",
    "    def __bool__(self) -> Bool:", "        return self.n != 0", "def main():",
    "    var x = T(0) or T(3)", "    print(x.n)"] == some (.finished ["3"])
-- The test of the left operand of the same type is checked as a call of
-- `__bool__`: one operand, a `Bool` result, and a `mut self` only on a
-- place that may change.
private def sameT (bool : List String) : List String :=
  ["struct T(ImplicitlyCopyable):", "    var n: Int", "    def __init__(out self, n: Int):",
    "        self.n = n"] ++ bool.map ("    " ++ ·) ++
    ["def main():", "    var x = T(0) or T(3)", "    print(x.n)"]
#guard runLines (sameT ["def __bool__(self, k: Int) -> Bool:", "    return True"]) ==
  some (.rejected ⟨"T.__bool__", .arityMismatch "__bool__" 1 2⟩)
#guard runLines (sameT (m "__bool__" "" "Int" "self.n")) ==
  some (.rejected ⟨"main", .missingMethod .int "__mlir_bool__"⟩)
#guard runLines (sameT ["def __bool__(mut self) -> Bool:", "    return True"]) matches
  some (.rejected ⟨"main", .notAPlace _⟩)
#guard runLines (sameT ["def __bool__(var self) -> Bool:", "    return self.n != 0"]) ==
  some (.finished ["3"])
-- A `var self` gets a copy of the left operand, a temporary too: a struct
-- that is not `ImplicitlyCopyable` is `implicitCopy`, on either path.
private def moveT (body : List String) : List String :=
  ["struct T(Movable):", "    var n: Int", "    def __init__(out self, n: Int):",
    "        self.n = n", "    def __bool__(var self) -> Bool:", "        return self.n != 0",
    "def main():"] ++ body.map ("    " ++ ·)
#guard runLines (moveT ["var x = T(0) or T(3)", "print(x.n)"]) ==
  some (.rejected ⟨"main", .implicitCopy (.struct "T")⟩)
#guard runLines (moveT ["print(T(4) and True)"]) ==
  some (.rejected ⟨"main", .implicitCopy (.struct "T")⟩)
#guard runLines (moveT ["var t = T(4)", "print(t^ or False)"]) ==
  some (.rejected ⟨"main", .implicitCopy (.struct "T")⟩)
#guard runLines (moveT ["print(True and T(4), not T(0))"]) == some (.finished ["True True"])

-- A value whose type does not convert to what it initializes is a
-- mismatch before a use of an uninitialized value inside it: the compiler
-- converts it as it types it (`checkValue`). The `and` of `x^` and a
-- `Bool` borrows `x` on the pin (#84); the conversion fails first.
private def moved (body : List String) : List String :=
  withT [m "__bool__" "" "Bool" "self.n > 0"] (["var x = T(1)", "var y = T(2)"] ++ body)
#guard runLines (moved ["y = (True and x^) or x.n > 0"]) ==
  some (.rejected ⟨"main", .typeMismatch (.struct "T") .bool⟩)
#guard runLines (moved ["var z: Int = (True and x^) or x.n > 0"]) ==
  some (.rejected ⟨"main", .typeMismatch .int .bool⟩)
#guard runLines (moved ["g((True and x^) or x.n > 0)"] ++ ["def g(t: T):", "    pass"]) ==
  some (.rejected ⟨"main", .typeMismatch (.struct "T") .bool⟩)
#guard runLines (moved ["var b = False", "b = (x^ or T(3)) and x.n > 0"]) ==
  some (.rejected ⟨"main", .uninitializedUse (.field (.var "x") "n")⟩)
#guard runLines (moved ["var b = (x^ or T(3)) and x.n > 0"]) ==
  some (.rejected ⟨"main", .uninitializedUse (.field (.var "x") "n")⟩)

-- Calls of a variable whose struct declares `__call__`, which hides the
-- function, `len`, `print` or struct of its name.
private def call : List String := m "__call__" ", k: Int" "Int" "self.n + k"
#guard prints [call] ["var t = T(7)", "print(t(2))"] ["9"]
#guard prints [call] ["var len = T(7)", "print(len(1))"] ["8"]
#guard prints [["def __call__(self, k: Int):", "    print(self.n + k)"]]
  ["var print = T(10)", "print(1)"] ["11"]
#guard runLines (withT [call] ["var f = T(7)", "print(f(1))"] ++
  ["def f(k: Int) -> Int:", "    return 1"]) == some (.finished ["8"])
#guard rejects [call] ["var t = T(1)", "print(t(2, 3))"] (.arityMismatch "T.__call__" 2 3)
#guard rejects [call] ["var t = T(1)", "print(t(True))"] (.typeMismatch .int .bool)
#guard rejects [call] ["var t: T", "print(t(1))"] (.uninitializedUse (.var "t"))
#guard rejects [["def __call__(self, x: List[Int]) -> Bool:", "    return True"]]
  ["var len = T(1)", "var xs: List[Int] = [1]", "print(-[True, len(xs)])"]
  (.missingMethod (.array .bool 2) "__neg__")

-- `Self` in a method is its struct.
#guard prints [m "same" ", o: Self" "Bool" "self.n == o.n"]
  ["var t = T(1)", "var u = T(1)", "print(t.same(u))"] ["True"]
#guard prints [m "__neg__" "" "Self" "Self(-self.n)"] ["var t = T(5)", "var u = -t", "print(u.n)"]
  ["-5"]

end MojoGrimoireTest.Parse.StructOperators
