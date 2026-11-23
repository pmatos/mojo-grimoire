import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the left operand of `and` and `or` on two values of the same
struct type, passed to the `self` of its `__bool__` without being checked
again (`MojoGrimoire.Check.passLeft`), and of the misfit of `and` and `or`,
which asks a nested test's operands first (`MojoGrimoire.Check.lackingTy`).
Each whole program's verdict is the pinned compiler's, probed on the
nightly 1.3.0.dev2026111905; the other tests call the checker's functions
directly.
-/

namespace MojoGrimoireTest.Check.LeftOperand

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- An empty state and an empty program: enough for the operands below,
which name no variable that is looked up. -/
private def st : State := { vars := [], live := true, stale := [], changes := [] }
private def none' : Program := { structs := [], funs := [] }

private def t : Ty := .struct "T"
private def x (n : Name) : Expr := .place (.var n)

/-- Whether `r` failed with the error `e`. -/
private def failsWith {α : Type} (r : Except CheckError α) (e : CheckError) : Bool :=
  match r with
  | .error e' => e' == e
  | .ok _ => false

/-- Passes the left operand `a`, of type `T`, to a `self` of convention
`c` of `T.__bool__`. -/
private def passing (c : Conv) (a : Expr) : Except CheckError Unit :=
  (passLeft none' ⟨c, "self", t⟩ "T.__bool__" a t st st).run' st

private def nested : Expr := .binary .or (x "a") (x "b")
private def wrapped : Expr := .call "idT" [nested]

-- An `out` or `deinit` `self` takes no operand that is not a place, as a
-- call's argument; the declaration's check rejects such a `__bool__`
-- first in a whole program.
#guard failsWith (passing .out nested) (.invalidConvention "T.__bool__")
#guard failsWith (passing .deinit wrapped) (.invalidConvention "T.__bool__")
-- A `mut self` takes no temporary, a nested test or a call that returns a
-- value (`notAPlace`, where the compiler says `immutablePlace`, #81).
#guard failsWith (passing .mutable nested) (Fit.call.misfit (.notAPlace "T.__bool__"))
#guard failsWith (passing .mutable wrapped) (Fit.call.misfit (.notAPlace "T.__bool__"))
-- A `read` or `var` `self` takes them, of the struct's type.
#guard (passing .read nested matches .ok _) && (passing .owned wrapped matches .ok _)
#guard failsWith ((passLeft none' ⟨.read, "self", t⟩ "T.__bool__" nested .int st st).run' st)
  (Fit.call.misfit (.typeMismatch t .int))

/-- A state whose one variable `x`, of type `T` and access `acc`, has the
parts `moved` moved out. -/
private def withX (acc : Access) (moved : List Path) : State :=
  { st with vars := [⟨"x", t, acc, [], moved, [], [], []⟩] }

private def passFrom (c : Conv) (a : Expr) (before after : State) : Except CheckError Unit :=
  (passLeft none' ⟨c, "self", t⟩ "T.__bool__" a t before after).run' before

-- A place is passed from the state after the first check, as `checkArg`
-- passes it once it has checked the place's indices: `x` moved there is
-- `uninitializedUse`, though it was whole before.
#guard failsWith (passFrom .read (x "x") (withX .owned []) (withX .owned [[]]))
  (.uninitializedUse (.var "x"))
#guard passFrom .read (x "x") (withX .owned [[]]) (withX .owned []) matches .ok _
-- Any other operand is passed from the state before it: `x^` under a
-- `mut self` is `transferFromBorrowed` when `x` could not change there.
#guard failsWith (passFrom .mutable (.transfer (.var "x")) (withX .readOnly []) (withX .owned []))
  (.transferFromBorrowed (.var "x"))
#guard failsWith (passFrom .mutable (.transfer (.var "x")) (withX .owned []) (withX .readOnly []))
  (Fit.call.misfit (.notAPlace "T.__bool__"))

/-- The form of an operand that `lackingTy` is given: `leaf` for an
operand that is no binary operation, and an error for one that is, which
shows whether `lackingTy` asked for the form of a whole test. -/
private def form (leaf : Ty) : Expr → CheckM (Option Ty)
  | .binary .. => throw (.invalidType .unknown)
  | _ => pure (some leaf)

private def lackingOf (leaf : Ty) (e : Expr) : Except CheckError (Option Ty) :=
  (lackingTy none' (form leaf) e).run' st

-- An operand of `Bool`s gives no type that lacks `__bool__`, so the form
-- of the whole test is not asked for, at any depth.
#guard lackingOf .bool nested matches .ok none
#guard lackingOf .bool (.binary .and nested (x "c")) matches .ok none
-- Operands of a struct that lacks `__bool__` may give one, so the form of
-- the whole test is asked for.
#guard failsWith (lackingOf (.struct "S") nested) (.invalidType .unknown)
-- An operand that is no test gives its form, when it lacks `__bool__`.
#guard lackingOf (.array .int 2) (x "a") matches .ok (some (.array .int 2))
#guard lackingOf .int (x "a") matches .ok none

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- A struct `T` with a field `n` and a `__bool__` of the convention `c`,
the function `idT`, then the lines `rest`. -/
private def withT (c : String) (rest : List String) : List String :=
  ["struct T(ImplicitlyCopyable):", "    var n: Int",
    "    def __init__(out self, n: Int):", "        self.n = n",
    s!"    def __bool__({c}self) -> Bool:", "        return self.n != 0",
    "def idT(x: T) -> T:", "    return x"] ++ rest

private def mainOf (body : List String) : List String :=
  "def main():" :: ["var a = T(0)", "var b = T(2)"].map ("    " ++ ·) ++ body.map ("    " ++ ·)

-- A `mut self` takes a place that may change, and not a `read` parameter.
#guard runLines (withT "mut " (mainOf ["var r = a or b", "print(r.n)"])) ==
  some (.finished ["2"])
#guard runLines (withT "mut " (["def f(a: T, b: T) -> Int:", "    var r = a or b",
  "    return r.n"] ++ mainOf ["print(f(a, b))"])) ==
  some (.rejected ⟨"f", .immutablePlace (.var "a")⟩)
-- A call that wraps a nested test, on the left, 20 levels deep, which
-- each level passes to `self`. The suite's
-- `structs/operator_method_bool_chain_call_left`, 40 levels deep, keeps
-- the check's time linear in the depth, under the suite's time limit.
private def callChain : Nat → String
  | 0 => "(a or b)"
  | n + 1 => s!"(idT({callChain n}) or b)"
#guard runLines (withT "" (mainOf [s!"var r = {callChain 20}", "print(r.n)"])) ==
  some (.finished ["2"])

end MojoGrimoireTest.Check.LeftOperand
