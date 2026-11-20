import MojoGrimoire.Parse.SelfType
import MojoGrimoire.Check.Methods

/-!
Which method of a struct an operator, a subscript or a call calls, as
inference decides it (#191). An operator or a call on a struct value
calls the method that the struct declares itself, with the operand read
by reference, as the pinned nightly 1.3.0.dev2026111905 does. Inference
makes it a call of the method as a function, `S.m(r, …)`
(`MojoGrimoire.Core.methodCallee`), which the checker, elaboration and
the interpreter treat as any other call.

A binary operator `a op b` calls the method of `a`'s struct that `op`
names, such as `__add__` or `__lt__`, when `b` fits its parameter.
Otherwise it calls the reflected method of `b`'s struct, such as
`__radd__` for `+`, or `__gt__` for `<`, when `a` fits its parameter, so
also when `a` is an `Int`, a `Bool`, a list or an array, or a struct that
lacks the method, of any type, its own too; `==` and `!=` reflect to
themselves. When neither fits,
the method of `a`'s struct is called, and the checker reports its misfit;
with no such method, the operator stays as it is, and the checker
reports the method that `a`'s type lacks, or the misfit of its built-in
operator. `!=` never falls back to `__eq__`, nor `>` to `__lt__` of the
left operand, and the methods that a trait supplies by default are not
modelled (#194).

`-a` calls `__neg__`, and `not a` negates what `__bool__` gives. `a and b`
and `a or b` convert each struct operand with `__bool__`, unless both
operands have the same type: then the operator gives the operand that
decides, as the checker and the interpreter say. `p += e`, `p -= e` and
`p *= e` call `__iadd__`, `__isub__` and `__imul__` of `p`'s struct,
with no fallback to `__add__`. A subscript `p[i]` read as a value calls
`__getitem__`, and assigned calls `__setitem__` when the struct declares
both. A call `f(…)` of a variable `f` whose struct declares `__call__`
calls it: the variable hides a function, `len`, `range`, `print` or a
struct of its name.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The struct named by the type `t`, and its method `m`, when `t` is a
struct that declares it. -/
def declaredMethod (prog : Program) (t : Option Ty) (m : Name) : Option (Name × FunDecl) :=
  match t with
  | some (.struct s) => ((findStruct prog s).bind (findMethod · m)).map (s, ·)
  | _ => none

/-- The method that the reflected binary operator `op` calls on its right
operand. -/
def reflectedMethod : BinOp → Name
  | .add => "__radd__"
  | .sub => "__rsub__"
  | .mul => "__rmul__"
  | .floorDiv => "__rfloordiv__"
  | .mod => "__rmod__"
  | .lt => "__gt__"
  | .le => "__ge__"
  | .gt => "__lt__"
  | .ge => "__le__"
  | .eq => "__eq__"
  | .ne => "__ne__"
  | .and | .or => "__bool__"

/-- The in-place method that `p op= e` calls. -/
def inPlaceMethod : BinOp → Name
  | .sub => "__isub__"
  | .mul => "__imul__"
  | _ => "__iadd__"

/-- The parameter of the method `fd` that takes the other operand of a
binary operator, when `fd` takes exactly one after `self`. -/
def otherParam (fd : FunDecl) : Option Param :=
  match fd.params with
  | [_, prm] => some prm
  | _ => none

/-- The method that the binary operator `op` calls on operands of types
`ta` and `tb`: its struct, the method, and whether it is reflected.
`fitsA prm` and `fitsB prm` say whether the left and the right operand fit
the parameter `prm`. `none` leaves the operator as it is. -/
def chooseBinary (prog : Program) (op : BinOp) (ta tb : Option Ty)
    (fitsA fitsB : Param → Bool) : Option (Name × FunDecl × Bool) :=
  let forward := declaredMethod prog ta (binaryMethod op)
  let reflected := declaredMethod prog tb (reflectedMethod op)
  let fits (fits : Param → Bool) (m : Option (Name × FunDecl)) :=
    m.any fun (_, fd) => (otherParam fd).any fits
  if fits fitsB forward then forward.map fun (s, fd) => (s, fd, false)
  else if fits fitsA reflected then reflected.map fun (s, fd) => (s, fd, true)
  else forward.map fun (s, fd) => (s, fd, false)

/-- The operand `e` of type `t` of `and`, `or` or `not`, converted with
`__bool__` when it is a struct that declares it. -/
def toBool (prog : Program) (e : Expr) (t : Option Ty) : Expr :=
  match declaredMethod prog t "__bool__" with
  | some (s, _) => .call (methodCallee s "__bool__") [e]
  | none => e

end MojoGrimoire.Parse
