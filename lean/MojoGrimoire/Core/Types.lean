/-!
The names, types, argument conventions and operators of the core calculus,
the subset of Mojo that Phase 1 models: structs and their methods, the
argument conventions, moves and copies, control flow, `Int`, lists and
arrays (`docs/decisions/process.md`). They are the leaves of the abstract syntax,
which the next sections build from them.

The core calculus is designed in this project's own terms
(ADR-2026-11-15-1908); Mojo's own spelling of each construct is given beside
it.
-/

namespace MojoGrimoire.Core

/-- A name: of a variable, a field, a function, a method or a struct. -/
abbrev Name := String

/-- The types of the core calculus. `str` is the type of string literals,
which may only be printed, and `noneType` the type of a call that returns
nothing, Mojo's `None`. `list t` is Mojo's `List[t]`, whose length may
change, and `array t n` is Mojo's `Array[t, n]`, which holds exactly `n`
elements. -/
inductive Ty where
  | int
  | bool
  | str
  | noneType
  | struct (name : Name)
  | list (elem : Ty)
  | array (elem : Ty) (size : Nat)
  deriving DecidableEq, Repr

/-- The argument conventions. `read` is the default, which Mojo writes with no
keyword; `mutable` is Mojo's `mut`, and `owned` is Mojo's `var`. `out` is
only the convention of `self` in `__init__`, and `deinit` only that of
`self` in `__deinit__`. -/
inductive Conv where
  | read
  | mutable
  | owned
  | ref
  | out
  | deinit
  deriving DecidableEq, Repr

/-- The unary operators: `-e` on `Int` and `not e` on `Bool`. -/
inductive UnOp where
  | neg
  | not
  deriving DecidableEq, Repr

/-- The binary operators. `floorDiv` is Mojo's `//`. `and` and `or`
short-circuit, as in Mojo: the right operand is evaluated only when the left
one does not decide the result. -/
inductive BinOp where
  | add
  | sub
  | mul
  | floorDiv
  | mod
  | lt
  | le
  | gt
  | ge
  | eq
  | ne
  | and
  | or
  deriving DecidableEq, Repr

end MojoGrimoire.Core
