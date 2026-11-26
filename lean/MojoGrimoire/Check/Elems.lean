import MojoGrimoire.Check.Pass

/-!
The elements of two kinds of literal, which the checking of expressions
(`MojoGrimoire.Check.Expr`) checks one by one: a literal with no type
expected that is the argument of `List[u](…)`, and a literal of any length
but 1 where an `Int` is expected (#153, #154). Each check is given the
checks of the expressions and places inside the literal (`Below`), so that
it lives outside the mutual block of the expression checker.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Checks the elements `es` of a literal with no type expected that is
the argument of `List[u](…)`, in order, each as passed to a `var`
parameter, by `check`, and gives the type of each, with the places it is
read from once every element is evaluated and how many changes were
recorded once it was checked; `iterableLiteralTy` gives the literal's
type. -/
def checkIterableElems (prog : Program) (u : Ty) {r : List Expr} (check : Below Expr Ty r) :
    (es : List Expr) → sizeOf es ≤ sizeOf r → CheckM (List (Ty × List Place × Nat))
  | [], _ => pure []
  | e :: es, h => do
    let t ← match e, h with
      | .list .unknown es', h => do
        iterableLiteralTy prog u (← checkIterableElems prog u check es' (by below_bound h))
      | e, h => check e (by below_bound h)
    let k ← mark
    pure ((t, ← lateLocs prog e, k) :: (← checkIterableElems prog u check es (by below_bound h)))
  termination_by es => sizeOf es

/-- The type of the first of the elements `es` of a literal where an `Int`
is expected that is no `Int`, nor such a literal of `Int`s. Each is typed
in `State.typing`, a place by `typePlace`, any other element by `check`;
one whose check gives an error that the compiler reports later has its
`lateElemTy`. -/
def intMisfit (prog : Program) {r : List Expr} (typePlace : Below Place Unit r)
    (check : Below Expr Ty r) : (es : List Expr) → sizeOf es ≤ sizeOf r → CheckM (Option Ty)
  | [], _ => pure none
  | e :: es, h => do
    modify State.typing
    let u ← match e, h with
      | .place p, h => do
        try typePlace p (by below_bound h) catch err =>
          unless err.late || err == .noMatchingInit .int do throw err
        placeTy prog p
      | .list .int es', h => do
        pure ((← intMisfit prog typePlace check es' (by below_bound h)).getD .int)
      | e, h => try check e (by below_bound h) catch err =>
          if err.late || err == .noMatchingInit .int then lateElemTy prog e else throw err
    if u == .int then intMisfit prog typePlace check es (by below_bound h) else pure (some u)
  termination_by es => sizeOf es

/-- Reads the elements `es` of such a literal of `Int`s, each by `check`,
as `Int`s passed `var`, a nested one's elements in turn, and gives what
each reads late. -/
def readIntElems (prog : Program) {r : List Expr} (check : Below Expr Ty r) :
    (es : List Expr) → sizeOf es ≤ sizeOf r → CheckM (List (List Place × Nat))
  | [], _ => pure []
  | e :: es, h => do
    let ks ← match e, h with
      | .list .int [], _ => pure []
      | .list .int es'@(_ :: _ :: _), h => readIntElems prog check es' (by below_bound h)
      | e, h => do
        expect .int (← check e (by below_bound h))
        let k ← mark
        pure [(← lateLocs prog e, k)]
    pure (ks ++ (← readIntElems prog check es (by below_bound h)))
  termination_by es => sizeOf es

/-- Rejects a literal `es` of `Int`s of any length but 1 as a call of fit
`fit` reports it (`rejectIntLiteral`): `intMisfit` types its elements and
`readIntElems` reads them, given the checks `typePlace` and `check`. It
rejects only in the instantiation phase. -/
def rejectIntElems (prog : Program) (fit : Fit) (es : List Expr)
    (typePlace : Below Place Unit es) (check : Below Expr Ty es) : CheckM Unit :=
  rejectIntLiteral prog fit (intMisfit prog typePlace check es (Nat.le_refl _))
    (readIntElems prog check es (Nat.le_refl _))

end MojoGrimoire.Check
