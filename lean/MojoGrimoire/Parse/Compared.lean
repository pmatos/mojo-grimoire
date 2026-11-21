import MojoGrimoire.Parse.Dispatch
import MojoGrimoire.Check.Compare

/-!
The types that inference expects of literals, and of a literal compared
with an array or a list (#166, #185).

A literal compared with an array or a list is converted to that operand's
type, as the checker's `MojoGrimoire.Check.literalFits` decides from the
forms of its elements. Inference infers the literal once, with no type
expected, so that an operator or a call of a struct in it is a call of
the method it calls, and finds the fit from the forms of what results,
as the checker finds it from the same forms (`TyEnv.leafTy`). A literal
that fits then takes that type: inference gives each literal in it the
type expected of it (`TyEnv.retype`), as it would have, had it expected
that type from the start, without inferring the rest of it again.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The type of an open literal that is expected to have the type `t`: `t`
itself when it is a list or an array, whose size the checker compares with
the literal's length, and otherwise `unknown`, which the elements decide. -/
def openLiteralTy : Ty → Ty
  | t@(.list _) | t@(.array ..) => t
  | _ => .unknown

/-- The type that the elements of a literal of type `t` are expected to
have. -/
def elemExpected (t : Ty) : Ty := (elemOf t).toOption.getD .unknown

/-- Whether the expression `e` is made only of literals and operators, so
that it reads no place and calls nothing: a literal `[e]` of type `Int`
that holds one is kept, so that the checker does not compute an index
from it, as Mojo does not; any other is replaced by `e`. -/
def foldable : Expr → Bool
  | .int _ | .bool _ => true
  | .unary _ a => foldable a
  | .binary _ a b => foldable a && foldable b
  | .list .int [a] => foldable a
  | _ => false

/-- The type of the operand `e` that its form gives, once inference has
made an operator or a call of a struct a call of its method: what
`MojoGrimoire.Check.literalFits` needs of the elements of a literal
compared with an array or a list. It follows the checker's
`MojoGrimoire.Check.operandTy`, so that both find the same fit: a call
of a name that a variable hides, and a call that the program does not
declare, but `len`, have none. -/
def TyEnv.leafTy (prog : Program) (env : TyEnv) : Expr → Option Ty
  | .int _ => some .int
  | .bool _ => some .bool
  | .str _ => some .str
  | .place p | .copy p | .transfer p => env.placeTy prog p
  | .call f _ =>
    if (env.lookup f).isSome then none
    else match callSig prog f with
      | .ok sig => some sig.result
      | .error _ => if f == "len" then some .int else none
  | .method p m args =>
    (env.placeTy prog p).bind fun t => (methodSig prog t m args.length).toOption.map (·.result)
  | .unary op _ => some (if op == .neg then .int else .bool)
  | .binary op _ _ => some (binaryResult op)
  | .listInit u _ => some (.list u)
  | .withDrops e _ _ => env.leafTy prog e
  | _ => none

/-- Whether the literal `lit`, once inferred with no type expected, so
that its operators and calls are those of the methods they call, fits
the type `t`, as the elements' forms give it
(`MojoGrimoire.Check.literalFits`). -/
def TyEnv.literalFit (prog : Program) (env : TyEnv) (t : Ty) (lit : Expr) : Option Bool :=
  (literalFits (m := Id) (fun e => env.leafTy prog e) t lit).run

/-- Whether the comparison `op` converts a literal, on the left when
`left` holds, to the type `t` of the other operand, when it is known
(`MojoGrimoire.Check.convertsTo`). -/
def converts (op : BinOp) (t : Option Ty) (left := false) : Bool :=
  compares op && t.any (convertsTo op · left)

mutual
/-- The literal `e`, inferred with no type expected, once it is expected
to have the type `exp`, and its type: what inferring it with `exp`
expected gives, as `inferExpr` types a literal, since nothing but a
literal depends on the type expected of it. Any other expression stays,
with the type its form gives (`TyEnv.leafTy`). -/
def TyEnv.retype (prog : Program) (env : TyEnv) (exp : Ty) : Expr → Expr × Option Ty
  | .list .unknown es =>
    match exp, es with
    | .int, [e] =>
      let (e', te) := env.retype prog .int e
      if te == some .int then (if foldable e' then .list .int [e'] else e', some .int)
      else (.list .unknown [e'], te.map (.array · 1))
    | .int, es => (.list .int ((env.retypeList prog .int es).map (·.1)), some .int)
    | exp, es =>
      let t := openLiteralTy exp
      let es' := env.retypeList prog (elemExpected t) es
      let t' := match t, es'.head?.bind (·.2) with
        | .unknown, some u => .array u es.length
        | t, _ => t
      (.list t (es'.map (·.1)), if t' == .unknown then none else some t')
  | e => (e, env.leafTy prog e)

/-- Each of the expressions `es`, inferred with no type expected, once it
is expected to have the type `u` (`TyEnv.retype`). -/
def TyEnv.retypeList (prog : Program) (env : TyEnv) (u : Ty) :
    List Expr → List (Expr × Option Ty)
  | [] => []
  | e :: es => env.retype prog u e :: env.retypeList prog u es
end

/-- The literal `lit`, inferred with no type expected, and its type, once
it is compared by `op` with an operand of type `t`, on the left when
`left` holds. It takes `t` when the comparison converts a literal to it
and it fits `t` (`TyEnv.literalFit`), and on the right of `==` or `!=`
of a list also when its fit is not known, as the argument of the list's
`__eq__` or `__ne__` (#185); otherwise its elements decide its type
(#166). -/
def TyEnv.compared (prog : Program) (env : TyEnv) (op : BinOp) (t : Option Ty) (left : Bool)
    (lit : Expr × Option Ty) : Expr × Option Ty :=
  match t with
  | some t =>
    let fit := env.literalFit prog t lit.1
    if converts op (some t) left && fit == some true ||
        !left && (op == .eq || op == .ne) && t matches .list _ && fit != some false then
      env.retype prog t lit.1
    else lit
  | none => lit

end MojoGrimoire.Parse
