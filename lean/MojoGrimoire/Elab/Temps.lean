import MojoGrimoire.Elab.Origins

/-!
The temporaries that a returned reference may point into (#80).

A call that returns a reference may take a temporary as an origin
argument: an argument that is neither a place nor a call that returns a
reference, such as `T(1)` in `same(T(1))`. Mojo keeps such a temporary
alive as it would an unnamed local variable declared where the argument is
evaluated: until the last use of the reference that points into it. It
then destroys it with the other values that die there, as the one declared
last.

Elaboration gives each such temporary whose value is dropped a hidden
variable of its own (`tempName`), declared with no value right before its
statement, in the same block, and replaces the argument with
`Expr.temp`, which moves the value into it. A statement declares its
hidden variables in the order its temporaries are made, those inside an
argument before the argument's own. Liveness and the drops then treat each
one as a local variable, and a use of a reference into it as a use of it
(`MojoGrimoire.Elab.locSlots`). Two kinds of temporary keep the old
lifetime, ending when their call returns: one inside the index of a place,
which elaboration leaves as it is (#377), and a subscript that Mojo reads
late (#191), which is read only once its call's arguments are evaluated.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- The variable types after the statement `s`, from those before it. -/
def envAfter (prog : Program) (sl : Slots) (env : TyEnv) (s : Stmt) : TyEnv :=
  match s with
  | .decl x t _ => (x, t) :: env
  | .refDecl .. => (aliasStmt prog (sl, env) s).2
  | _ => env

/-- Whether the origin argument `e` is a temporary that gets a hidden
variable: neither a place, a call of a function or a method that returns a
reference, nor a subscript read late. -/
def isTempArg (prog : Program) (env : TyEnv) (e : Expr) : Bool :=
  match e with
  | .place _ => false
  | .call f _ => !lateGetter prog f && !(refCallee prog env e).any (·.1.origin.isSome)
  | e => !(refCallee prog env e).any (·.1.origin.isSome)

/-- For each parameter among `params`, the type of a temporary passed to
it that gets a hidden variable: the parameter's own, when the origin `os`
names it and its values are dropped. -/
def tempParams (os : List Name) (params : List Param) : List (Option Ty) :=
  params.map fun prm => if os.contains prm.name && needsDrop prm.ty then some prm.ty else none

/-- The temporaries made so far in a statement: the number of the next one,
and the number and type of each, the last made first. -/
abbrev Temps := Nat × List (Nat × Ty)

/-- The argument `a`, elaborated inside as `a'`, passed to a parameter
for which `tempParams` gives `o`: a temporary of the type `t` when `o` is
`some t` and `a` is one (`isTempArg`), and else `a'` itself. -/
def wrapTemp (prog : Program) (env : TyEnv) (o : Option Ty) (a a' : Expr) (acc : Temps) :
    Expr × Temps :=
  match o with
  | some t =>
    if isTempArg prog env a then (.temp (tempName acc.1) a', (acc.1 + 1, (acc.1, t) :: acc.2))
    else (a', acc)
  | none => (a', acc)

mutual
/-- Names the temporary origin arguments in the expression `e`, in the
order Mojo evaluates them, but those in the indices of its places. -/
def tempExpr (prog : Program) (env : TyEnv) (acc : Temps) (e : Expr) : Expr × Temps :=
  let ps := match refCallee prog env e with
    | some (⟨_, params, _, some os, _⟩, _) => tempParams os params
    | _ => []
  match e with
  | .call f args => let r := tempArgs prog env ps acc args; (.call f r.1, r.2)
  | .method p m args => let r := tempArgs prog env ps acc args; (.method p m r.1, r.2)
  | .unary op a => let r := tempExpr prog env acc a; (.unary op r.1, r.2)
  | .binary op a b =>
    let r := tempExpr prog env acc a
    let s := tempExpr prog env r.2 b
    (.binary op r.1 s.1, s.2)
  | .list t es => let r := tempArgs prog env [] acc es; (.list t r.1, r.2)
  | .listInit u es => let r := tempArgs prog env [] acc es; (.listInit u r.1, r.2)
  | .withDrops e pre post => let r := tempExpr prog env acc e; (.withDrops r.1 pre post, r.2)
  | .temp x e => let r := tempExpr prog env acc e; (.temp x r.1, r.2)
  | e@(.int _) | e@(.bool _) | e@(.str _) | e@(.place _) | e@(.transfer _) | e@(.copy _) =>
    (e, acc)

/-- Names the temporaries in the arguments `es`, passed to the parameters
for which `tempParams` gives `ps`. -/
def tempArgs (prog : Program) (env : TyEnv) (ps : List (Option Ty)) (acc : Temps) :
    List Expr → List Expr × Temps
  | [] => ([], acc)
  | a :: es =>
    let r := tempExpr prog env acc a
    let w := wrapTemp prog env ps.head?.join a r.1 r.2
    let s := tempArgs prog env ps.tail w.2 es
    (w.1 :: s.1, s.2)
end

/-- The declarations, with no value, of the hidden variables of the
temporaries `ds`, the last made first, in the order they are made. -/
def tempDecls (ds : List (Nat × Ty)) : List Stmt :=
  (ds.map fun (k, t) => .decl (tempName k) t none).reverse

/-- The statement `s'`, whose temporaries are `acc`, after the
declarations of their hidden variables, and the number of the next one. -/
def withTemps (s' : Stmt) (acc : Temps) : List Stmt × Nat :=
  (tempDecls acc.2 ++ [s'], acc.1)

mutual
/-- Names the temporaries of the statement `s`, the first numbered `k`, in
the variables `env`: those of its expressions are declared before it, and
those of the blocks it holds inside them. -/
def tempStmt (prog : Program) (env : TyEnv) (k : Nat) : Stmt → List Stmt × Nat
  | .decl x t (some e) => let r := tempExpr prog env (k, []) e; withTemps (.decl x t (some r.1)) r.2
  | .refDecl x e => let r := tempExpr prog env (k, []) e; withTemps (.refDecl x r.1) r.2
  | .assign p e => let r := tempExpr prog env (k, []) e; withTemps (.assign p r.1) r.2
  | .expr e => let r := tempExpr prog env (k, []) e; withTemps (.expr r.1) r.2
  | .print args => let r := tempArgs prog env [] (k, []) args; withTemps (.print r.1) r.2
  | .ret (some e) => let r := tempExpr prog env (k, []) e; withTemps (.ret (some r.1)) r.2
  | .ifElse c a b =>
    let r := tempExpr prog env (k, []) c
    let ra := tempBlock prog env r.2.1 a
    let rb := tempBlock prog env ra.2 b
    (tempDecls r.2.2 ++ [.ifElse r.1 ra.1 rb.1], rb.2)
  | .whileLoop c body =>
    let r := tempExpr prog env (k, []) c
    let rb := tempBlock prog env r.2.1 body
    (tempDecls r.2.2 ++ [.whileLoop r.1 rb.1], rb.2)
  | .decl x t none => ([.decl x t none], k)
  | .ret none => ([.ret none], k)
  | .pass => ([.pass], k)
  | .drop p => ([.drop p], k)

/-- Names the temporaries of the block `b`, the first numbered `k`, in the
variables `env`. -/
def tempBlock (prog : Program) (env : TyEnv) (k : Nat) : List Stmt → List Stmt × Nat
  | [] => ([], k)
  | s :: rest =>
    let r := tempStmt prog env k s
    let q := tempBlock prog (envAfter prog ⟨none, []⟩ env s) r.2 rest
    (r.1 ++ q.1, q.2)
end

mutual
/-- The hidden variables of the temporaries in the expression `e`. -/
def tempsIn : Expr → List Place
  | .temp x e => .var x :: tempsIn e
  | .call _ args | .method _ _ args | .list _ args | .listInit _ args => tempsList args
  | .unary _ a | .withDrops a _ _ => tempsIn a
  | .binary _ a b => tempsIn a ++ tempsIn b
  | .int _ | .bool _ | .str _ | .place _ | .transfer _ | .copy _ => []

/-- The hidden variables of the temporaries in the expressions `es`. -/
def tempsList : List Expr → List Place
  | [] => []
  | e :: es => tempsIn e ++ tempsList es
end

end MojoGrimoire.Elab
