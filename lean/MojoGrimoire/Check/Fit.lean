import MojoGrimoire.Check.Change

/-!
How a call reports an argument that does not fit its parameter (#46).

A function or a method reports the misfit itself: a type mismatch, a wrong
number of arguments, a value that is not a place, or a place that may not
change, passed `mut`. An initializer reports every misfit as
`noMatchingInit` of its type, since the compiler tries each initializer
and reports only that none fits: a construction `S(…)`, and a literal that
initializes the list or array expected where it stands, and `List[u](e)`
from a source that is not a list or an array of `u` that can be copied,
or from `range(…)` with arguments that fit no form of `range` (#121). A
literal passed to a function or a method is converted to its parameter's
type, and the compiler reports one that does not fit as a type mismatch.
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

mutual
/-- Whether the expression `e` holds a string or a call of `range`, itself
or through a literal or an operator: the model cannot type it, and the
compiler finds no form of `range` that takes it as an argument (#121). -/
def holdsStrOrRange : Expr → Bool
  | .str _ | .call "range" _ => true
  | .list _ es => holdsStrOrRangeList es
  | .unary _ a => holdsStrOrRange a
  | .binary _ a b => holdsStrOrRange a || holdsStrOrRange b
  | _ => false

/-- Whether one of the expressions `es` holds a string or a call of
`range` (`holdsStrOrRange`). -/
def holdsStrOrRangeList : List Expr → Bool
  | [] => false
  | e :: es => holdsStrOrRange e || holdsStrOrRangeList es
end

/-- What checking the arguments of the standard library's `range` finds,
by the compiler's passes, which report in this order (#121): `misfit`, an
argument that fits no form of `range` once every argument is typed;
`owned`, the first use of an uninitialized or invalidated value; `literal`,
a literal of `Int`s of a length other than 1, or empty, which fails when
the call is instantiated; `index`, the first constant index out of range.
`locs` holds, for each argument, the places it reads late, with its mark. -/
structure RangeArgs where
  misfit : Bool := false
  owned : Option CheckError := none
  literal : Bool := false
  index : Option CheckError := none
  locs : List (List Place × Nat) := []

/-- What the arguments `r` and then `s` find. -/
def RangeArgs.append (r s : RangeArgs) : RangeArgs :=
  ⟨r.misfit || s.misfit, r.owned <|> s.owned, r.literal || s.literal, r.index <|> s.index,
    r.locs ++ s.locs⟩

/-- The error `err` of a later pass than typing, found in an argument of
`range`: a constant index out of range, or else a use of a value. -/
def RangeArgs.ofLate (err : CheckError) : RangeArgs :=
  if err matches .negativeIndex _ | .constantIndexOutOfBounds _ then { index := some err }
  else { owned := some err }

/-- Whether the type `t` is `Int`, or an array of such, as the elements of
a literal of `Int`s are, at any depth. -/
def intShaped : Ty → Bool
  | .int => true
  | .array t _ => intShaped t
  | _ => false

end MojoGrimoire.Check
