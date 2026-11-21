import MojoGrimoire.Check.Errors

/-!
The types and constant values of operators, which the checker gives the
operands of a unary or a binary operator, and the indices that Mojo
computes when it compiles the program. The type of a binary operator's
result, whatever its operands, is also what inference gives it.
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
