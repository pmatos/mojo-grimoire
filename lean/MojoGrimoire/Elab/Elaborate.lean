import MojoGrimoire.Elab.Operations
import MojoGrimoire.Elab.Temps

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

A temporary origin argument of a call that returns a reference, whose
value is dropped, is a local variable of its own, declared where it is made
(`MojoGrimoire.Elab.tempBlock`), so it dies as one, as the last declared:
the compiler keeps it alive until the last use of the reference (#80).

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
A subscript of a struct that Mojo reads late (#191) uses the places among
its getter's arguments: they live until the operands are read, when the
getter is called, and the getter destroys what it last uses right after it,
but what a reference it returns points into (`MojoGrimoire.Elab.Late`),
also under `print`, before `print` writes. On the left of `and` or `or`, it is read as a
subscript of a struct with no setter is, once, as it is evaluated: the
compiler reads it twice there, a bug (D-0011, #211).
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

/-- Elaborates the operands `es`, the last of the operands `args` of
`print`, given the slots `atLoad` live once `print` has read them, but
those of its subscripts. `print` reads its operands once every operand is
evaluated, and a place operand lives until it is done. A subscript that
Mojo reads late calls its getter then, so what the getter last uses dies
right after it, before `print` writes, and lives until then. -/
def elabPrintOps (ctx : Ctx) (args : List Expr) (atLoad : List Place) : List Expr → List Expr
  | [] => []
  | e :: rest =>
    let late := isGetter ctx.prog e
    let live := union atLoad (placeUses ctx ((if late then rest else args).filter (isGetter ctx.prog)))
    let held := placeUses ctx ((args.take (args.length - rest.length - 1)).filter (isGetter ctx.prog))
    (if late then (elabLate ctx e live (union held (usesList ctx.sl rest))).out
      else (elabExpr ctx false e (union live (usesList ctx.sl rest))).out) ::
      elabPrintOps ctx args atLoad rest

/-- Elaborates the operands `args` of `print`, given the slots live after
it (`elabPrintOps`). -/
def elabPrintArgs (ctx : Ctx) (args : List Expr) (after : List Place) : List Expr :=
  elabPrintOps ctx args (union after (placeUses ctx (args.filter (!isGetter ctx.prog ·)))) args

/-- Elaborates the value `e` of a `return`. A call that returns a reference
is read once it is done, so the values it points into that the function
owns live until then, and die then in the order of `owned`. The inner
`withDrops` makes the call one operand, so that they die after it is read,
not before it is made. A subscript read late keeps only what its getter's
reference points into: its getter destroys what else it last uses. -/
def elabReturn (ctx : Ctx) (e : Expr) : Expr :=
  match e, opKeep ctx e with
  | .place _, _ => e
  | e, keep =>
    let e' := (elabExpr ctx false e keep).out
    if keep.isEmpty then e' else .withDrops (.withDrops e' [] []) keep []

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
    let head := diff (liveStmt sl (.whileLoop c body) after) (tempsIn c)
    .whileLoop (elabExpr ctx false c head).out (elabBlock ctx body head) ::
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
    let args' := elabPrintArgs ctx args after
    rest (.print args') (droppedList args' ++ consumedList ctx args)

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
  let body := (tempBlock prog (paramEnv fd.params) 0 fd.body).1
  { fd with
    body := elabBody prog (slotsOf prog none fd.params body) (paramEnv fd.params)
      (ownedParams fd.params).reverse body }

/-- Elaborates the body of the `__deinit__` of the struct `sd`: each field
is a slot of its own, and those whose values are dropped are owned. -/
def elabDeinit (prog : Program) (sd : StructDecl) (body : List Stmt) : List Stmt :=
  let self : Param := ⟨.deinit, "self", .struct sd.name⟩
  let body := (tempBlock prog (paramEnv [self]) 0 body).1
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
