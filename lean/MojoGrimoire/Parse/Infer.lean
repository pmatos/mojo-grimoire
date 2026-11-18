import MojoGrimoire.Parse.Stmt
import MojoGrimoire.Check.State

/-!
Type inference for what the parser leaves open: the type of a variable
declared as `var x = e`, and the type of a literal `[e₁, …, eₙ]`.

Inference follows the program's declarations: the types of the
parameters, of the variables declared so far, of the fields of each
struct, and the signature of each call and method call. A variable takes the
type of its initial value. A literal takes the type expected where it
stands: the declared type of its variable, the type of the place it is
assigned to, the function's result when it is returned, the parameter it
is passed to, or the element type of the literal or list that holds it.
Where none is expected, it is an `Array[t, n]` of its `n` elements, with
the type `t` of the first, as in Mojo: inference gives that type to what
holds the literal, and leaves the literal's own type `None`, so that the
checker tells a literal that initializes an expected type from one that
takes the type of its elements (#46). What inference cannot find stays
`None`, which the checker rejects as a type that may not be declared, once
it has checked the initializer, whose own error comes first (#123).
`List[u](e₁, …, eₙ)` is a list of `u`; nothing is expected of its
arguments. With one argument, `e`, Mojo takes it by `ref`, which borrows
`p^`: inference gives it the place `transferred p` (#103).

Inference also gives `p^` its meaning when `p` is an `Int` or a `Bool`.
Mojo does not move such a value: it warns that the transfer has no effect,
and uses the place `p`, which is what inference puts in its stead. That
holds wherever `p` is, also an element of a list or an array, or a field of
one, which keeps its value.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The types of the variables in scope, innermost first. -/
abbrev TyEnv := List (Name × Ty)

/-- The type of the result of the binary operator `op`. -/
def binaryResult : BinOp → Ty
  | .add | .sub | .mul | .floorDiv | .mod => .int
  | _ => .bool

/-- The type of an open literal that is expected to have the type `t`: `t`
itself when it is a list or an array, whose size the checker compares with
the literal's length, and otherwise `None`, which the elements decide. -/
def openLiteralTy : Ty → Ty
  | t@(.list _) | t@(.array ..) => t
  | _ => .noneType

/-- The type that the elements of a literal of type `t` are expected to
have. -/
def elemExpected (t : Ty) : Ty := (elemOf t).toOption.getD .noneType

/-- The types of the parameters of the signature `sig`, when there is one,
which the arguments of a call are expected to have. -/
def paramTys (sig : Option Signature) : List Ty :=
  sig.elim [] (·.params.map (·.ty))

/-- The type of a call of `f` with no signature: a struct's, even when it
cannot be built, so that the checker reports why; `len`'s `Int`; and
otherwise none. -/
def unsignedResult (prog : Program) (f : Name) : Option Ty :=
  if (findStruct prog f).isSome then some (.struct f)
  else if f == "len" then some .int
  else none

mutual
/-- Infers inside the place `p`, and gives its type, if it has one. -/
def inferPlace (prog : Program) (env : TyEnv) : Place → Place × Option Ty
  | .var x => (.var x, env.lookup x)
  | .field p f =>
    let (p', t) := inferPlace prog env p
    (.field p' f, t.bind fun t => (fieldOf prog t f).toOption)
  | .index p i =>
    let (p', t) := inferPlace prog env p
    (.index p' (inferExpr prog env .noneType i).1, t.bind fun t => (elemOf t).toOption)
  | .transferred p => let (p', t) := inferPlace prog env p; (.transferred p', t)

/-- Infers inside the expression `e`, expected to have the type `exp`
(`None` when nothing is expected), and gives its type, if it has one. -/
def inferExpr (prog : Program) (env : TyEnv) (exp : Ty) : Expr → Expr × Option Ty
  | .int k => (.int k, some .int)
  | .bool b => (.bool b, some .bool)
  | .str s => (.str s, some .str)
  | .place p => let (p', t) := inferPlace prog env p; (.place p', t)
  | .transfer p =>
    let (p', t) := inferPlace prog env p
    if t.any Ty.byValue then (.place p', t) else (.transfer p', t)
  | .copy p => let (p', t) := inferPlace prog env p; (.copy p', t)
  | .call f args =>
    let sig := (callSig prog f).toOption
    let args' := (inferList prog env (paramTys sig) args).map (·.1)
    (.call f args', sig.elim (unsignedResult prog f) (some ·.result))
  | .method p m args =>
    let (p', pt) := inferPlace prog env p
    let sig := pt.bind fun t => (methodSig prog t m args.length).toOption
    let args' := (inferList prog env (paramTys sig) args).map (·.1)
    (.method p' m args', sig.map (·.result))
  | .unary op a =>
    (.unary op (inferExpr prog env .noneType a).1, some (if op == .neg then .int else .bool))
  | .binary op a b =>
    (.binary op (inferExpr prog env .noneType a).1 (inferExpr prog env .noneType b).1,
      some (binaryResult op))
  | .list t es =>
    let n := es.length
    let t := if t == .noneType then openLiteralTy exp else t
    let es' := inferList prog env (List.replicate n (elemExpected t)) es
    let t' := match t, es'.head?.bind (·.2) with
      | .noneType, some u => .array u n
      | t, _ => t
    (.list t (es'.map (·.1)), if t' == .noneType then none else some t')
  | .listInit u args =>
    let args' : List Expr := (inferList prog env [] args).map (·.1)
    (.listInit u (match args' with | [.transfer p] => [.place (.transferred p)] | as => as),
      some (.list u))
  | .withDrops e pre post =>
    let (e', t) := inferExpr prog env exp e
    (.withDrops e' pre post, t)

/-- Infers inside each of the expressions `es`, expected to have the types
`exps` in order, or `None` past their end. -/
def inferList (prog : Program) (env : TyEnv) (exps : List Ty) :
    List Expr → List (Expr × Option Ty)
  | [] => []
  | e :: es => inferExpr prog env (exps.headD .noneType) e :: inferList prog env exps.tail es
end

mutual
/-- Infers inside the statement `s` of a function whose result type is
`result`, and gives the types in scope after it. -/
def inferStmt (prog : Program) (result : Ty) (env : TyEnv) : Stmt → Stmt × TyEnv
  | .decl x t init =>
    let init' := init.map fun e => inferExpr prog env t e
    let t' := if t == .noneType then ((init'.bind (·.2)).getD .noneType) else t
    (.decl x t' (init'.map (·.1)), (x, t') :: env)
  | .refDecl x e =>
    let (e', t) := inferExpr prog env .noneType e
    (.refDecl x e', match t with | some t => (x, t) :: env | none => env)
  | .assign p e =>
    let (p', t) := inferPlace prog env p
    (.assign p' (inferExpr prog env (t.getD .noneType) e).1, env)
  | .expr e => (.expr (inferExpr prog env .noneType e).1, env)
  | .print args => (.print ((inferList prog env [] args).map (·.1)), env)
  | .ifElse c a b =>
    (.ifElse (inferExpr prog env .noneType c).1 (inferBlock prog result env a)
      (inferBlock prog result env b), env)
  | .whileLoop c body =>
    (.whileLoop (inferExpr prog env .noneType c).1 (inferBlock prog result env body), env)
  | .ret value => (.ret (value.map fun e => (inferExpr prog env result e).1), env)
  | .pass => (.pass, env)
  | .drop p => (.drop p, env)

/-- Infers inside the statements of a block, in order. -/
def inferBlock (prog : Program) (result : Ty) (env : TyEnv) : List Stmt → List Stmt
  | [] => []
  | s :: rest =>
    let (s', env') := inferStmt prog result env s
    s' :: inferBlock prog result env' rest
end

/-- Infers inside a function, from its parameters. -/
def inferFun (prog : Program) (fd : FunDecl) : FunDecl :=
  { fd with body := inferBlock prog fd.result (fd.params.map fun p => (p.name, p.ty)) fd.body }

/-- Infers inside a struct's initializer, destructor and methods. -/
def inferStruct (prog : Program) (sd : StructDecl) : StructDecl :=
  { sd with
    init := sd.init.map (inferFun prog)
    deinit := sd.deinit.map (inferBlock prog .noneType [("self", .struct sd.name)])
    methods := sd.methods.map (inferFun prog) }

/-- Infers inside every declaration of a program. -/
def inferProgram (prog : Program) : Program :=
  ⟨prog.structs.map (inferStruct prog), prog.funs.map (inferFun prog)⟩

/-- Parses the text of a `.mojo` file into a program of the core calculus. -/
def parse (source : String) : Except SyntaxError Program := do
  pure (inferProgram (← parseRaw source))

end MojoGrimoire.Parse
