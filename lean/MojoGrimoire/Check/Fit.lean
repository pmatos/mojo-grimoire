import MojoGrimoire.Check.Change

/-!
How a call reports an argument that does not fit its parameter (#46).

A function or a method reports the misfit itself: a type mismatch, a wrong
number of arguments, a value that is not a place, or a place that may not
change, passed `mut`. An initializer reports every misfit as
`noMatchingInit` of its type, since the compiler tries each initializer
and reports only that none fits: a construction `S(…)`, and a literal that
initializes the list or array expected where it stands, and `List[u](e)`
from a source that is not a list or an array of `u` that can be copied. A
literal passed to a function or a method is converted to its parameter's
type, and the compiler reports one that does not fit as a type mismatch.
A literal of any length but 1 where an `Int` is expected fits nowhere
(`rejectIntLiteral`, #153, #154).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- How a call reports an argument that does not fit its parameter: a
function or a method by the error itself, and an initializer of the type
`t` by `noMatchingInit t`, whatever the misfit. -/
inductive Fit where
  | call
  | init (t : Ty)

/-- The error that a call of fit `fit` reports for the misfit `e`. -/
def Fit.misfit : Fit → CheckError → CheckError
  | .call, e => e
  | .init t, _ => .noMatchingInit t

/-- Rejects unless the type of an argument, `actual`, is its parameter's,
`expected`, by the error that `fit` reports. -/
def expectArg (fit : Fit) (expected actual : Ty) : CheckM Unit :=
  unless expected == actual do throw (fit.misfit (CheckError.typeMismatch expected actual))

/-- Rejects a value that is not a place passed to a parameter of convention
`c`, of a call of `callee` of fit `fit`: it may not be passed `mut`, `out`
or `deinit`. -/
def passValue (fit : Fit) (callee : Name) (c : Conv) : CheckM Unit := do
  if c == .out || c == .deinit then throw (CheckError.invalidConvention callee)
  if c == .mutable then throw (fit.misfit (CheckError.notAPlace callee))

/-- The element type of a literal of `n` elements that has the expected type
`t`, which a call of fit `fit` initializes or converts it to. It rejects a
`t` that is not a list or an array of a valid type, and an array of another
size. -/
def literalElem (prog : Program) (fit : Fit) (t : Ty) (n : Nat) : CheckM Ty := do
  let .ok u := elemOf t | throw (CheckError.invalidType t)
  unless validTy prog u do throw (CheckError.invalidType t)
  if let .array _ k := t then
    unless k == n do throw (fit.misfit (CheckError.typeMismatch t (.array u n)))
  pure u

/-- Rejects unless a value of the type `t` is a source that `List[u](e)`
copies, through the initializer of `List` from any iterable: a list or an
array of `u`, which can be copied (#103). Anything else fits no
initializer of `List[u]`. -/
def iterableFits (prog : Program) (u t : Ty) : CheckM Unit := do
  unless (elemOf t).toOption == some u && copyingOf prog t != .none do
    throw (CheckError.noMatchingInit (.list u))

/-- The type of a literal `[e₁, …, eₙ]` with no type expected that is the
argument of `List[u](…)`, given the type of each element, with the places
it is read from and when it was checked: an array of the type of `e₁`. The
compiler infers that type while it looks for an initializer, so a literal
with no elements, or an element whose type differs from the first, also
inside a nested literal, fits no initializer of `List[u]` (#103). -/
def iterableLiteralTy (prog : Program) (u : Ty) (ts : List (Ty × List Place × Nat)) :
    CheckM Ty := do
  let some (t, _) := ts.head? | throw (CheckError.noMatchingInit (.list u))
  unless validTy prog t do throw (CheckError.invalidType (.array t ts.length))
  unless ts.all (·.1 == t) do throw (CheckError.noMatchingInit (.list u))
  recheckLocs prog (ts.map (·.2))
  pure (.array t ts.length)

/-- The elements of a literal `[e₁, …, eₙ]`, `n ≠ 1`, typed `Int`, as
inference types one where an `Int` is expected (#153, #154). -/
def wrongIntLiteral : Expr → Option (List Expr)
  | .list .int es => if es.length == 1 then none else some es
  | _ => none

/-- The state `s` with every variable whole and no reference invalidated,
in which an expression is typed without its reads failing. -/
def State.typing (s : State) : State :=
  { s with vars := s.vars.map fun v => { v with uninit := [], moved := [], pieces := [] },
           stale := [] }

/-- Rejects a `wrongIntLiteral` as a call of fit `fit` reports it. The
compiler types its elements before it reads any: `misfit`, run in the
state's `State.typing`, gives the type of the first that is no `Int`,
nor such a literal of `Int`s, a type mismatch. Otherwise `reads` reads
them, and the compiler then fails SIMD's constraint of one element,
`noMatchingInit`. -/
def rejectIntLiteral {α : Type} (prog : Program) (fit : Fit) (misfit : CheckM (Option Ty))
    (reads : CheckM (List (List Place × Nat))) : CheckM α := do
  let s ← get
  set s.typing
  if let some u ← misfit then throw (fit.misfit (CheckError.typeMismatch .int u))
  set s
  recheckLocs prog (← reads)
  throw (fit.misfit (CheckError.noMatchingInit .int))

end MojoGrimoire.Check
