import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the operators, subscripts, `and`, `or` and calls on a struct
value, which call the methods that the struct declares (#191,
`MojoGrimoire.Parse.Dispatch`): which method inference calls, and what
running the program gives. Each verdict is the pinned compiler's for the
program, probed on the nightly 1.3.0.dev2026111905, but where a comment
names a compiler bug that the human ruled on (#211).
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
-- `main` read a place that `not` tests as a value, which copies it: once a
-- later error in the statement brings `main`'s order back, that is
-- `implicitCopy`, before the first argument's misfit, as the pin reports
-- for the second argument.
#guard runLines ["struct M(Movable):", "    var f: Bool", "    def __init__(out self, f: Bool):",
    "        self.f = f", "    def __bool__(self) -> Bool:", "        return self.f",
    "def f2(a: Int, b: Bool) -> Int:", "    return a", "def main():", "    var m = M(True)",
    "    var m2 = M(False)", "    print(f2(not m, m or m2))"] ==
  some (.rejected ⟨"main", .implicitCopy (.struct "M")⟩)

-- The bridge to `main`'s order (`bridged`, until #96 part 4). `main`
-- rejected a struct test as `typeMismatch` once its operands were checked,
-- and so did any statement whose error comes after the test, which the
-- pin reports as `typeMismatch` too when the statement has a type error:
-- so it is still. An error before the test stays as it is.
private def bridgeWith (decls body : List String) : Option Outcome :=
  runLines (["struct S(ImplicitlyCopyable):", "    var n: Int", "    var f: Bool",
    "    def __init__(out self, n: Int, f: Bool):", "        self.n = n", "        self.f = f",
    "    def __bool__(self) -> Bool:", "        return self.f",
    "    def __add__(self, o: S) -> S:", "        return S(self.n + o.n, self.f)",
    "    def __neg__(self) -> S:", "        return self",
    "    def __lt__(self, o: S) -> Bool:", "        return self.n < o.n"] ++ decls ++
    ["def main():", "    var x = S(1, False)", "    var y = S(2, True)",
    "    var xs: List[Int] = [1, 2, 3]", "    var k = 1"] ++ body.map ("    " ++ ·))
private def bridge (body : List String) : Option Outcome := bridgeWith [] body
private def mainMismatch (body : List String) : Bool :=
  bridge body matches some (.rejected ⟨"main", .typeMismatch ..⟩)
#guard mainMismatch ["y = (True and x^) or x.f"]
#guard mainMismatch ["var c = x^", "var w: List[Int] = (y.f or y) and x.f"]
#guard mainMismatch ["var c = x^", "var w: Int = (y.f or y) and (len(xs) > 0) and x.f"]
#guard mainMismatch ["var c = x^", "var w = (y or x) + k"]
#guard mainMismatch ["var w: List[Int] = (y.f or y) and xs[5] > 0"]
#guard mainMismatch ["var w = k + ((True and x^) or x.f)"]
#guard mainMismatch ["var b = False", "b = (x^ or S(3, True)) and x.f"]
#guard mainMismatch ["var c = x^", "var z = -(y or x)"]
-- Where an operator fits no `Bool`, `main` typed its operands, leaving out
-- a later-pass error, and then rejected the misfit (`mainOperator`); the
-- pin's `negativeIndex` comes from its passes' order (#96).
#guard bridge ["var z = (y or S(xs[1 - 2], True)) + y"]
  matches some (.rejected ⟨"main", .missingMethod ..⟩)
#guard bridge ["var z = -(y or S(xs[1 - 2], True))"]
  matches some (.rejected ⟨"main", .missingMethod ..⟩)
-- A test that a reflected method takes: `main` typed it as a `Bool`, so
-- `y > (x or y)` was `y.__gt__`, which `S` lacks.
#guard mainMismatch ["var c = x^", "var z: Int = y > (x or y)"]
-- An error after a test that passes, not of the later pass either, was
-- `main`'s `typeMismatch` too.
#guard mainMismatch ["print(y or x, k)"]
#guard bridge ["var c = x^", "print(x.n, y.f or y)"] ==
  some (.rejected ⟨"main", .uninitializedUse (.field (.var "x") "n")⟩)
-- `main` typed a test of two structs as a `Bool` at any depth, so
-- `[x or y]` was an array of `Bool`s, which `[k]` does not fit: that
-- misfit of the comparison comes before the moved `x`, as the pin's does.
#guard mainMismatch ["var c = x^", "var z = [x or y] == [k]"]
#guard mainMismatch ["var c = x^", "var z = [x or y] < [k]"]
#guard mainMismatch ["var z = [S(xs[1 - 2], True) or y] == [k]"]
-- An error of the test itself, a `__bool__` that returns an `Int` or takes
-- `mut self`, stays only where the statement holds no other error: else
-- `main` reported the test's `typeMismatch` first, which the pin gives for
-- the index's misfit, as it types the target first.
private def withU (body : List String) : Option Outcome :=
  bridgeWith ["struct U(ImplicitlyCopyable):", "    var f: Bool",
    "    def __init__(out self, f: Bool):", "        self.f = f",
    "    def __bool__(self) -> Int:", "        return 1",
    "struct V(ImplicitlyCopyable):", "    var f: Bool",
    "    def __init__(out self, f: Bool):", "        self.f = f",
    "    def __bool__(mut self) -> Bool:", "        return self.f",
    "def bi(a: Int) -> Int:", "    return a"]
    (["var u = U(True)", "var u2 = U(False)", "var v = V(True)",
      "var ls: List[S] = [S(1, True)]"] ++ body)
#guard withU ["var q = u or u2"] ==
  some (.rejected ⟨"main", .missingMethod .int "__mlir_bool__"⟩)
#guard withU ["ls[bi(u)] = (u or u2)"] matches some (.rejected ⟨"main", .typeMismatch ..⟩)
#guard withU ["ls[bi(u)] = (V(True) or v)"] matches some (.rejected ⟨"main", .typeMismatch ..⟩)
-- On the mixed path and under `not` too, where inference made the call
-- of `__bool__` that the replay without those checks leaves out.
#guard withU ["ls[bi(u)] = (True or V(True))"] matches some (.rejected ⟨"main", .typeMismatch ..⟩)
#guard withU ["ls[bi(u)] = (not V(True))"] matches some (.rejected ⟨"main", .typeMismatch ..⟩)
-- `main`'s `typeMismatch` here too, before the `mut self` of the
-- temporary `V(True)`, which the pin reports.
#guard withU ["var z = (y or S(xs[1 - 2], True)) + (V(True) or v)"]
  matches some (.rejected ⟨"main", .typeMismatch ..⟩)
#guard bridge ["var c = x^", "var w = (x.f and y.f) or y"] ==
  some (.rejected ⟨"main", .uninitializedUse (.field (.var "x") "f")⟩)
-- Without a test of a struct, nothing changes from `main`: the pin's
-- `noMatchingMethod` for `1 + b` comes from its passes' order (#96), and a
-- value of `Int`s under `or` is typed with a known gap (#187).
#guard runLines (withT [] ["var b: Bool", "print(1 + b)"]) ==
  some (.rejected ⟨"main", .uninitializedUse (.var "b")⟩)
#guard runLines (withT [] ["var j = 0", "var k: Int", "print(j or k)"]) ==
  some (.rejected ⟨"main", .uninitializedUse (.var "k")⟩)

-- Subscripts: the getter is called late only when the struct declares a
-- setter too.
private def getter : List String := m "__getitem__" ", i: Int" "Int" "self.n + i"
private def setter : List String := ["def __setitem__(mut self, i: Int, v: Int):", "    self.n = v"]
private def bump : List String := ["def bump(mut t: T) -> Int:", "    t.n += 10", "    return 0"]
#guard prints [getter] ["var t = T(5)", "print(t[1])"] ["6"]
#guard prints [getter, setter] ["var t = T(5)", "t[1] = 2", "print(t.n)"] ["2"]
#guard runLines (withT [getter, setter] ["var t = T(1)", "print(t[0], bump(t))"] ++ bump) ==
  some (.finished ["11 0"])
#guard runLines (withT [getter] ["var t = T(1)", "print(t[0], bump(t))"] ++ bump) ==
  some (.finished ["1 0"])
#guard rejects [getter] ["var t = T(1)", "t[0] = 2"]
  (.immutablePlace (.index (.var "t") (.int 0)))
#guard rejects [getter] ["var t = T(1)", "print(t[True])"] (.typeMismatch .int .bool)
-- The index is typed before the receiver is read, as any subscript's is: an
-- unknown name or a misfit in it comes before a use of a moved receiver.
#guard rejects [getter] ["var t = T(1)", "var u = t^", "print(t[nope])"]
  (.unknownVariable "nope")
#guard rejects [getter, setter] ["var t = T(1)", "var u = t^", "print(t[True])"]
  (.typeMismatch .int .bool)
#guard rejects [getter, setter] ["var t = T(1)", "var u = t^", "print(t[[1, 2]])"]
  (.uninitializedUse (.var "t"))
#guard rejects [getter] ["var t = T(1)", "var u = t^", "print(t[0])"]
  (.uninitializedUse (.var "t"))
-- With a setter, the getter's call and its result are checked first.
#guard rejects [getter, ["def __setitem__(mut self, b: Bool, v: Int):", "    pass"]]
  ["var t = T(1)", "t[True] = 5"] (.typeMismatch .int .bool)
#guard rejects [getter, ["def __setitem__(mut self, i: Int, v: Bool):", "    pass"]]
  ["var t = T(1)", "t[1] = True"] (.typeMismatch .int .bool)
-- Assigning it checks the getter's call first, and never the value.
#guard rejects [getter] ["var t = T(1)", "t[True] = 2"] (.typeMismatch .int .bool)
#guard rejects [getter] ["var t = T(1)", "t[0] = nope"]
  (.immutablePlace (.index (.var "t") (.int 0)))
-- A subscript read late passed `mut`, here to `mut self`, keeps the result
-- it had before #191, `notAList`, until its write-back is modelled (#198).
#guard rejects [m "__getitem__" ", i: Int" "T" "T(self.n)",
    ["def __setitem__(mut self, i: Int, v: T):", "    pass"],
    ["def __add__(mut self, k: Int) -> Int:", "    return self.n + k"]]
  ["var t = T(1)", "print(t[0] + 1)"] (.notAList (.struct "T"))
-- On the left of `and` or `or`, a getter-and-setter subscript is read once,
-- as one of a struct with no setter is (#211).
private def bgetter : List String :=
  ["def __getitem__(self, i: Int) -> Bool:", "    print(\"get\", i)", "    return self.n != 0"]
#guard prints [bgetter, ["def __setitem__(mut self, i: Int, v: Bool):", "    pass"]]
  ["var t = T(1)", "print(t[0] or False)"] ["get 0", "True"]
#guard prints [bgetter] ["var t = T(1)", "print(t[0] or False)"] ["get 0", "True"]

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
