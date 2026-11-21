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
elements. `unknown` is no Mojo type: it stands for a type that the parser
leaves for inference, and stays where inference finds none (#131). -/
inductive Ty where
  | int
  | bool
  | str
  | noneType
  | struct (name : Name)
  | list (elem : Ty)
  | array (elem : Ty) (size : Nat)
  | unknown
  deriving DecidableEq, Repr

/-- The type written as the name `x` where a variable of that name is in
scope, which hides the type there (#193): a struct that no program
declares, since no name of a program holds `$`. The checker rejects it as
`valueAsType`. -/
def hiddenTy (x : Name) : Ty := .struct ("$" ++ x)

/-- The name that a variable hides in the type `t`, itself or through its
lists and arrays (`hiddenTy`). -/
def Ty.hidden : Ty → Option Name
  | .struct s => if s.startsWith "$" then some (s.drop 1).toString else none
  | .list t | .array t _ => t.hidden
  | _ => none

/-- Whether Mojo uses a value of type `t` by value where it would otherwise
use its location: an `Int`, a `Bool` or `None`, which Mojo copies when it
is passed to a `read` parameter, and does not move with `^` (#131). -/
def Ty.byValue : Ty → Bool
  | .int | .bool | .noneType => true
  | _ => false

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

/-- The integer function of an arithmetic operator, before any wrapping to
a machine width; `none` for the others. `//` and `%` round toward negative
infinity and give `0` for a zero divisor, as Mojo defines them. The
checker folds constant indices with it and the interpreter computes with
it, so the two agree. -/
def BinOp.arith : BinOp → Option (Int → Int → Int)
  | .add => some (· + ·)
  | .sub => some (· - ·)
  | .mul => some (· * ·)
  | .floorDiv => some fun x y => if y == 0 then 0 else x.fdiv y
  | .mod => some fun x y => if y == 0 then 0 else x.fmod y
  | _ => none

end MojoGrimoire.Core
