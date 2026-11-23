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

A literal on the right of a list is the argument of the list's `__eq__`
or `__ne__`, converted to the list's type as a call's argument is: inference gives
it that type, and the checker checks it against that parameter
(`rightParam`). An element type that holds a struct waits for its
conformances (#194), and any other literal that the compiler converts to
the other operand's type, on the left of a list or holding a literal, for
part 2 of #166 (`convertsLiteral`): such comparisons stay rejected, with
a class that is still not the compiler's. A list of structs compared
with an empty literal, `List[P]() == []`, is now a type mismatch where it
was `invalidType`, since the literal takes the list's type; the compiler
gives `violatedConstraint` (#194).
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

/-- Whether the expression `e` is a literal that holds a literal. -/
def holdsLiteral : Expr → Bool
  | .list .unknown es => es.any (· matches .list ..)
  | _ => false

/-- Whether the comparison `op` of `a` and `b`, of types `ta` and `tb`
found from their forms, has a literal that the compiler converts to the
other operand's type, which part 2 of #166 models: one that holds a
literal, with types not known to be the same, or one with no type
compared with a list. Until then the comparison keeps the checks it had
before #166. -/
def convertsLiteral (op : BinOp) (a b : Expr) (ta tb : Option Ty) : Bool :=
  compares op && ((holdsLiteral a || holdsLiteral b) && (ta.isNone || ta != tb) ||
    a matches .list .unknown _ && tb matches some (.list _) ||
    b matches .list .unknown _ && ta matches some (.list _))

/-- Whether the operand `e` is a binary operation, under the drops that
the elaborator adds: in an operand of struct type, a nested test of `and`
or `or`, never a place nor a call. -/
def nestedTest : Expr → Bool
  | .binary .. => true
  | .withDrops e _ _ => nestedTest e
  | _ => false

/-- The type of the operand `e` of `and` or `or` found by `formTy`, as far
as the operator's misfit needs it (`binaryMisfit`): a type that lacks
`__bool__`, such as a struct without it, an array or `None`, and else
`none`. A nested test gives such a type only when both of its operands
give it, so its operand that is no test is asked first: when that gives
none, `lackingTy` gives none at once, and `formTy` does not go down the
whole test, which at each level of a chain would go down the rest of
it. -/
def lackingTy (prog : Program) (formTy : Expr → CheckM (Option Ty)) (e : Expr) :
    CheckM (Option Ty) := do
  unless ← candidate e do return none
  pure (lacking (← formTy e))
where
  /-- The type `t` when it lacks `__bool__`. -/
  lacking (t : Option Ty) : Option Ty := if (lacks prog "__bool__" t).isSome then t else none
  /-- Whether the form of `e` may give a type that lacks `__bool__`. -/
  candidate : Expr → CheckM Bool
    | .binary op a b => do
      unless op == .and || op == .or do return (lacking (← formTy (.binary op a b))).isSome
      if nestedTest b then
        unless ← candidate a do return false
        candidate b
      else
        unless ← candidate b do return false
        candidate a
    | .withDrops e _ _ => candidate e
    | e => do pure (lacking (← formTy e)).isSome

/-- The error of the operator `op` that the forms of its operands `a` and
`b` give (`operandTy`, or `formTy` when given: `main`'s typing in the
bridge to its order, temporary, until #96 part 4), before they are read
(`binaryMisfit`). An integer
literal's comparison with an array or a list is left to its overloads,
and an empty literal with no type compared with an array has no type
that fits it. A literal that the compiler converts (`convertsLiteral`) is
left to the checks that follow, as before #166. -/
def operandMisfit (prog : Program) (op : BinOp) (a b : Expr)
    (formTy : Expr → CheckM (Option Ty) := operandTy prog) : CheckM (Option CheckError) := do
  let formTy := if op == .and || op == .or then lackingTy prog formTy else formTy
  let ta ← if intLiteral a then pure none else formTy a
  let tb ← if compares op && b matches .list .unknown [] then pure (some .unknown)
    else formTy b
  let tb := if convertsLiteral op a b ta tb then none else tb
  pure (binaryMisfit prog op ta tb)

/-- Whether the operand `e` of the operator `op`, whose other operand is
`other`, is passed by reference, uncopied, as the comparisons of `Array`
and `List` take a `read` argument: a place, or a call that returns a
reference, compared as an array or a list (`seqCompare`), unless a
literal is converted (`convertsLiteral`). -/
def byRef (prog : Program) (op : BinOp) (e other : Expr) : CheckM Bool := do
  if !compares op then return false
  let t ← operandTy prog e
  if convertsLiteral op e other t (← operandTy prog other) then return false
  pure (t.bind (seqCompare op)).isSome

/-- The parameter, with the fit of its call, that the right operand `b`
of the operator `op` is checked against as an argument, when it is one,
given the left operand `a` of type `ta`: an integer literal's operators
take an `Int` `rhs` and have several overloads (`noMatchingMethod`), and
a list's `__eq__` and `__ne__` take an `other` of the list's type, to
which a literal on the right is converted. Inference gives such a literal
that type. -/
def rightParam (op : BinOp) (a b : Expr) (ta : Ty) : Option (Fit × Param) :=
  if intLiteral a && op != .and && op != .or then
    some (.overload (binaryMethod op), ⟨.read, "rhs", .int⟩)
  else if (op == .eq || op == .ne) && ta matches .list _ && b matches .list (.list _) _ then
    some (.call, ⟨.read, "other", ta⟩)
  else none

/-- The type of the result of the operator `op` on operands of types `ta`
and `tb`: a method that a type lacks first, or the misfit of a comparison
of arrays or lists, then a `Bool` for such a comparison, and `binaryTy`
for any other. `and` and `or` on operands of the same struct type, which
has `__bool__`, give the operand that decides, of that type (#191). -/
def methodBinaryTy (prog : Program) (op : BinOp) (ta tb : Ty) : Except CheckError Ty :=
  match binaryMisfit prog op (some ta) (some tb) with
  | some err => throw err
  | none =>
    if (op == .and || op == .or) && ta == tb && ta matches .struct _ then pure ta
    else if (seqCompare op ta).isSome then pure .bool else binaryTy op ta tb

end MojoGrimoire.Check
