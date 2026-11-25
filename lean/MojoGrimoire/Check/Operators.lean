import MojoGrimoire.Check.Errors

/-!
The types and constant values of operators, which the checker gives the
operands of a unary or a binary operator, and the indices that Mojo
computes when it compiles the program. The type of a binary operator's
result, whatever its operands, is also what inference gives it. A `Bool`
compared with an empty literal is a type mismatch, found from the forms
of the operands before they are read (#286).
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The type of the result of the operator `op` on operands of types `a` and
`b`. -/
def binaryTy (op : BinOp) (a b : Ty) : Except CheckError Ty :=
  match op with
  | .add | .sub | .mul | .floorDiv | .mod => do
    unless a == .int do throw (.typeMismatch .int a)
    unless b == .int do throw (.typeMismatch .int b)
    pure .int
  | .lt | .le | .gt | .ge | .eq | .ne => do
    unless a == .int || a == .bool do throw (.typeMismatch .int a)
    unless b == a do throw (.typeMismatch a b)
    pure .bool
  | .and | .or => do
    unless a == .bool do throw (.typeMismatch .bool a)
    unless b == .bool do throw (.typeMismatch .bool b)
    pure .bool

/-- Whether the operator `op` compares: `<`, `<=`, `>`, `>=`, `==` or
`!=`. -/
def compares (op : BinOp) : Bool :=
  op matches .lt | .le | .gt | .ge | .eq | .ne

/-- The error of the comparison `op` of an operand of type `ta` with the
right operand `b`, found before they are read: an empty literal with no
type beside a `Bool` is the argument `rhs` of the `Bool`'s method, which
the compiler cannot convert to a `Bool`, a type mismatch (#286). A
literal with typed elements tries `Bool`'s initializers instead (#165),
and one made only of empty literals waits for #300. -/
def boolLiteralMisfit (op : BinOp) (ta : Option Ty) (b : Expr) : Option CheckError :=
  if compares op && ta == some .bool &&
      b matches .list .unknown [] then some (.typeMismatch .bool .unknown)
  else none

/-- The type of the result of the binary operator `op`, whatever its
operands: an `Int` for arithmetic, and a `Bool` for any other. -/
def binaryResult : BinOp → Ty
  | .add | .sub | .mul | .floorDiv | .mod => .int
  | _ => .bool

/-- The type of the result of the operator `op` on an operand of type `a`. -/
def unaryTy (op : UnOp) (a : Ty) : Except CheckError Ty :=
  match op with
  | .neg => if a == .int then pure .int else throw (.typeMismatch .int a)
  | .not => if a == .bool then pure .bool else throw (.typeMismatch .bool a)

/-- The value of an index made only of integer literals, negation, `+`, `-`,
`*`, `//` and `%`: Mojo computes it when it compiles the program, with
`BinOp.arith`, as the interpreter does at run time. -/
def constInt : Expr → Option Int
  | .int k => some k
  | .unary .neg a => (constInt a).map (- ·)
  | .binary op a b => do
    let f ← op.arith
    pure (f (← constInt a) (← constInt b))
  | _ => none

end MojoGrimoire.Check
