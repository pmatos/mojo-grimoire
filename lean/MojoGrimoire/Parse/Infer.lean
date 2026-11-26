import MojoGrimoire.Parse.InferExpr

/-!
Type inference for what the parser leaves open: the type of a variable
declared as `var x = e`, and the type of a literal `[e₁, …, eₙ]`. This
module infers statements, functions and the program; inference inside an
expression, and what it expects there, is `MojoGrimoire.Parse.InferExpr`.

A variable takes the type of its initial value, `None` for a call that
returns nothing (#131), unless it declares one. A literal there is
expected to have the declared type of its variable, the type of the
place it is assigned to, or the function's result when it is returned.
A `ref` binding, and a function that returns a reference, keep a place as
it is (`inferTarget`), so a subscript of a struct there is not read
through its getter (#198). `q[i] = v` on a struct that declares
`__getitem__` and `__setitem__` calls the setter, and its value is read
as it is evaluated (`eagerValue`, #191).
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- Infers inside the expression `e`, expected to have the type `exp`, that
a `ref` binds or a function that returns a reference returns: a place
stays a place, so a subscript of a struct is not read through its getter. -/
def inferTarget (prog : Program) (env : TyEnv) (exp : Ty) (e : Expr) : Expr × Option Ty :=
  match e with
  | .place p => let (p', t) := inferPlace prog env p; (.place p', t)
  | e => inferExpr prog env exp e

/-- The value `e` of `q[i] = e`, which the compiler reads before it calls
the getters of the subscripts read late in `i` (#191): such a subscript is
a call of its getter as a method, made as `e` is evaluated. -/
def eagerValue (prog : Program) : Expr → Expr
  | .call g (.place r :: args) =>
    if lateGetter prog g then .method r "__getitem__" args else .call g (.place r :: args)
  | e => e

mutual
/-- Infers inside the statement `s` of a function whose result type is
`result`, and gives the types in scope after it. -/
def inferStmt (prog : Program) (result : Ty) (env : TyEnv) : Stmt → Stmt × TyEnv
  | .decl x t init =>
    let init' := init.map fun e => inferExpr prog env t e
    let t' := if t == .unknown then ((init'.bind (·.2)).getD .unknown) else t
    (.decl x t' (init'.map (·.1)), env.push x t')
  | .refDecl x e =>
    let (e', t) := inferTarget prog env .unknown e
    let mutable := match e' with
      | .place p => !env.fixed.contains (splitPlace p).1
      | e' => env.mutableAt prog e'
    (.refDecl x e', match t with
      | some t => { env.push x t with fixed := if mutable then env.fixed else x :: env.fixed }
      | none => env)
  | .assign (.index q i) e =>
    let (q', qt) := inferPlace prog env q
    match declaredMethod prog qt "__getitem__", declaredMethod prog qt "__setitem__" with
    | some _, some (s, fd) =>
      let args := match inferArgs prog env fd.params.tail [i, e] with
        | [i', e'] => [i', eagerValue prog e']
        | args => args
      (.expr (.call (methodCallee s "__setitem__") (.place q' :: args)), env)
    | _, _ =>
      let (p', t) := inferPlace prog env (.index q i)
      (.assign p' (inferExpr prog env (t.getD .unknown) e).1, env)
  | .assign p e =>
    let (p', t) := inferPlace prog env p
    (.assign p' (inferExpr prog env (t.getD .unknown) e).1, env)
  | .expr (.call f [.place p, e]) =>
    match augOps.find? (·.1 == f) with
    | some (_, op) =>
      let (p', t) := inferPlace prog env p
      match t with
      | some (.struct s) =>
        let m := inPlaceMethod op
        let prms := ((declaredMethod prog t m).map (·.2.params.tail)).getD []
        (.expr (.call (methodCallee s m) (.place p' :: inferArgs prog env prms [e])), env)
      | _ =>
        let u := if t == some .int && e matches .list .. then .int else .unknown
        (.assign p' (.binary op (.place p') (inferExpr prog env u e).1), env)
    | none => (.expr (inferExpr prog env .unknown (.call f [.place p, e])).1, env)
  | .expr e => (.expr (inferExpr prog env .unknown e).1, env)
  | .print args =>
    match declaredMethod prog (env.lookup "print") "__call__" with
    | some (s, fd) =>
      (.expr (.call (methodCallee s "__call__") (.place (.var "print") :: inferArgs prog env fd.params.tail args)),
        env)
    | none => (.print ((inferList prog env [] args).map (·.1)), env)
  | .ifElse c a b =>
    (.ifElse (inferExpr prog env .unknown c).1 (inferBlock prog result env a)
      (inferBlock prog result env b), env)
  | .whileLoop c body =>
    (.whileLoop (inferExpr prog env .unknown c).1 (inferBlock prog result env body), env)
  | .ret value =>
    (.ret (value.map fun e => (if result == .unknown then inferTarget prog env result e
      else inferExpr prog env result e).1), env)
  | .pass => (.pass, env)
  | .drop p => (.drop p, env)

/-- Infers inside the statements of a block, in order. -/
def inferBlock (prog : Program) (result : Ty) (env : TyEnv) : List Stmt → List Stmt
  | [] => []
  | s :: rest =>
    let (s', env') := inferStmt prog result env s
    s' :: inferBlock prog result env' rest
end

/-- Infers inside a function, from its parameters. A function that returns
a reference expects no `Int` of the value it returns, which must be a
place: a literal there is no place, as Mojo reports. -/
def inferFun (prog : Program) (fd : FunDecl) : FunDecl :=
  let result := if fd.origin.isSome then Ty.unknown else fd.result
  let fixed := fd.params.filter fun p => p.conv == .read || p.conv == .ref
  let env : TyEnv := ⟨fd.params.map fun p => (p.name, p.ty), fixed.map (·.name)⟩
  { fd with body := inferBlock prog result env fd.body }

/-- Infers inside a struct's initializer, destructor and methods. -/
def inferStruct (prog : Program) (sd : StructDecl) : StructDecl :=
  { sd with
    init := sd.init.map (inferFun prog)
    deinit := sd.deinit.map (inferBlock prog .noneType ⟨[("self", .struct sd.name)], []⟩)
    methods := sd.methods.map (inferFun prog) }

/-- Infers inside every declaration of a program. -/
def inferProgram (prog : Program) : Program :=
  { prog with structs := prog.structs.map (inferStruct prog), funs := prog.funs.map (inferFun prog) }

/-- The program of the core calculus that the program `raw`, as parsed,
stands for: the types that a variable hides are marked (`markHidden`), then
`Self` is resolved, then inference fills in what the program leaves open. -/
def inferRaw (raw : Program) : Program :=
  inferProgram (resolveSelf (markHidden raw))

/-- Parses the text of a `.mojo` file into a program of the core calculus,
as `inferRaw` gives it. It does not check the constructs outside the
subset, which `MojoGrimoire.Parse.parseSubset` does. -/
def parse (source : String) : Except SyntaxError Program := do
  pure (inferRaw (← parseRaw source))

end MojoGrimoire.Parse
