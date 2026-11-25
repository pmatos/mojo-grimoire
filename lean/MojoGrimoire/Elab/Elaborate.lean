import MojoGrimoire.Elab.Operations

/-!
ASAP elaboration: the insertion of an explicit `drop` wherever Mojo destroys
a value.

Mojo destroys a value right after its last use. Elaboration makes those
points explicit, so that the interpreter only destroys what a `drop` or a
`withDrops` names, and what remains when a function returns. A value is
destroyed:

- inside an expression, when an operation nested in it last uses the value:
  right after the operation reads it, for an operand passed by value, or
  right after the operation is done, for one passed by reference;
- right after the statement that last uses it otherwise, or right after the
  declaration or assignment that gives it when nothing uses it, even when
  that assignment destroys or consumes the old value, as in
  `s = s^.consume()`;
- at the start of a branch of an `if` that does not use it, when the test
  or the other branch does;
- right after a loop that uses it, since the next iteration might use it;
- at the start of a function body, for a `var` parameter the body never
  uses.

A value moved away with `^` is not destroyed: its new owner destroys it.
Nor is one that `p^.m(…)` gives to a method that takes `var self`. A
use of a reference bound with `ref` is a use of every value it may point
into, so those values live until its last use. A call that returns a
reference, passed by reference to an operation, uses the values it points
into the same way, so they live until that operation is done; read by
value, it uses them until the operation's operands are read, since Mojo
reads the reference only then, and those that die then are destroyed the
last declared first. An operand of a comparison of two arrays or two
lists is passed by reference (#166, #185). The value of a `return` uses
them until it is read.
Inside `__deinit__(deinit self)`, each field of `self` is destroyed on its own,
at the same points, so a field the body never uses is destroyed before the
body runs.

Only values of struct type, and lists and arrays of them, are dropped:
values of the other types of the core calculus have no destruction that can
be observed.
Several values destroyed at the same point are destroyed as the compiler
does: the parameters first, then the local variables, each the last
declared first; the fields of `self` in `__deinit__` in their order, and
values read by value in the order they are read.

`MojoGrimoire.Elab.Operations` elaborates the operations inside
expressions; this module elaborates statements, blocks and bodies.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- Whether a value of type `t` is dropped: one of struct type, or a list
or an array of them. -/
def needsDrop : Ty → Bool
  | .struct _ => true
  | .list t | .array t _ => needsDrop t
  | _ => false

/-- The statements that drop the slots of `d`, in the order of `owned`, the
slots a function owns, in the order they die when several die at once. A
slot that the function does not own, such as a borrowed parameter, is never
dropped. -/
def drops (owned d : List Place) : List Stmt :=
  (owned.filter (d.contains ·)).map .drop

/-- The slots that the simple statement `s` defines: a declaration with an
initial value, or an assignment to a whole slot. -/
def defs (sl : Slots) : Stmt → List Place
  | .decl x _ (some _) => [.var x]
  | .assign p _ => if sl.isSlot p then [p] else []
  | _ => []

/-- The slots that the simple statement `s` uses. An assignment to a part of
a slot uses the slot. -/
def usesStmt (sl : Slots) : Stmt → List Place
  | .decl _ _ init => usesOpt sl init
  | .refDecl _ e => uses sl e
  | .assign p e =>
    if sl.isSlot p then uses sl e else union (uses sl e) (union (sl.of p) (indexUses sl p))
  | .expr e => uses sl e
  | .print args => usesList sl args
  | _ => []

/-- The slots that the simple statement `s` moves away whole. -/
def movesStmt (sl : Slots) : Stmt → List Place
  | .decl _ _ (some e) | .refDecl _ e | .expr e => moves sl e
  | .assign p e => union (moves sl e) (indexMoves sl p)
  | .print args => movesList sl args
  | _ => []

/-- The slots that die right after the simple statement `s`, given the
slots `gone` that its expressions destroy or consume, and the slots `after`
live after it: those it uses but neither moves away nor leaves in `gone`,
and those it defines, unless they are live. `gone` holds values that die
before `s` defines anything, so it never holds the value that `s` defines,
even when an assignment destroys or consumes the old value of the slot it
assigns. -/
def dying (sl : Slots) (s : Stmt) (gone after : List Place) : List Place :=
  diff (union (diff (usesStmt sl s) (union (movesStmt sl s) gone)) (defs sl s)) after

mutual
/-- The local variables whose values are dropped that the statement `s`
declares, in order, each once. -/
def declared : Stmt → List Place
  | .decl x t _ => if needsDrop t then [.var x] else []
  | .ifElse _ a b => union (declaredBlock a) (declaredBlock b)
  | .whileLoop _ body => declaredBlock body
  | _ => []

/-- The local variables whose values are dropped that the block `b`
declares, in order, each once. -/
def declaredBlock : List Stmt → List Place
  | [] => []
  | s :: rest => union (declared s) (declaredBlock rest)
end

/-- The slots that the operands `es`, read by reference, use directly. -/
def placeUses (ctx : Ctx) : List Expr → List Place
  | [] => []
  | e :: es => union (directOf ctx e false).1 (placeUses ctx es)

/-- Elaborates the value `e` of a `return`. A call that returns a reference
is read once it is done, so the values it points into that the function
owns live until then, and die then in the order of `owned`. The inner
`withDrops` makes the call one operand, so that they die after it is read,
not before it is made. -/
def elabReturn (ctx : Ctx) (e : Expr) : Expr :=
  match e, directOf ctx e true with
  | .place _, _ => e
  | e, (keep, _) =>
    let e' := (elabExpr ctx false e keep).out
    if keep.isEmpty then e' else .withDrops (.withDrops e' [] []) keep []

/-- The variable types after the statement `s`, from those before it. -/
def envAfter (prog : Program) (sl : Slots) (env : TyEnv) (s : Stmt) : TyEnv :=
  match s with
  | .decl x t _ => (x, t) :: env
  | .refDecl .. => (aliasStmt prog (sl, env) s).2
  | _ => env

mutual
/-- Elaborates the statement `s`, given the slots live after it. What dies at
it, given what its expressions destroy or consume, dies right after it. The
value that an assignment to a whole slot replaces is not live after its
expression, whether or not the new one is (#191). -/
def elabStmt (ctx : Ctx) (s : Stmt) (after : List Place) : List Stmt :=
  let sl := ctx.sl
  let rest (s' : Stmt) (inner : List Place) : List Stmt :=
    s' :: drops ctx.owned (dying sl s inner after)
  match s with
  | .ifElse c a b =>
    let la := liveBlock sl a after
    let lb := liveBlock sl b after
    let c' := elabExpr ctx true c (union la lb)
    let avail := diff (diff (liveStmt sl (.ifElse c a b) after) (moves sl c))
      (c'.dropped ++ consumedIn ctx c)
    [.ifElse c'.out
      (drops ctx.owned (diff avail la) ++ elabBlock ctx a after)
      (drops ctx.owned (diff avail lb) ++ elabBlock ctx b after)]
  | .whileLoop c body =>
    let head := liveStmt sl (.whileLoop c body) after
    .whileLoop c (elabBlock ctx body head) ::
      drops ctx.owned (diff head (after ++ consumedIn ctx c))
  | .ret value => [.ret (value.map (elabReturn ctx))]
  | .pass => [.pass]
  | .drop p => [.drop p]
  | .decl x t init =>
    let init' := init.map (elabExpr ctx true · after)
    rest (.decl x t (init'.map (·.out)))
      ((init'.map (·.dropped)).getD [] ++ (init.map (consumedIn ctx)).getD [])
  | .refDecl x e =>
    let e' := elabExpr ctx true e after
    rest (.refDecl x e'.out) (e'.dropped ++ consumedIn ctx e)
  | .assign p e =>
    let target := if sl.isSlot p then indexUses sl p else union (sl.of p) (indexUses sl p)
    let old := if sl.isSlot p then [p] else []
    let e' := elabExpr ctx true e (union (diff after old) target)
    rest (.assign p e'.out) (e'.dropped ++ consumedIn ctx e)
  | .expr e =>
    let e' := elabExpr ctx true e after
    rest (.expr e'.out) (e'.dropped ++ consumedIn ctx e)
  | .print args =>
    let args' := elabOps ctx args (union after (placeUses ctx args))
    rest (.print args'.out) (args'.dropped ++ consumedList ctx args)

/-- Elaborates the block `b`, given the slots live after it. -/
def elabBlock (ctx : Ctx) (b : List Stmt) (after : List Place) : List Stmt :=
  match b with
  | [] => []
  | s :: rest =>
    elabStmt ctx s (liveBlock ctx.sl rest after) ++
      elabBlock { ctx with env := envAfter ctx.prog ctx.sl ctx.env s } rest after
end

/-- Elaborates a function body. `params` is the slots the function owns on
entry, in the order they die when several die at once; those the body never
uses are dropped before it runs. The local variables die after them, the
last declared first. -/
def elabBody (prog : Program) (sl : Slots) (env : TyEnv) (params : List Place)
    (body : List Stmt) : List Stmt :=
  let owned := union params (declaredBlock body).reverse
  drops owned (diff params (liveBlock sl body [])) ++ elabBlock ⟨prog, sl, owned, env⟩ body []

/-- The slots of the `var` parameters among `params` whose values are dropped. -/
def ownedParams (params : List Param) : List Place :=
  (params.filter fun prm => prm.conv == .owned && needsDrop prm.ty).map (.var ·.name)

/-- The types of the parameters `params`. -/
def paramEnv (params : List Param) : TyEnv := params.map fun prm => (prm.name, prm.ty)

/-- Elaborates a function, a method or an initializer of the program
`prog`. -/
def elabFun (prog : Program) (fd : FunDecl) : FunDecl :=
  { fd with
    body := elabBody prog (slotsOf prog none fd.params fd.body) (paramEnv fd.params)
      (ownedParams fd.params).reverse fd.body }

/-- Elaborates the body of the `__deinit__` of the struct `sd`: each field
is a slot of its own, and those whose values are dropped are owned. -/
def elabDeinit (prog : Program) (sd : StructDecl) (body : List Stmt) : List Stmt :=
  let self : Param := ⟨.deinit, "self", .struct sd.name⟩
  elabBody prog (slotsOf prog (some (sd.fields.map (·.1))) [self] body) (paramEnv [self])
    ((sd.fields.filter (needsDrop ·.2)).map (.field (.var "self") ·.1)) body

/-- Elaborates a struct: its initializer, destructor and methods. -/
def elabStruct (prog : Program) (sd : StructDecl) : StructDecl :=
  { sd with
    init := sd.init.map (elabFun prog)
    deinit := sd.deinit.map (elabDeinit prog sd)
    methods := sd.methods.map (elabFun prog) }

/-- Elaborates a program. It expects a program that the checker accepts and
that holds no `drop`. -/
def elabProgram (prog : Program) : Program :=
  { prog with structs := prog.structs.map (elabStruct prog), funs := prog.funs.map (elabFun prog) }

end MojoGrimoire.Elab
