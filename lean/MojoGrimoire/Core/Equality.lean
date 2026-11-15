import MojoGrimoire.Core.Syntax

/-!
Equality of expressions and statements, as a test that two terms are the
same tree. Lean's derived equality would be partial on these types, because
they nest lists of themselves, and the build accepts no partial code
(ADR-2026-11-15-1906), so it is written here by structural recursion.
-/

namespace MojoGrimoire.Core

mutual
/-- Whether two expressions are the same tree. -/
def Expr.beq : Expr → Expr → Bool
  | .int a, .int b => a == b
  | .bool a, .bool b => a == b
  | .str a, .str b => a == b
  | .place p, .place q => p == q
  | .transfer p, .transfer q => p == q
  | .copy p, .copy q => p == q
  | .call f as, .call g bs => f == g && Expr.beqList as bs
  | .method p m as, .method q n bs => p == q && m == n && Expr.beqList as bs
  | .unary o a, .unary p b => o == p && Expr.beq a b
  | .binary o a b, .binary p c d => o == p && Expr.beq a c && Expr.beq b d
  | _, _ => false

/-- Whether two lists of expressions are the same, element by element. -/
def Expr.beqList : List Expr → List Expr → Bool
  | [], [] => true
  | a :: as, b :: bs => Expr.beq a b && Expr.beqList as bs
  | _, _ => false
end

/-- Whether two optional expressions are both absent, or the same. -/
def Expr.beqOption : Option Expr → Option Expr → Bool
  | none, none => true
  | some a, some b => Expr.beq a b
  | _, _ => false

instance instBEqExpr : BEq Expr := ⟨Expr.beq⟩

mutual
/-- Whether two statements are the same tree. -/
def Stmt.beq : Stmt → Stmt → Bool
  | .pass, .pass => true
  | .decl x t e, .decl y u f => x == y && t == u && Expr.beqOption e f
  | .assign p e, .assign q f => p == q && Expr.beq e f
  | .expr e, .expr f => Expr.beq e f
  | .print as, .print bs => Expr.beqList as bs
  | .ifElse c t e, .ifElse d u f => Expr.beq c d && Stmt.beqList t u && Stmt.beqList e f
  | .whileLoop c b, .whileLoop d e => Expr.beq c d && Stmt.beqList b e
  | .ret e, .ret f => Expr.beqOption e f
  | .drop p, .drop q => p == q
  | _, _ => false

/-- Whether two blocks are the same, statement by statement. -/
def Stmt.beqList : List Stmt → List Stmt → Bool
  | [], [] => true
  | a :: as, b :: bs => Stmt.beq a b && Stmt.beqList as bs
  | _, _ => false
end

instance instBEqStmt : BEq Stmt := ⟨Stmt.beq⟩

end MojoGrimoire.Core
