import MojoGrimoire.Check.Change
import MojoGrimoire.Check.Operators

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
type, and the compiler reports one that does not fit, also inside it, as a
type mismatch. A literal with no expected type takes the type of its
elements, and an element that differs from the first is a type mismatch
too. A literal of type `Int`, which inference keeps only for `[e]` of one
`Int` element made of literals and operators, or passed `mut` or `ref`,
has the type of `e` (#103); passed so, what `e` is read from is read late,
as an operand. One of any other length where an `Int` is expected fits
nowhere (`rejectIntLiteral`, #153, #154): an element that is no `Int` fits
no initializer, or is a type mismatch where the literal is converted; else
it is `noMatchingInit` once its elements are read.

With one argument, `List[u](e)` copies the elements of a list or an array
of `u`, which can be copied (#103): `e` is passed by `ref`, as `len` takes
its list, and a mutable place passed so may be changed. `List[u](range(…))`,
when neither the program nor a variable in scope is named `range`, takes
one to three `Int`s, read as `read` arguments, and needs `u` to be `Int`;
any misfit is `noMatchingInit` (#121). Its errors come in the compiler's
order of passes: typing errors in any argument first, then the misfits of
`range`, then uses of uninitialized or invalidated values, then a literal
of `Int`s of the wrong length, then a constant index out of range.
Anywhere else `range` is an unknown function.
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

/-- What reading the arguments of the standard library's `range` finds, of
the compiler's passes after typing, which report in this order (#121):
`owned`, the first use of an uninitialized or invalidated value; `index`,
the first constant index out of range. `locs` holds the places that the
arguments read late, each with its mark, of those read without an error. -/
structure RangeArgs where
  owned : Option CheckError := none
  index : Option CheckError := none
  locs : List (List Place × Nat) := []

/-- What the arguments `r` and then `s` find. -/
def RangeArgs.append (r s : RangeArgs) : RangeArgs :=
  ⟨r.owned <|> s.owned, r.index <|> s.index, r.locs ++ s.locs⟩

/-- The error `err` of a later pass than typing, found in an argument of
`range`: a constant index out of range, or else a use of a value. -/
def RangeArgs.ofLate (err : CheckError) : RangeArgs :=
  if err matches .negativeIndex _ | .constantIndexOutOfBounds _ then { index := some err }
  else { owned := some err }

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

/-- The type of an element `e` of a literal where an `Int` is expected, when
checking it gives an error that the compiler reports after its types: one
of a later pass (`CheckError.late`), or a nested literal's failed SIMD
constraint. It is the type of its operator's or its call's result, of
the place it reads, the list that `List[u](e)` builds, an array of its
first element, or else `Int`. -/
def lateElemTy (prog : Program) : Expr → CheckM Ty
  | .unary .not _ => pure .bool
  | .binary op _ _ => pure (binaryResult op)
  | .call f _ => pure (((callSig prog f).toOption.map (·.result)).getD .int)
  | .method p m args => do
    pure (((methodSig prog (← placeTy prog p) m args.length).toOption.map (·.result)).getD .int)
  | .place p | .copy p | .transfer p => placeTy prog p
  | .listInit u [_] => pure (.list u)
  | .list .noneType (e :: es) => do pure (.array (← lateElemTy prog e) (es.length + 1))
  | _ => pure .int

/-- Rejects a `wrongIntLiteral` as a call of fit `fit` reports it. The
compiler types its elements before it reads any: `misfit` types each in
`State.typing`, and gives the type of the first that is no `Int`, nor
such a literal of `Int`s, a type mismatch. Otherwise, in the state it
started from, `reads` reads them, and the compiler then fails SIMD's
constraint of one element, `noMatchingInit`. -/
def rejectIntLiteral {α : Type} (prog : Program) (fit : Fit) (misfit : CheckM (Option Ty))
    (reads : CheckM (List (List Place × Nat))) : CheckM α := do
  let s ← get
  if let some u ← misfit then throw (fit.misfit (CheckError.typeMismatch .int u))
  set s
  recheckLocs prog (← reads)
  throw (fit.misfit (CheckError.noMatchingInit .int))

end MojoGrimoire.Check
