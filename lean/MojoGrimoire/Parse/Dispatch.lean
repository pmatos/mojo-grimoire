import MojoGrimoire.Parse.SelfType
import MojoGrimoire.Check.Methods

/-!
Which method of a struct an operator or a call calls, as
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
the method of `a`'s struct is called, and the checker reports its misfit.
A method fits only when its receiver and its other operand can be passed
with their conventions: a `mut` parameter, `self` among them, takes only
what may change, a place or a returned reference (`TyEnv.mutableAt`);
with no such method, the operator stays as it is, and the checker
reports the method that `a`'s type lacks, or the misfit of its built-in
operator. `!=` never falls back to `__eq__`, nor `>` to `__lt__` of the
left operand, and the methods that a trait supplies by default are not
modelled (#194).

`-a` calls `__neg__`, and `not a` negates what `__bool__` gives. `a and b`
and `a or b` convert each struct operand with `__bool__`, unless both
operands have the same type: then the operator gives the operand that
decides, as the checker and the interpreter say. `p += e`, `p -= e` and `p *= e` call `__iadd__`,
`__isub__` and `__imul__` of `p`'s struct, with no fallback to
`__add__`. A call `f(…)` of a variable `f` whose struct declares
`__call__` calls it: the variable hides a function, `len`, `range`,
`print` or a struct of its name. A struct's subscripts are not yet calls
of its methods (#191).
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The types of the variables in scope, innermost first, and the variables
that may not change: `read` and `ref` parameters, and `ref` bindings that
may not change what they point to. -/
structure TyEnv where
  vars : List (Name × Ty)
  fixed : List Name := []

/-- The type of the variable `x`. -/
def TyEnv.lookup (env : TyEnv) (x : Name) : Option Ty := env.vars.lookup x

/-- The variables after `x` of type `t` is declared. -/
def TyEnv.push (env : TyEnv) (x : Name) (t : Ty) : TyEnv := { env with vars := (x, t) :: env.vars }

/-- Whether the place `p` goes into a variable that may change. -/
def TyEnv.freePlace (env : TyEnv) (p : Place) : Bool :=
  !env.fixed.contains (splitPlace p).1 && !throughTransfer p

/-- The type of the place `p`. -/
def TyEnv.placeTy (prog : Program) (env : TyEnv) : Place → Option Ty
  | .var x => env.lookup x
  | .field p f => (env.placeTy prog p).bind fun t => (fieldOf prog t f).toOption
  | .index p _ => (env.placeTy prog p).bind fun t => (indexedOf t).toOption
  | .transferred p => env.placeTy prog p

mutual
/-- Whether the operand `e` may change: a place into a variable that may, or
a call that returns a reference whose origins are all parameters it may
change, `mut` ones, or `ref` ones passed what may change. -/
def TyEnv.mutableAt (prog : Program) (env : TyEnv) : Expr → Bool
  | .place p => env.freePlace p
  | .call f args => match callSig prog f with
    | .ok ⟨_, prms, _, some os@(_ :: _), _⟩ => env.mutableArgs prog os prms args
    | _ => false
  | .method p m args =>
    match (env.placeTy prog p).bind fun t => (methodSig prog t m args.length).toOption with
    | some ⟨self, prms, _, some os@(_ :: _), _⟩ =>
      (self.all fun s => !os.contains s.name || s.conv == .mutable ||
        (s.conv == .ref && env.freePlace p)) && env.mutableArgs prog os prms args
    | _ => false
  | _ => false

/-- Whether the arguments `as` passed to `prms` may change what a reference
into the parameters `os` points to. -/
def TyEnv.mutableArgs (prog : Program) (env : TyEnv) (os : List Name) :
    List Param → List Expr → Bool
  | prm :: prms, a :: as =>
    (!os.contains prm.name || prm.conv == .mutable || (prm.conv == .ref && env.mutableAt prog a))
      && env.mutableArgs prog os prms as
  | _, _ => true
end

/-- Whether the operand `e` may be passed to the parameter `prm` with its
convention: a `mut` parameter takes only what may change. -/
def TyEnv.canPass (prog : Program) (env : TyEnv) (e : Expr) (prm : Param) : Bool :=
  prm.conv != .mutable || env.mutableAt prog e

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
`fitsA prm` and `fitsB prm` say whether the type of the left and the right
operand fits the parameter `prm`, and `canA prm` and `canB prm` whether
the operand may be passed with its convention: a `mut` parameter, `self`
among them, takes only a place that may change. A method that its
receiver or its other operand cannot be passed to is not viable, as in
the compiler. `none` leaves the operator as it is. -/
def chooseBinary (prog : Program) (op : BinOp) (ta tb : Option Ty)
    (fitsA fitsB canA canB : Param → Bool) : Option (Name × FunDecl × Bool) :=
  let forward := declaredMethod prog ta (binaryMethod op)
  let reflected := declaredMethod prog tb (reflectedMethod op)
  let viable (self other : Param → Bool) (m : Option (Name × FunDecl)) :=
    m.any fun (_, fd) => fd.params.head?.all self && (otherParam fd).any other
  if viable canA (fun p => fitsB p && canB p) forward then forward.map fun (s, fd) => (s, fd, false)
  else if viable canB (fun p => fitsA p && canA p) reflected then
    reflected.map fun (s, fd) => (s, fd, true)
  else forward.map fun (s, fd) => (s, fd, false)

/-- The operand `e` of type `t` of `and`, `or` or `not`, converted with
`__bool__` when it is a struct that declares it. -/
def toBool (prog : Program) (e : Expr) (t : Option Ty) : Expr :=
  match declaredMethod prog t "__bool__" with
  | some (s, _) => .call (methodCallee s "__bool__") [e]
  | none => e

end MojoGrimoire.Parse
