import MojoGrimoire.Core.Types

/-!
The places, expressions and statements of the core calculus.

A place names a location that holds a value: a variable, a field of a
place, or an element of a list, whose index is an expression. Places are their own syntactic category because Mojo's argument
conventions pass some arguments as locations and others as values: a place
used as an argument is passed as a reference when the parameter's convention
is `read`, `mut` or `ref`, and read as a value otherwise.

Mojo destroys each value as soon as possible, right after its last use.
The core calculus makes destruction explicit with the statement `drop`,
which no Mojo program contains: elaboration inserts it, so that running a
program never has to find a value's last use.
-/

namespace MojoGrimoire.Core

mutual
/-- A place: a variable `x`, a field `p.f` of a place `p`, or the element
`p[i]` of a list. -/
inductive Place where
  | var (name : Name)
  | field (base : Place) (field : Name)
  | index (base : Place) (index : Expr)

/-- The expressions. `place p` uses a place: as a value, which copies it
implicitly, or as a reference argument. `transfer p` is Mojo's `p^`, which
moves the value out of `p`, and `copy p` is Mojo's explicit `p.copy()`.
`call f args` calls the function `f` or, when `f` names a struct,
constructs it, as Mojo's `S(args)` does. `method p m args` calls the method
`m` on the place `p`, Mojo's `p.m(args)`. `list t es` is a list of elements
of type `t`: Mojo's literal `[e₁, …, eₙ]`, or `List[t]()` when it is empty. -/
inductive Expr where
  | int (value : Int)
  | bool (value : Bool)
  | str (value : String)
  | place (p : Place)
  | transfer (p : Place)
  | copy (p : Place)
  | call (callee : Name) (args : List Expr)
  | method (receiver : Place) (name : Name) (args : List Expr)
  | unary (op : UnOp) (arg : Expr)
  | binary (op : BinOp) (lhs rhs : Expr)
  | list (elemTy : Ty) (elems : List Expr)
end

/-- The statements. `decl x t e` is Mojo's `var x: t = e`, or `var x: t`
when `e` is absent. `ifElse` and `whileLoop` hold blocks, sequences of
statements; an `if` with no `else` has an empty else block. `ret` is
`return`, with or without a value. `drop p` destroys the value in `p`;
only elaboration inserts it. -/
inductive Stmt where
  | pass
  | decl (name : Name) (ty : Ty) (init : Option Expr)
  | assign (target : Place) (value : Expr)
  | expr (e : Expr)
  | print (args : List Expr)
  | ifElse (cond : Expr) (thenBlock elseBlock : List Stmt)
  | whileLoop (cond : Expr) (body : List Stmt)
  | ret (value : Option Expr)
  | drop (p : Place)

end MojoGrimoire.Core
