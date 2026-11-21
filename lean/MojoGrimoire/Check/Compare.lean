import MojoGrimoire.Check.Methods

/-!
The comparisons of arrays and of lists, and the misfits of a binary
operator found from the types of its operands (#166, #185).

Two arrays compare with `<`, `<=`, `>`, `>=`, `==` and `!=`, which `Array`
declares, and two lists with `==` and `!=`, which `List` declares, when
they have the same type and their element type conforms to `Comparable`,
or for `==` and `!=` to `Equatable`: `Int`, `Bool`, arrays of them and,
for `==` and `!=`, lists of them (`seqCompare`). Each operand is passed
by reference, as these methods take a `read` argument: a place is read,
uncopied (`byRef`). Another type is a type mismatch, found from the
operands' types, as an `Int` or a `Bool` compared with an array or a list
is; an element type that does not conform, `None` or, to order them, a
list, is the compiler's "violated constraint", `violatedConstraint`,
found the same way. A list has no order: it lacks the methods
(`missingMethod`).

A literal operand is converted to the type of the other operand, element
by element, as a call converts its argument (#166, #185): a literal on
the right to the type of the left operand, and one on the left to the
type of the right operand, unless that is a literal too (`literalFits`,
`operandFit`). Inference gives a literal that fits that type, and the
checker checks one on the right against the parameter of the method
(`rightParam`). One that does not fit is a type mismatch, found before
the operands are read. An element type that holds a struct waits for its
conformances (#194), and a literal that would initialize a `Bool` for
#165: those comparisons keep the checks they had before #166. A list of
structs compared with an empty literal, `List[P]() == []`, is a type
mismatch where the compiler gives `violatedConstraint` (#194).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether the operator `op` compares: `<`, `<=`, `>`, `>=`, `==` or
`!=`. -/
def compares (op : BinOp) : Bool :=
  op matches .lt | .le | .gt | .ge | .eq | .ne

/-- Whether the comparison `op` of two arrays, or two lists, of type `t` is
modelled, and then whether `t`'s element type conforms to the trait that
`op` needs: `Comparable` to order, `Equatable` for `==` and `!=`. `Int`,
`Bool` and arrays of them conform, and lists of them for `==` and `!=`;
`None` does not. A list has no order: it lacks the methods (`hasMethod`),
and does not conform as an element. An element type that holds a struct
is not modelled yet (#194). -/
def seqCompare (op : BinOp) : Ty → Option Bool
  | t@(.array u _) | t@(.list u) => if modelled u then conforms t else none
  | _ => none
where
  /-- Whether the comparison of a sequence of elements of type `u` is
  modelled. -/
  modelled (u : Ty) : Bool := compares op && !(elemBase u matches .struct _)
  /-- Whether the element type `u` conforms, when that is modelled. -/
  conforms : Ty → Option Bool
    | .int | .bool => some true
    | .array u _ => conforms u
    | .list u => if op == .eq || op == .ne then conforms u else some false
    | .noneType => some false
    | _ => none

/-- The error of the comparison `op` of operands of types `ta` and `tb`,
when one is an array or a list whose comparison is modelled
(`seqCompare`): a type mismatch when the other is of another type, as the
compiler cannot convert it, the left one such a sequence, an `Int` or a
`Bool`, then `violatedConstraint` when their element type does not
conform. -/
def seqMisfit (op : BinOp) : Option Ty → Option Ty → Option CheckError
  | some ta, some tb =>
    match seqCompare op ta, seqCompare op tb with
    | some ok, _ =>
      if ta != tb then some (.typeMismatch ta tb)
      else if ok then none else some (.violatedConstraint ta (binaryMethod op))
    | none, some _ => if ta == .int || ta == .bool then some (.typeMismatch ta tb) else none
    | none, none => none
  | _, _ => none

/-- The error of the operator `op` that the types `ta` and `tb` of its
operands give, when they are known: the method that the left operand's
type lacks, or, for `and` and `or`, `__bool__` that the right one's
lacks, then the misfit of a comparison of arrays or lists (`seqMisfit`). -/
def binaryMisfit (prog : Program) (op : BinOp) (ta tb : Option Ty) : Option CheckError :=
  lacks prog (binaryMethod op) ta <|>
    (if op == .and || op == .or then lacks prog (binaryMethod op) tb else none) <|>
    seqMisfit op ta tb

/-- Whether the comparison `op` converts a literal operand to the type `t`
of its other operand: an array whose comparison is modelled
(`seqCompare`), or a list for `==` and `!=`, the methods a list declares.
A list compared with `<`, which it lacks, converts no literal. -/
def convertsTo (op : BinOp) (t : Ty) : Bool :=
  (seqCompare op t).isSome && (t matches .array .. || op == .eq || op == .ne)

mutual
/-- Whether the literal `e` fits the type `t`, as the compiler converts a
literal compared with an array or a list to that operand's type, element
by element, as a call converts its argument (#166): an array of `n`
elements of `u` takes `n` elements that each fit `u`, a list of `u` any
number of them, and an `Int`, whose initializer from a literal takes
`Int`s (#103), any number of elements that fit `Int`, its length checked
later (#170). Any other operand fits only its own type, which `leafTy`
gives. A literal fits no other type, but one that would initialize a
`Bool` is left to #165, and an operand whose type `leafTy` does not give
is not known: both are `none`. -/
def literalFits {m : Type → Type} [Monad m] (leafTy : Expr → m (Option Ty)) (t : Ty) :
    Expr → m (Option Bool)
  | .list _ es => match t with
    | .array u n => if es.length == n then elemsFit leafTy u es else pure (some false)
    | .list u => elemsFit leafTy u es
    | .int => elemsFit leafTy .int es
    | .bool => pure none
    | _ => pure (some false)
  | e => do pure ((← leafTy e).map (· == t))

/-- Whether each of the elements `es` fits the type `u` (`literalFits`):
`some false` when one does not, `none` when one is not known. -/
def elemsFit {m : Type → Type} [Monad m] (leafTy : Expr → m (Option Ty)) (u : Ty) :
    List Expr → m (Option Bool)
  | [] => pure (some true)
  | e :: es => do
    let r ← literalFits leafTy u e
    let rs ← elemsFit leafTy u es
    pure (match r, rs with
      | some false, _ | _, some false => some false
      | some true, some true => some true
      | _, _ => none)
end

/-- The type that inference gave the literal `e`; none for any other
expression. -/
def literalTy : Expr → Option Ty
  | .list u _ => some u
  | _ => none

/-- Whether the expression `e` is a literal that holds a literal. -/
def holdsLiteral : Expr → Bool
  | .list _ es => es.any (· matches .list ..)
  | _ => false

/-- How the literal operand `e` of the comparison `op` fits the type `t`
of its other operand, once the operands' forms give it (`literalFits`,
from `operandTy`); `none` when `e` is no literal or the comparison
converts none to `t` (`convertsTo`). -/
def operandFit (prog : Program) (op : BinOp) (e : Expr) (t : Option Ty) :
    CheckM (Option (Option Bool)) := do
  match e, t with
  | .list .., some t =>
    if compares op && convertsTo op t then pure (some (← literalFits (operandTy prog) t e))
    else pure none
  | _, _ => pure none

/-- The type that the operand `e` of the comparison `op` has, from its
form `te`, once a literal is converted to the type `t` of the other
operand (`operandFit`): `t` when it fits, and none when its fit is not
known, so that no misfit is found from it. -/
def fitTy (fit : Option (Option Bool)) (t te : Option Ty) : Option Ty :=
  match fit with
  | some (some true) => t
  | some none => none
  | _ => te

/-- The error of the operator `op` that the forms of its operands `a` and
`b` give (`operandTy`), before they are read (`binaryMisfit`). A literal
on the left of a comparison is converted to the type of the right
operand, unless that is a literal too, and a literal on the right to the
type of the left one (`operandFit`), as the compiler converts the
argument of the method: one that does not fit is a type mismatch, but a
literal on the left with no type of its own, which the compiler reports
as a list it cannot type, keeps the checks it had before. An integer
literal's comparison with an array or a list is left to its overloads. -/
def operandMisfit (prog : Program) (op : BinOp) (a b : Expr) : CheckM (Option CheckError) := do
  let ta ← if intLiteral a then pure none else operandTy prog a
  let tb ← operandTy prog b
  let fa ← if b matches .list .. then pure none else operandFit prog op a tb
  let ta' := fitTy fa tb ta
  let fb ← operandFit prog op b ta'
  if fa == some (some false) && ta.isSome || fb == some (some false) then
    return some (.typeMismatch (ta'.getD .unknown) (tb.getD .unknown))
  pure (binaryMisfit prog op (if fa == some (some false) then none else ta') (fitTy fb ta' tb))

/-- Whether the operand `e` of the operator `op`, whose other operand is
`other`, is passed by reference, uncopied, as the comparisons of `Array`
and `List` take a `read` argument: a place, or a call that returns a
reference, compared as an array or a list (`seqCompare`). Beside a
literal `other` whose fit is not known, and which inference left
untyped, a list, or an array when `other` holds a literal, keeps the
checks it had before #166, a copy. -/
def byRef (prog : Program) (op : BinOp) (e other : Expr) : CheckM Bool := do
  if !compares op then return false
  let t ← operandTy prog e
  if (← operandFit prog op other t) == some none && literalTy other != t &&
      (holdsLiteral other || t matches some (.list _)) then
    return false
  pure (t.bind (seqCompare op)).isSome

/-- The parameter, with the fit of its call, that the right operand `b`
of the operator `op` is checked against as an argument, when it is one,
given the left operand `a` of type `ta`: an integer literal's operators
take an `Int` `rhs` and have several overloads (`noMatchingMethod`), and
the comparisons of an array or a list take an `other` of its type, to
which a literal on the right is converted (`convertsTo`). Inference gives
such a literal that type. -/
def rightParam (op : BinOp) (a b : Expr) (ta : Ty) : Option (Fit × Param) :=
  if intLiteral a && op != .and && op != .or then
    some (.overload (binaryMethod op), ⟨.read, "rhs", .int⟩)
  else if convertsTo op ta && literalTy b == some ta then
    some (.call, ⟨.read, "other", ta⟩)
  else none

/-- The type of the result of the operator `op` on operands of types `ta`
and `tb`: a method that a type lacks first, or the misfit of a comparison
of arrays or lists, then a `Bool` for such a comparison, and `binaryTy`
for any other. -/
def methodBinaryTy (prog : Program) (op : BinOp) (ta tb : Ty) : Except CheckError Ty :=
  match binaryMisfit prog op (some ta) (some tb) with
  | some err => throw err
  | none => if (seqCompare op ta).isSome then pure .bool else binaryTy op ta tb

end MojoGrimoire.Check
