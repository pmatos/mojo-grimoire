import MojoGrimoire.Check.Loc

/-!
How a call reports an argument that does not fit its parameter (#46).

A function or a method reports the misfit itself: a type mismatch, a wrong
number of arguments, a value that is not a place, or a place that may not
change, passed `mut`. An initializer reports every misfit as
`noMatchingInit` of its type, since the compiler tries each initializer
and reports only that none fits: a construction `S(…)`, and a literal that
initializes the list or array expected where it stands. A literal passed
to a function or a method is converted to its parameter's type, and the
compiler reports one that does not fit as a type mismatch.
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

end MojoGrimoire.Check
