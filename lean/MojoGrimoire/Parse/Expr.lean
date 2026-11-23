import MojoGrimoire.Parse.Parser

/-!
The parsing of expressions, with Mojo's precedence, loosest first: `or`,
`and`, `not`, comparisons, `+` and `-`, `*`, `//` and `%`, unary `-`, and
then the postfix forms of a primary expression.

A postfix chain starts from a primary expression. From a name, it stays a
place while it reads fields and indices; `x^`, `x.copy()`, a method call
`x.m(…)` and a call `f(…)` make it an expression. `x^` followed by `.`
stays a place, `transferred x`, whose fields and methods the chain goes on
to read: the compiler reads `x^.f` as the field `f` of `x`, which it
borrows, and `x^.m(…)` as a call on `x` that takes it only for a method
whose `self` is `var`. The type of a literal `[…]` is left for
inference, and `List[T]()` is an empty list of `T`, where `T` is a type
argument (`typeArgument`), so `List[None]` is not a list of `None`. `List[T](e₁, …, eₙ)`
with arguments is read as a call of `List`'s initializer, which the checker
accepts only for one argument, a list or an array of `T` that it copies
(#103), or a call of the standard library's `range` (#121), and rejects
otherwise (#46). The compiler also accepts other iterables, which are
outside the subset.

`^` is also binary XOR, which is outside the subset. As in the compiler,
`^` after a term is XOR when the next token of the logical line can start
an expression and is not `.`, and a transfer otherwise.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- What a postfix chain has read so far: a place, or an expression. -/
inductive Term where
  | place (p : Place)
  | expr (e : Expr)

/-- The expression a term stands for: a place used as a value. -/
def Term.toExpr : Term → Expr
  | .place p => .place p
  | .expr e => e

/-- The comparison operators. -/
def compOps : List (String × BinOp) :=
  [("<", .lt), ("<=", .le), (">", .gt), (">=", .ge), ("==", .eq), ("!=", .ne)]

/-- The additive operators. -/
def addOps : List (String × BinOp) := [("+", .add), ("-", .sub)]

/-- The multiplicative operators. -/
def mulOps : List (String × BinOp) := [("*", .mul), ("//", .floorDiv), ("%", .mod)]

/-- The operator among `ops` that the next token is, read if it is there. -/
def acceptOp (ops : List (String × BinOp)) : P (Option BinOp) := do
  match ← peek with
  | some (.sym s) => match ops.lookup s with
    | some op => let _ ← next; pure (some op)
    | none => pure none
  | _ => pure none

/-- The compiler's keywords that cannot start an expression: those of
`TokenKinds.def` that `isPrimaryExprStart` (`ParserExprs.cpp`) leaves out.
Every other name can. -/
def nonOperandKeywords : List String :=
  ["and", "as", "assert", "break", "case", "class", "continue", "del", "elif", "else",
   "except", "finally", "for", "from", "global", "if", "import", "in", "is", "match",
   "nonlocal", "or", "pass", "raise", "return", "struct", "trait", "try", "while", "with",
   "yield", "__extension", "__mlir_region", "__match", "__enum"]

/-- Whether the token `t` can start an expression, by the compiler's
`isPrimaryExprStart`, less `.`. Of its symbols, the lexer reads only these. -/
def startsOperand : Tok → Bool
  | .int _ | .str _ => true
  | .ident x => !nonOperandKeywords.contains x
  | .sym s => ["+", "-", "*", "(", "[", "=="].contains s
  | .newline | .indent | .dedent => false

mutual
/-- Reads an expression. -/
def expr (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do
    let a ← andExpr n
    orRest n a

/-- Reads the rest of a chain of `or`. -/
def orRest (fuel : Nat) (a : Expr) : P Expr :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    if ← acceptKw "or" then orRest n (.binary .or a (← andExpr n)) else pure a

/-- Reads a chain of `and`. -/
def andExpr (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do
    let a ← notExpr n
    andRest n a

/-- Reads the rest of a chain of `and`. -/
def andRest (fuel : Nat) (a : Expr) : P Expr :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    if ← acceptKw "and" then andRest n (.binary .and a (← notExpr n)) else pure a

/-- Reads `not e`, or a comparison. -/
def notExpr (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do
    if ← acceptKw "not" then pure (.unary .not (← notExpr n))
    else
      let a ← sum n
      match ← acceptOp compOps with
      | some op => pure (.binary op a (← sum n))
      | none => pure a

/-- Reads a sum. -/
def sum (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do sumRest n (← product n)

/-- Reads the rest of a sum. -/
def sumRest (fuel : Nat) (a : Expr) : P Expr :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    match ← acceptOp addOps with
    | some op => sumRest n (.binary op a (← product n))
    | none => pure a

/-- Reads a product. -/
def product (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do productRest n (← unaryExpr n)

/-- Reads the rest of a product. -/
def productRest (fuel : Nat) (a : Expr) : P Expr :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    match ← acceptOp mulOps with
    | some op => productRest n (.binary op a (← unaryExpr n))
    | none => pure a

/-- Reads `-e`, or a postfix chain. A negated integer literal is a negative
literal. -/
def unaryExpr (fuel : Nat) : P Expr :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do
    if ← acceptSym "-" then
      match ← unaryExpr n with
      | .int k => pure (.int (-k))
      | e => pure (.unary .neg e)
    else pure (← chain n).toExpr

/-- Reads a primary expression and its postfix forms. -/
def chain (fuel : Nat) : P Term :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do trailers n (← primary n)

/-- Reads the postfix forms after the term `t`. -/
def trailers (fuel : Nat) (t : Term) : P Term :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    if ← acceptSym "." then
      let f ← memberName
      let .place p := t | fail "a field or method of a value that is not a place"
      if ← acceptSym "(" then
        let args ← exprList n ")"
        if f == "copy" && args.isEmpty then trailers n (.expr (.copy p))
        else trailers n (.expr (.method p f args))
      else trailers n (.place (.field p f))
    else if ← acceptSym "[" then
      let .place p := t | fail "an index into a value that is not a place"
      let i ← expr n
      expectSym "]"
      trailers n (.place (.index p i))
    else if ← acceptSym "^" then
      if (← peek).any startsOperand then fail "a binary `^` (XOR), which is outside the subset"
      let .place p := t | fail "a transfer of a value that is not a place"
      if (← peek) matches some (.sym ".") then trailers n (.place (.transferred p))
      else pure (.expr (.transfer p))
    else if ← acceptSym "(" then
      let .place (.var f) := t | fail "a call of something that is not a name"
      trailers n (.expr (.call f (← exprList n ")")))
    else pure t

/-- Reads a primary expression: a literal, a name, a parenthesized
expression, a list literal, `List[T]()`, or `List[T](e₁, …, eₙ)`. -/
def primary (fuel : Nat) : P Term :=
  match fuel with
  | 0 => fail "an expression too deeply nested"
  | n + 1 => do
    match ← peek with
    | some (.int k) => let _ ← next; pure (.expr (.int k))
    | some (.str s) => let _ ← next; pure (.expr (.str s))
    | some (.ident "True") => let _ ← next; pure (.expr (.bool true))
    | some (.ident "False") => let _ ← next; pure (.expr (.bool false))
    | some (.ident "List") =>
      let _ ← next
      expectSym "["
      let t := typeArgument (← ty n)
      expectSym "]"
      expectSym "("
      match ← exprList n ")" with
      | [] => pure (.expr (.list (.list t) []))
      | args => pure (.expr (.listInit t args))
    | some (.sym "(") =>
      let _ ← next
      let e ← expr n
      expectSym ")"
      pure (.expr e)
    | some (.sym "[") =>
      let _ ← next
      pure (.expr (.list .unknown (← exprList n "]")))
    | _ => pure (.place (.var (← name)))

/-- Reads expressions separated by commas, up to the closing symbol
`close`. -/
def exprList (fuel : Nat) (close : String) : P (List Expr) :=
  match fuel with
  | 0 => fail "a list too long"
  | n + 1 => do
    if ← acceptSym close then pure []
    else
      let e ← expr n
      if ← acceptSym "," then pure (e :: (← exprList n close))
      else
        expectSym close
        pure [e]
end

end MojoGrimoire.Parse
