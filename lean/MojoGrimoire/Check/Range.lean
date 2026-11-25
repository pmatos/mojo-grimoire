import MojoGrimoire.Check.Pass

/-!
The arguments of the standard library's `range` in the argument of
`List[u](…)` (#121), which the checking of expressions
(`MojoGrimoire.Check.Expr`) types and then reads in the compiler's order of
passes, as `rangeList` says. Each check is given the checks of the
expressions and places inside the arguments (`Below`), so that it lives
outside the mutual block of the expression checker.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Types the elements `es` of an open literal that is an argument of
`range`, and gives whether every element that is not a literal, at any
depth, is an `Int`, typed by `typeArg`, and whether its first element, at
any depth, is an empty literal: such a literal fits no form of `range`
(#121). -/
def typeLiteral {r : List Expr} (typeArg : Below Expr Ty r) :
    (es : List Expr) → sizeOf es ≤ sizeOf r → CheckM (Bool × Bool)
  | [], _ => pure (true, true)
  | e :: es, h => do
    let (ints, empty) ← match e, h with
      | .list .unknown es', h | .list .int es'@([]), h | .list .int es'@(_ :: _ :: _), h =>
        typeLiteral typeArg es' (by subst_vars; simp at h ⊢; omega)
      | e, h => do pure ((← typeArg e (by subst_vars; simp at h ⊢; omega)) == .int, false)
    let (ints', _) ← typeLiteral typeArg es (by subst_vars; simp at h ⊢; omega)
    pure (ints && ints', empty)
  termination_by es => sizeOf es

/-- Types the arguments of the standard library's `range` in the argument
of `List[u](…)`, each in `State.typing`, and gives whether one fits no form
of `range`, and whether one is an open literal of `Int`s, which the
compiler takes for an `Int` and rejects only when it instantiates the call
(#121). An error of typing is thrown, in any argument; a literal is typed
by `typeLiteral`, and any other argument by `typeArg`. A literal whose first
element, at any depth, is an empty literal fits no form as the `first`
argument, and is such a literal of `Int`s after it. -/
def typeRangeArgs {r : List Expr} (typeArg : Below Expr Ty r) (first : Bool) :
    (as : List Expr) → sizeOf as ≤ sizeOf r → CheckM (Bool × Bool)
  | [], _ => pure (false, false)
  | a :: as, h => do
    modify State.typing
    let (misfit, literal) ← match a, h with
      | .list .unknown es, h | .list .int es@([]), h | .list .int es@(_ :: _ :: _), h => do
        let (ints, empty) ← typeLiteral typeArg es (by subst_vars; simp at h ⊢; omega)
        pure (if ints && !(first && empty) then (false, true) else (true, false))
      | a, h => do pure ((← typeArg a (by subst_vars; simp at h ⊢; omega)) != .int, false)
    let (misfit', literal') ← typeRangeArgs typeArg false as (by subst_vars; simp at h ⊢; omega)
    pure (misfit || misfit', literal || literal')
  termination_by as => sizeOf as

/-- Reads the arguments `as` of `range`, typed by `typeRangeArgs`, in
order, as `Int`s passed to `read` parameters, and an open literal's
elements in turn: a place once `checkIndices` has checked its indices, and
any other argument by `check`. An error of a later pass than typing is
recorded (`lateErrors`), and the arguments and elements after it still
read. -/
def readRangeArgs (prog : Program) {r : List Expr} (checkIndices : Below Place Unit r)
    (check : Below Expr Ty r) : (as : List Expr) → sizeOf as ≤ sizeOf r → CheckM RangeArgs
  | [], _ => pure {}
  | a :: as, h => do
    let r ← match a, h with
      | .list .unknown es, h | .list .int es@([]), h | .list .int es@(_ :: _ :: _), h =>
        readRangeArgs prog checkIndices check es (by subst_vars; simp at h ⊢; omega)
      | .place p, h => lateErrors (do
        checkIndices p (by subst_vars; simp at h ⊢; omega)
        let _ ← readPlace prog p
        pure { locs := [([p], ← mark)] })
      | a, h => lateErrors (do
        let _ ← check a (by subst_vars; simp at h ⊢; omega)
        pure { locs := [(← lateLocs prog a, ← mark)] })
    pure (r.append (← readRangeArgs prog checkIndices check as (by subst_vars; simp at h ⊢; omega)))
  termination_by as => sizeOf as

end MojoGrimoire.Check
