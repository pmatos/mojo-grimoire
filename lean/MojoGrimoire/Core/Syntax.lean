import MojoGrimoire.Core.Types

/-!
The places, expressions and statements of the core calculus.

A place names a location that holds a value: a variable, a field of a
place, or an element of a list or an array, whose index is an expression.
Mojo's `p^.f` and `p^.m(…)` read a field of, or call a method on, the place
`p` reached by a transfer, which the compiler borrows instead of moving: the
place `transferred p`. Places are their own syntactic category because Mojo's argument
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
/-- A place: a variable `x`, a field `p.f` of a place `p`, the element
`p[i]` of a list or an array, or `p^` when a field or a method follows it,
`transferred p`: the place `p`, which cannot be changed through it, unless
a method that takes `var self` consumes it. -/
inductive Place where
  | var (name : Name)
  | field (base : Place) (field : Name)
  | index (base : Place) (index : Expr)
  | transferred (base : Place)

/-- The expressions. `place p` uses a place: as a value, which copies it
implicitly, or as a reference argument. `transfer p` is Mojo's `p^`, which
moves the value out of `p`, and `copy p` is Mojo's explicit `p.copy()`.
`call f args` calls the function `f` or, when `f` names a struct,
constructs it, as Mojo's `S(args)` does. `method p m args` calls the method
`m` on the place `p`, Mojo's `p.m(args)`. `list t es` is a literal of the
type `t`, a list or an array, with the elements `es`: Mojo's
`[e₁, …, eₙ]`, or `List[u]()` when it is empty. Mojo gives `[e₁, …, eₙ]`
the type `Array[u, n]` unless a list is expected where it stands; the
parser gives it the type `None`, which inference replaces only when a list
or an array is expected, or an `Int` for a literal `[e]` of one `Int`
made of literals and operators, which is the value of `e` (#103). `listInit u es` is Mojo's `List[u](e₁, …, eₙ)`
with at least one argument. With one, a list or an array of `u`, it is a
new list of copies of its elements (#103), and with one that calls the
standard library's `range`, the list of the range's `Int`s (#121); with
more, the compiler rejects it (#46): no initializer of `List` takes its
elements as arguments.
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
  | listInit (elem : Ty) (args : List Expr)
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
