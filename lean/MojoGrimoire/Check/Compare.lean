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
type of the right operand, unless that is a literal too or its
comparison does not conform (`convertsTo`, `literalFits`, `operandFit`).
Inference gives a literal that fits that type, and the checker checks
one on the right against the parameter of the method (`rightParam`). One
that does not fit is a type mismatch, found before the operands are
read. A comparison with a literal that holds a place whose value is not
implicitly copyable or one with `List[u]()`, keeps the checks it had
before #166 (`keepsBefore`): the compiler builds the literal, and copies
the place, in an order against its conversion that waits for #96. A
literal on the left that holds an inner literal of another length than
one where an `Int` is expected is not converted: the order of SIMD's
failure and the reads waits for #96. An element type that holds a struct
waits for its conformances (#194), and a literal that would initialize a
`Bool` for #165: those comparisons keep the checks they had before #166.
A list of structs compared with an empty literal, `List[P]() == []`, is
a type mismatch where the compiler gives `violatedConstraint` (#194).
So is a `Bool` compared with one, on both paths (`boolLiteralMisfit`).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

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
A list compared with `<`, which it lacks, converts no literal. A literal
on the left, when `left` holds, is converted only when the comparison of
`t` also conforms: beside an array of lists ordered, it keeps its own
type, and the right operand is converted to it. -/
def convertsTo (op : BinOp) (t : Ty) (left : Bool := false) : Bool :=
  (if left then seqCompare op t == some true else (seqCompare op t).isSome) &&
    (t matches .array .. || op == .eq || op == .ne)

mutual
/-- Whether the literal `e` fits the type `t`, as the compiler converts a
literal compared with an array or a list to that operand's type, element
by element, as a call converts its argument (#166): an array of `n`
elements of `u` takes `n` elements that each fit `u`, a list of `u` any
number of them, and an `Int`, whose initializer from a literal takes
`Int`s (#103), any number of elements that fit `Int`, its length checked
later (#170). Any other operand fits only its own type, which `leafTy`
gives, and so does a literal that has a type, such as `List[u]()` or one
that inference typed. A literal fits no other type, but one that would
initialize a `Bool` is left to #165, and an operand whose type `leafTy`
does not give is not known: both are `none`. So is, when `left` holds,
an inner literal of another length than one where an `Int` is expected:
the order of the compiler's failure of SIMD's constraint and of the reads
waits for #96, and a literal on the left that holds one keeps the checks
it had before #166. -/
def literalFits {m : Type → Type} [Monad m] (leafTy : Expr → m (Option Ty)) (left : Bool)
    (t : Ty) : Expr → m (Option Bool)
  | .list .unknown es => match t with
    | .array u n => if es.length == n then elemsFit leafTy left u es else pure (some false)
    | .list u => elemsFit leafTy left u es
    | .int => if left && es.length != 1 then pure none else elemsFit leafTy left .int es
    | .bool => pure none
    | _ => pure (some false)
  | .list u _ => pure (some (u == t))
  | e => do pure ((← leafTy e).map (· == t))

/-- Whether each of the elements `es` fits the type `u` (`literalFits`):
`some false` when one does not, `none` when one is not known. -/
def elemsFit {m : Type → Type} [Monad m] (leafTy : Expr → m (Option Ty)) (left : Bool)
    (u : Ty) : List Expr → m (Option Bool)
  | [] => pure (some true)
  | e :: es => do
    let r ← literalFits leafTy left u e
    let rs ← elemsFit leafTy left u es
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

/-- How the literal operand `e` of the comparison `op`, on the left when
`left` holds, fits the type `t` of its other operand, once the operands'
forms give it (`literalFits`, from `operandTy`); `none` when `e` is no
literal or the comparison converts none to `t` (`convertsTo`). -/
def operandFit (prog : Program) (op : BinOp) (e : Expr) (t : Option Ty) (left := false) :
    CheckM (Option (Option Bool)) := do
  match e, t with
  | .list .., some t =>
    if compares op && convertsTo op t left then pure (some (← literalFits (operandTy prog) left t e))
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

mutual
/-- The places that the literal `e` holds, in order, also in a literal it
holds. -/
def literalPlaces : Expr → List Place
  | .list _ es => placesOf es
  | .place p => [p]
  | _ => []

/-- The places that the expressions `es` are or hold (`literalPlaces`). -/
def placesOf : List Expr → List Place
  | [] => []
  | e :: es => literalPlaces e ++ placesOf es
end

/-- Whether the literal `e` holds, at any depth, a place whose value is not
implicitly copyable (`literalPlaces`). -/
def heldCopy (prog : Program) (e : Expr) : CheckM Bool := do
  unless e matches .list .. do return false
  for p in literalPlaces e do
    if let some t ← operandTy prog (.place p) then
      if copyingOf prog t != .implicit then return true
  pure false

/-- Whether the expression `e` is an empty list built by `List[u]()`, which
the parser gives as a literal of its type; inference gives that form to
an empty literal it types as a list, too. -/
def emptyList : Expr → Bool
  | .list (.list _) [] => true
  | _ => false

/-- Whether the comparison `op` of `a` and `b` keeps the checks it had
before #166 (`Before`): when either operand is a literal that holds a
place whose value is not implicitly copyable (`heldCopy`), or an empty
list built by `List[u]()`, which is no literal that the compiler
converts (`emptyList`). The compiler builds such a literal, and copies
the place, in an order against its conversion and its misfit that waits
for #96. In a program checked as `main` did (`Program.mainMode`), every
comparison keeps them. -/
def keepsBefore (prog : Program) (op : BinOp) (a b : Expr) : CheckM Bool := do
  pure (compares op && (prog.mainMode ||
    emptyList a || emptyList b || (← heldCopy prog a) || (← heldCopy prog b)))

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

namespace Before

/-- Whether the expression `e` is an open literal that holds a literal. -/
def holdsLiteral : Expr → Bool
  | .list .unknown es => es.any (· matches .list ..)
  | _ => false

/-- Whether the comparison `op` of `a` and `b`, of types `ta` and `tb`
found from their forms, has a literal that the compiler converts to the
other operand's type: one that holds a literal, with types not known to
be the same, or one with no type compared with a list. -/
def convertsLiteral (op : BinOp) (a b : Expr) (ta tb : Option Ty) : Bool :=
  compares op && ((holdsLiteral a || holdsLiteral b) && (ta.isNone || ta != tb) ||
    a matches .list .unknown _ && tb matches some (.list _) ||
    b matches .list .unknown _ && ta matches some (.list _))

/-- The error of `op` that the forms of `a` and `b` give (`operandTy`, or
`formTy` when given: `main`'s typing in the bridge to its order of #191,
temporary, until #96 part 4), before #166's conversions: an integer
literal's comparison with an array or a list is left to its overloads,
an empty literal with no type compared with an array has no type that
fits it, and a literal that the compiler converts (`convertsLiteral`) is
left to the checks that follow. -/
def operandMisfit (prog : Program) (op : BinOp) (a b : Expr)
    (formTy : Expr → CheckM (Option Ty) := operandTy prog) : CheckM (Option CheckError) := do
  let formTy := if op == .and || op == .or then lackingTy prog formTy else formTy
  let ta ← if intLiteral a then pure none else formTy a
  let tb ← if compares op && b matches .list .unknown [] then pure (some .unknown)
    else formTy b
  let tb := if convertsLiteral op a b ta tb then none else tb
  pure (binaryMisfit prog op ta tb <|> boolLiteralMisfit op ta b)

/-- Whether the operand `e` of `op` is passed by reference, before #166's
conversions: not beside a literal that the compiler converts. -/
def byRef (prog : Program) (op : BinOp) (e other : Expr) : CheckM Bool := do
  if !compares op then return false
  let t ← operandTy prog e
  if convertsLiteral op e other t (← operandTy prog other) then return false
  pure (t.bind (seqCompare op)).isSome

/-- The parameter that the right operand `b` is checked against, before
#166's conversions: only a list's `other` of `==` and `!=`. -/
def rightParam (op : BinOp) (a b : Expr) (ta : Ty) : Option (Fit × Param) :=
  if intLiteral a && op != .and && op != .or then
    some (.overload (binaryMethod op), ⟨.read, "rhs", .int⟩)
  else if (op == .eq || op == .ne) && ta matches .list _ && b matches .list (.list _) _ then
    some (.call, ⟨.read, "other", ta⟩)
  else none

end Before

/-- The error of the operator `op` that the forms of its operands `a` and
`b` give (`operandTy`), before they are read (`binaryMisfit`). A literal
on the left of a comparison is converted to the type of the right
operand, unless that is a literal too, and a literal on the right to the
type of the left one (`operandFit`), as the compiler converts the
argument of the method: one that does not fit is a type mismatch, but a
literal on the left with no type of its own, which the compiler reports
as a list it cannot type, keeps the checks it had before. A comparison
with a literal that holds a place whose value is not implicitly copyable
keeps them all (`keepsBefore`), and so does any other operator, which
#166 does not change (`Before.operandMisfit`). An integer literal's
comparison with an array or a list is left to its overloads. `formTy`
gives the forms' types, `operandTy`'s, or `main`'s typing in the bridge
to its order of #191 (`mainFormTy`). -/
def operandMisfit (prog : Program) (op : BinOp) (a b : Expr)
    (formTy : Expr → CheckM (Option Ty) := operandTy prog) : CheckM (Option CheckError) := do
  if !compares op || (← keepsBefore prog op a b) then
    return ← Before.operandMisfit prog op a b formTy
  let ta ← if intLiteral a then pure none else formTy a
  let tb ← formTy b
  let fa ← if b matches .list .. then pure none else operandFit prog op a tb true
  let ta' := fitTy fa tb ta
  let fb ← operandFit prog op b ta'
  if fa == some (some false) && ta.isSome || fb == some (some false) then
    return some (.typeMismatch (ta'.getD .unknown) (tb.getD .unknown))
  pure (binaryMisfit prog op (if fa == some (some false) then none else ta') (fitTy fb ta' tb) <|>
    boolLiteralMisfit op ta b)

/-- Whether the operand `e` of the operator `op`, whose other operand is
`other`, is passed by reference, uncopied, as the comparisons of `Array`
and `List` take a `read` argument: a place, or a call that returns a
reference, compared as an array or a list (`seqCompare`). Beside a
literal `other` whose fit is not known, and which inference left
untyped, a list, or an array when `other` holds a literal, keeps the
checks it had before #166, a copy. `left` holds when `other` is on the
left. -/
def byRef (prog : Program) (op : BinOp) (e other : Expr) (left := false) : CheckM Bool := do
  if !compares op then return false
  if ← keepsBefore prog op e other then return ← Before.byRef prog op e other
  let t ← operandTy prog e
  if (← operandFit prog op other t left) == some none && literalTy other != t &&
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

/-- The parameter that the right operand `b` of the operator `op` is
checked against, given the type of `a`: `rightParam`, or the one it had
before #166 when the comparison keeps those checks (`keepsBefore`). That
is decided before `a` is read. -/
def rightParamOf (prog : Program) (op : BinOp) (a b : Expr) :
    CheckM (Ty → Option (Fit × Param)) := do
  pure ((if ← keepsBefore prog op a b then Before.rightParam else rightParam) op a b)

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
