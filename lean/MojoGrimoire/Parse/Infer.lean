import MojoGrimoire.Parse.Compared
import MojoGrimoire.Parse.HiddenTypes

/-!
Type inference for what the parser leaves open: the type of a variable
declared as `var x = e`, and the type of a literal `[e₁, …, eₙ]`.

Inference follows the program's declarations: the types of the
parameters, of the variables declared so far, of the fields of each
struct, and the signature of each call and method call. A variable takes the
type of its initial value, `None` for a call that returns nothing (#131),
unless it declares one. A literal takes the type expected where it
stands: the declared type of its variable, the type of the place it is
assigned to, the function's result when it is returned, the parameter it
is passed to, or the element type of the literal or list that holds it.
A literal `[e]` of one `Int` element where an `Int` is expected is an
`Int`, the value of `e`, as Mojo's `SIMD` initializer from a list literal
makes it (#103). Mojo reads it as it reads the operand `e`: a place in it
is read once every operand of the operation is evaluated, and destroyed
then. So inference puts `e` in its stead, unless `e` is made only of
literals and operators: that literal stays, typed `Int`, since Mojo does
not compute an index that holds it when it compiles the program. Passed
`mut` or `ref`, the literal is a temporary, so it stays too
(`inferArg`), and a function that returns a reference expects no
`Int` of what it returns, which must be a place. A literal of any other
length where an `Int` is expected is typed `Int` too, and so is each of
its elements, as SIMD's initializer takes them; the checker rejects it
(#153, #154). An `Int`
is also expected by an index, and by either operand of an operator other
than `and` and `or` whose other operand is an `Int`, as Mojo reads it
(#160). A literal compared with an array or a list is expected to have
that operand's type, as the argument of its comparison method, when it
fits it (`MojoGrimoire.Check.literalFits`): on the right, of the left
operand, and on the left, of a right operand that is no literal and
whose comparison conforms (#166), unless either operand is a literal that
holds a place whose value is not implicitly copyable, or `List[u]()`.
The right operand of `==` or `!=` whose left operand is a list is
expected to have the list's type unless it does not fit it, also when its
fit is not known (#185). In a program in `main`'s mode
(`Program.mainMode`), every comparison keeps the expectations it had
before #166, as in `main`: inference gives a program also the bodies it
gives in that mode, each with the struct it belongs to (`Program.twin`),
for the checker's bridge to `main`'s order (`MojoGrimoire.Check.bridged`). Where none is expected, it is an `Array[t, n]` of its `n` elements, with
the type `t` of the first, as in Mojo: inference gives that type to what
holds the literal, and leaves the literal's own type `unknown`, so that the
checker tells a literal that initializes an expected type from one that
takes the type of its elements (#46). What inference cannot find stays
`unknown`, which the checker rejects as a type that may not be declared, once
it has checked the initializer, whose own error comes first (#123).
`List[u](e₁, …, eₙ)` is a list of `u`; nothing is expected of its
arguments. With one argument, `e`, Mojo takes it by `ref`, which borrows
`p^`: inference gives it the place `transferred p` (#103). A call of
`range` that the program does not declare expects an `Int` of each of its
arguments, as the standard library's `range` does (#121). A call of a name
that a variable in scope hides follows no signature and has no type: the
checker rejects it, once it has typed the arguments (#176), unless the
variable's struct declares `__call__`.

An operator, an in-place operator and a call whose operand is a struct
that declares the method become calls of the method, as
`MojoGrimoire.Parse.Dispatch` decides (#191); a literal operand is
inferred as an argument of the method's other parameter (`inferArg`,
`literalArg`), so that one passed `mut` or `ref` stays a temporary. Inference knows which
variables may not change, so that a method whose `mut` parameter an
operand cannot be passed to is not chosen: a `ref` binding may change
what it points to when its target, once inferred, may, such as a call of
a method that returns a reference through a `mut` parameter, or a place
of a variable that may change, also through `q^`, whose transfer has no
effect there, as the checker's `refTarget` reads it.

Inference also gives `p^` its meaning when `p` is an `Int`, a `Bool` or
`None` (#131).
Mojo does not move such a value: it warns that the transfer has no effect,
and uses the place `p`, which is what inference puts in its stead. That
holds wherever `p` is, also an element of a list or an array, or a field of
one, which keeps its value.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core MojoGrimoire.Check

/-- The type of a call of `f` with no signature: a struct's, even when it
cannot be built, so that the checker reports why; `len`'s `Int`; and
otherwise none. -/
def unsignedResult (prog : Program) (f : Name) : Option Ty :=
  if (findStruct prog f).isSome then some (.struct f)
  else if f == "len" then some .int
  else none

/-- The argument that inference gave a literal passed to the parameter
`prm`, given the literal's inferred form `a'`: an `Int` that the literal
became is put back in a literal when `prm` is `mut` or `ref`, so that it
stays a temporary. Callers pass only the form of a literal. -/
def literalArg (prm : Param) (a' : Expr) : Expr :=
  if (prm.conv == .mutable || prm.conv == .ref) && !(a' matches .list ..) then .list .int [a']
  else a'

mutual
/-- Infers inside the place `p`, and gives its type, if it has one. -/
def inferPlace (prog : Program) (env : TyEnv) : Place → Place × Option Ty
  | .var x => (.var x, env.lookup x)
  | .field p f =>
    let (p', t) := inferPlace prog env p
    (.field p' f, t.bind fun t => (fieldOf prog t f).toOption)
  | .index p i =>
    let (p', t) := inferPlace prog env p
    (.index p' (inferExpr prog env .int i).1, t.bind fun t => (indexedOf t).toOption)
  | .transferred p => let (p', t) := inferPlace prog env p; (.transferred p', t)
  termination_by p => (sizeOf p, 0)

/-- Infers inside the expression `e`, expected to have the type `exp`
(`unknown` when nothing is expected), and gives its type, if it has one. -/
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
    match declaredMethod prog (env.lookup f) "__call__" with
    | some (s, fd) =>
      (.call (methodCallee s "__call__") (.place (.var f) :: inferArgs prog env fd.params.tail args),
        some fd.result)
    | none =>
      let hidden := (env.lookup f).isSome
      let sig := if hidden then none else (callSig prog f).toOption
      let params := sig.elim
        (if builtinRange prog f && !hidden then rangeParams args.length else []) (·.params)
      (.call f (inferArgs prog env params args),
        if hidden then none else sig.elim (unsignedResult prog f) (some ·.result))
  | .method p m args =>
    let (p', pt) := inferPlace prog env p
    let sig := pt.bind fun t => (methodSig prog t m args.length).toOption
    (.method p' m (inferArgs prog env (sig.elim [] (·.params)) args), sig.map (·.result))
  | .unary op a =>
    let (a', ta) := inferExpr prog env .unknown a
    match declaredMethod prog ta (unaryMethod op), op with
    | some (s, fd), .neg => (.call (methodCallee s "__neg__") [a'], some fd.result)
    | _, _ => (.unary op a', some (if op == .neg then .int else .bool))
  | .binary op a b =>
    let (a₀, ta₀) := if a matches .list .. then (a, none) else inferExpr prog env .unknown a
    let (b₀, tb₀) := if b matches .list .. then (b, none) else inferExpr prog env .unknown b
    if op == .and || op == .or then
      let a' := if a matches .list .. then (inferExpr prog env .unknown a).1 else a₀
      let b' := if b matches .list .. then (inferExpr prog env .unknown b).1 else b₀
      (.binary op a' b', some (binaryResult op))
    else
    let tyA := ((declaredMethod prog tb₀ (reflectedMethod op)).bind (otherParam ·.2)).map (·.ty)
    let tyB := ((declaredMethod prog ta₀ (binaryMethod op)).bind (otherParam ·.2)).map (·.ty)
    let iA : Thunk (Expr × Option Ty) := Thunk.mk fun _ => inferExpr prog env (tyA.getD .unknown) a
    let iB : Thunk (Expr × Option Ty) := Thunk.mk fun _ => inferExpr prog env (tyB.getD .unknown) b
    let atA (t : Ty) := if tyA == some t then iA.get else inferExpr prog env t a
    let atB (t : Ty) := if tyB == some t then iB.get else inferExpr prog env t b
    match chooseBinary prog op ta₀ tb₀
      (fun prm => (if a matches .list .. then (atA prm.ty).2 else ta₀) == some prm.ty)
      (fun prm => (if b matches .list .. then (atB prm.ty).2 else tb₀) == some prm.ty)
      (env.canPass prog a₀) (env.canPass prog b₀)
    with
    | some (s, fd, reflected) =>
      let prm := (otherParam fd).getD ⟨.read, "", .unknown⟩
      let a' := if a matches .list .. then literalArg prm (atA prm.ty).1 else a₀
      let b' := if b matches .list .. then literalArg prm (atB prm.ty).1 else b₀
      let m := if reflected then reflectedMethod op else binaryMethod op
      (.call (methodCallee s m reflected) [a', b'], some fd.result)
    | none =>
    let before := compares op && (prog.mainMode || emptyList a || emptyList b ||
      env.heldCopy prog a || env.heldCopy prog b)
    let (a', ta) := if a matches .list .. then
        if tb₀ == some .int then inferExpr prog env .int a
        else if before then inferExpr prog env .unknown a
        else env.compared prog op tb₀ true (inferExpr prog env .unknown a)
      else (a₀, ta₀)
    let b' := if b matches .list .. then
        if ta == some .int then (inferExpr prog env .int b).1
        else if before then (inferExpr prog env (match ta with
          | some t@(.list _) => if op == .eq || op == .ne then t else .unknown
          | _ => .unknown) b).1
        else (env.compared prog op ta false (inferExpr prog env .unknown b)).1
      else b₀
    (.binary op a' b', some (binaryResult op))
  | .list t es =>
    match t, exp, es with
    | .unknown, .int, [e] =>
      let (e', te) := inferExpr prog env .int e
      if te == some .int then (if foldable e' then .list .int [e'] else e', some .int)
      else (.list .unknown [e'], te.map (.array · 1))
    | .unknown, .int, es =>
      (.list .int ((inferList prog env (List.replicate es.length .int) es).map (·.1)), some .int)
    | t, _, es =>
      let n := es.length
      let t := if t == .unknown then openLiteralTy exp else t
      let es' := inferList prog env (List.replicate n (elemExpected t)) es
      let t' := match t, es'.head?.bind (·.2) with
        | .unknown, some u => .array u n
        | t, _ => t
      (.list t (es'.map (·.1)), if t' == .unknown then none else some t')
  | .listInit u args =>
    let args' : List Expr := (inferList prog env [] args).map (·.1)
    (.listInit u (match args' with | [.transfer p] => [.place (.transferred p)] | as => as),
      some (.list u))
  | .withDrops e pre post =>
    let (e', t) := inferExpr prog env exp e
    (.withDrops e' pre post, t)
  termination_by e => (sizeOf e, 0)

/-- Infers inside the arguments `args` of a call, passed to the parameters
`params` in order, or with no type expected past their end. A place
passed `mut` or `ref` stays a place. A literal `[e]` that inference replaced by `e` is a literal again when
it is passed `mut` or `ref`: Mojo passes a temporary there, not the place
or the reference `e` names. -/
def inferArgs (prog : Program) (env : TyEnv) : List Param → List Expr → List Expr
  | prm :: prms, a :: args => inferArg prog env prm a :: inferArgs prog env prms args
  | [], args => (inferList prog env [] args).map (·.1)
  | _ :: _, [] => []
  termination_by _ args => (sizeOf args, 3)

/-- Infers inside the argument `a` passed to the parameter `prm`
(`inferArgs`). -/
def inferArg (prog : Program) (env : TyEnv) (prm : Param) : Expr → Expr
  | .place p =>
    if prm.conv == .mutable || prm.conv == .ref then .place (inferPlace prog env p).1
    else (inferExpr prog env prm.ty (.place p)).1
  | a =>
    let a' := (inferExpr prog env prm.ty a).1
    if a matches .list .. then literalArg prm a' else a'
  termination_by a => (sizeOf a, 1)

/-- Infers inside each of the expressions `es`, expected to have the types
`exps` in order, or `unknown` past their end. -/
def inferList (prog : Program) (env : TyEnv) (exps : List Ty) :
    List Expr → List (Expr × Option Ty)
  | [] => []
  | e :: es => inferExpr prog env (exps.headD .unknown) e :: inferList prog env exps.tail es
  termination_by es => (sizeOf es, 2)
end

mutual
/-- Infers inside the statement `s` of a function whose result type is
`result`, and gives the types in scope after it. -/
def inferStmt (prog : Program) (result : Ty) (env : TyEnv) : Stmt → Stmt × TyEnv
  | .decl x t init =>
    let init' := init.map fun e => inferExpr prog env t e
    let t' := if t == .unknown then ((init'.bind (·.2)).getD .unknown) else t
    (.decl x t' (init'.map (·.1)), env.push x t')
  | .refDecl x e =>
    let (e', t) := inferExpr prog env .unknown e
    let mutable := match e' with
      | .place p => !env.fixed.contains (splitPlace p).1
      | e' => env.mutableAt prog e'
    (.refDecl x e', match t with
      | some t => { env.push x t with fixed := if mutable then env.fixed else x :: env.fixed }
      | none => env)
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
    (.ret (value.map fun e => (inferExpr prog env result e).1), env)
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

/-- The bodies of the functions, initializers, destructors and methods of
the program `prog`, as functions (`deinitDecl`), each with the struct it
belongs to, or none for a free function. -/
def bodies (prog : Program) : List (Option Name × FunDecl) :=
  prog.funs.map (none, ·) ++ prog.structs.flatMap fun sd =>
    (sd.init.toList ++ sd.deinit.toList.map (deinitDecl sd.name) ++ sd.methods).map (some sd.name, ·)

/-- The program of the core calculus that the program `raw`, as parsed,
stands for: the types that a variable hides are marked (`markHidden`), then
`Self` is resolved, then inference fills in what the program leaves open.
Its `twin` holds the bodies that inference gives in `main`'s mode, as a
thunk, inferred only when the checker needs one. -/
def inferRaw (raw : Program) : Program :=
  let prog := resolveSelf (markHidden raw)
  { inferProgram prog with twin := Thunk.mk fun _ => bodies (inferProgram prog.asMain) }

/-- Parses the text of a `.mojo` file into a program of the core calculus,
as `inferRaw` gives it. It does not check the constructs outside the
subset, which `MojoGrimoire.Parse.parseSubset` does. -/
def parse (source : String) : Except SyntaxError Program := do
  pure (inferRaw (← parseRaw source))

end MojoGrimoire.Parse
