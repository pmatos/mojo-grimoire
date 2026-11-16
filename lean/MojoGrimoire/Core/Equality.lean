import MojoGrimoire.Core.Syntax

/-!
Equality of places, expressions and statements, as a test that two terms are the
same tree. Lean's derived equality would be partial on these types, because
they nest lists of themselves, and the build accepts no partial code
(ADR-2026-11-15-1906), so it is written here by structural recursion.
-/

namespace MojoGrimoire.Core

mutual
/-- Whether two places are the same tree. -/
def Place.beq : Place → Place → Bool
  | .var x, .var y => x == y
  | .field p f, .field q g => Place.beq p q && f == g
  | .index p i, .index q j => Place.beq p q && Expr.beq i j
  | .transferred p, .transferred q => Place.beq p q
  | _, _ => false
termination_by structural p => p

/-- Whether two expressions are the same tree. -/
def Expr.beq : Expr → Expr → Bool
  | .int a, .int b => a == b
  | .bool a, .bool b => a == b
  | .str a, .str b => a == b
  | .place p, .place q => Place.beq p q
  | .transfer p, .transfer q => Place.beq p q
  | .copy p, .copy q => Place.beq p q
  | .call f as, .call g bs => f == g && Expr.beqList as bs
  | .method p m as, .method q n bs => Place.beq p q && m == n && Expr.beqList as bs
  | .unary o a, .unary p b => o == p && Expr.beq a b
  | .binary o a b, .binary p c d => o == p && Expr.beq a c && Expr.beq b d
  | .list t as, .list u bs => t == u && Expr.beqList as bs
  | .listInit t as, .listInit u bs => t == u && Expr.beqList as bs
  | .withDrops a ps qs, .withDrops b rs ss =>
    Expr.beq a b && Place.beqList ps rs && Place.beqList qs ss
  | _, _ => false

/-- Whether two lists of places are the same, element by element. -/
def Place.beqList : List Place → List Place → Bool
  | [], [] => true
  | p :: ps, q :: qs => Place.beq p q && Place.beqList ps qs
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

instance instBEqPlace : BEq Place := ⟨Place.beq⟩

instance instBEqExpr : BEq Expr := ⟨Expr.beq⟩

mutual
/-- Whether two statements are the same tree. -/
def Stmt.beq : Stmt → Stmt → Bool
  | .pass, .pass => true
  | .decl x t e, .decl y u f => x == y && t == u && Expr.beqOption e f
  | .refDecl x e, .refDecl y f => x == y && Expr.beq e f
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
