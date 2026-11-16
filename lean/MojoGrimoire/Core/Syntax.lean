import MojoGrimoire.Core.Types

/-!
The places, expressions and statements of the core calculus.

A place names a location that holds a value: a variable, a field of a
place, or an element of a list, whose index is an expression. Places are their own syntactic category because Mojo's argument
conventions pass some arguments as locations and others as values: a place
used as an argument is passed as a reference when the parameter's convention
is `read`, `mut` or `ref`, and read as a value otherwise.

Mojo destroys each value as soon as possible, right after its last use.
The core calculus makes destruction explicit with the statement `drop`, and
with the expression `withDrops` for a value whose last use is inside an
expression. No Mojo program contains them: elaboration inserts them, so
that running a program never has to find a value's last use.
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
`m` on the place `p`, Mojo's `p.m(args)`. `list t es` is a literal of the
type `t`, a list or an array, with the elements `es`: Mojo's
`[e₁, …, eₙ]`, or `List[u](e₁, …, eₙ)`. Mojo gives `[e₁, …, eₙ]` the type
`Array[u, n]` unless a list is expected where it stands.
`withDrops e pre post` performs the operation `e` and destroys the values
in the places `pre` once its operands are read, before it is performed,
and those in `post` once it is done; only elaboration inserts it. -/
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
  | list (ty : Ty) (elems : List Expr)
  | withDrops (e : Expr) (pre post : List Place)
end

/-- The statements. `decl x t e` is Mojo's `var x: t = e`, or `var x: t`
when `e` is absent. `ifElse` and `whileLoop` hold blocks, sequences of
statements; an `if` with no `else` has an empty else block. `ret` is
`return`, with or without a value. `refDecl x e` is Mojo's `ref x = e`,
which binds `x` to the location that `e` names: a place, or a call that
returns a reference. `drop p` destroys the value in `p`; only elaboration
inserts it. -/
inductive Stmt where
  | pass
  | decl (name : Name) (ty : Ty) (init : Option Expr)
  | refDecl (name : Name) (target : Expr)
  | assign (target : Place) (value : Expr)
  | expr (e : Expr)
  | print (args : List Expr)
  | ifElse (cond : Expr) (thenBlock elseBlock : List Stmt)
  | whileLoop (cond : Expr) (body : List Stmt)
  | ret (value : Option Expr)
  | drop (p : Place)

end MojoGrimoire.Core
