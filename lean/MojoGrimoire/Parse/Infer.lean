import MojoGrimoire.Parse.Stmt
import MojoGrimoire.Check.State

/-!
Type inference for what the parser leaves open: the type of a variable
declared as `var x = e`, and the element type of a list literal.

Inference follows the program's declarations: the types of the
parameters, of the variables declared so far, of the fields of each
struct, and the result of each function and method. A variable takes the
type of its initial value. A list literal takes the type of its first
element, or, when it is empty, the element type that its declaration or
the function's result gives it. What inference cannot find stays `None`,
which the checker rejects as a type that may not be declared.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The types of the variables in scope, innermost first. -/
abbrev TyEnv := List (Name × Ty)

/-- The type of the result of the binary operator `op`. -/
def binaryResult : BinOp → Ty
  | .add | .sub | .mul | .floorDiv | .mod => .int
  | _ => .bool

mutual
/-- Infers inside the place `p`, and gives its type, if it has one. -/
def inferPlace (prog : Program) (env : TyEnv) : Place → Place × Option Ty
  | .var x => (.var x, env.lookup x)
  | .field p f =>
    let (p', t) := inferPlace prog env p
    (.field p' f, t.bind fun t => (fieldOf prog t f).toOption)
  | .index p i =>
    let (p', t) := inferPlace prog env p
    (.index p' (inferExpr prog env i).1, t.bind fun t => (elemOf t).toOption)

/-- Infers inside the expression `e`, and gives its type, if it has one. -/
def inferExpr (prog : Program) (env : TyEnv) : Expr → Expr × Option Ty
  | .int k => (.int k, some .int)
  | .bool b => (.bool b, some .bool)
  | .str s => (.str s, some .str)
  | .place p => let (p', t) := inferPlace prog env p; (.place p', t)
  | .transfer p => let (p', t) := inferPlace prog env p; (.transfer p', t)
  | .copy p => let (p', t) := inferPlace prog env p; (.copy p', t)
  | .call f args =>
    let args' := (inferList prog env args).map (·.1)
    let t := match findStruct prog f, findFun prog f with
      | some _, _ => some (.struct f)
      | none, some fd => some fd.result
      | none, none => if f == "len" then some .int else none
    (.call f args', t)
  | .method p m args =>
    let (p', pt) := inferPlace prog env p
    let args' := (inferList prog env args).map (·.1)
    let t := match pt with
      | some (.list _) => some .noneType
      | some (.struct s) => ((findStruct prog s).bind (findMethod · m)).map (·.result)
      | _ => none
    (.method p' m args', t)
  | .unary op a =>
    (.unary op (inferExpr prog env a).1, some (if op == .neg then .int else .bool))
  | .binary op a b =>
    (.binary op (inferExpr prog env a).1 (inferExpr prog env b).1, some (binaryResult op))
  | .list t es =>
    let es' := inferList prog env es
    let t' := if t == .noneType then ((es'.head?.bind (·.2)).getD .noneType) else t
    (.list t' (es'.map (·.1)), some (.list t'))

/-- Infers inside each of the expressions `es`. -/
def inferList (prog : Program) (env : TyEnv) : List Expr → List (Expr × Option Ty)
  | [] => []
  | e :: es => inferExpr prog env e :: inferList prog env es
end

/-- Gives an empty list literal the element type of the type `t` it is
expected to have. -/
def expecting (t : Ty) : Expr → Expr
  | .list .noneType [] => match t with
    | .list u => .list u []
    | _ => .list .noneType []
  | e => e

mutual
/-- Infers inside the statement `s` of a function whose result type is
`result`, and gives the types in scope after it. -/
def inferStmt (prog : Program) (result : Ty) (env : TyEnv) : Stmt → Stmt × TyEnv
  | .decl x t init =>
    let init' := init.map fun e => inferExpr prog env (expecting t e)
    let t' := if t == .noneType then ((init'.bind (·.2)).getD .noneType) else t
    (.decl x t' (init'.map (·.1)), (x, t') :: env)
  | .refDecl x e =>
    let (e', t) := inferExpr prog env e
    (.refDecl x e', match t with | some t => (x, t) :: env | none => env)
  | .assign p e =>
    let (p', t) := inferPlace prog env p
    (.assign p' (inferExpr prog env (expecting (t.getD .noneType) e)).1, env)
  | .expr e => (.expr (inferExpr prog env e).1, env)
  | .print args => (.print ((inferList prog env args).map (·.1)), env)
  | .ifElse c a b =>
    (.ifElse (inferExpr prog env c).1 (inferBlock prog result env a)
      (inferBlock prog result env b), env)
  | .whileLoop c body =>
    (.whileLoop (inferExpr prog env c).1 (inferBlock prog result env body), env)
  | .ret value => (.ret (value.map fun e => (inferExpr prog env (expecting result e)).1), env)
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
