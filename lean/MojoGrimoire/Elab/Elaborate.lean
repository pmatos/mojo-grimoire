import MojoGrimoire.Elab.Operands

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
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

mutual
/-- The slots that the elaborated expression `e` destroys. -/
def droppedIn : Expr → List Place
  | .withDrops e pre post => pre ++ post ++ droppedIn e
  | .call _ args | .method _ _ args | .list _ args | .listInit _ args => droppedList args
  | .binary _ a b => droppedIn a ++ droppedIn b
  | .unary _ a => droppedIn a
  | _ => []

/-- The slots that the elaborated expressions `es` destroy. -/
def droppedList : List Expr → List Place
  | [] => []
  | e :: es => droppedIn e ++ droppedList es
end

mutual
/-- Elaborates the expression `e`, given the slots live once it is
evaluated, `after`: each operation in it destroys the values whose last use
it is, and a place is left as it is, for the operation or the statement
that uses it. At the top of a statement, `top`, an operation leaves what
dies once it is done to the statement, which destroys it with the
statement's other values. The right operand of `and` and `or` may not run:
it destroys what it uses once it is read when it runs, and the operation
when it does not, before what the left one last uses, which dies once it
is tested (#191). -/
def elabExpr (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) : Expr :=
  match e with
  | .call f args =>
    let d := opDrops ctx.owned (directArgs ctx args (callModes ctx.prog f)) after
    withDropsOf (.call f (elabOps ctx args d.2.2 [])) d.1 (if top then [] else d.2.1)
  | .method p m args =>
    let ms := methodModes ctx.prog ctx.env p m args.length
    let d := opDrops ctx.owned (directOf ctx (.place p) ms.1 :: directArgs ctx args ms.2)
      after
    let gone := consumedSlot ctx p m args.length
    withDropsOf (.method p m (elabOps ctx args d.2.2 [])) (diff d.1 gone)
      (if top then [] else diff d.2.1 gone)
  | .binary op a b =>
    if op == .and || op == .or then
      let a₀ := if isGetter ctx.prog a then locOperand ctx a true else directOf ctx a true
      let d := opDrops ctx.owned [a₀, (uses ctx.sl b, false)] after
      let b' := elabExpr ctx false b (union after (opKeep ctx b))
      let rest := diff d.2.1 (droppedIn b')
      let b'' := if rest.isEmpty then b' else .withDrops (.withDrops b' [] []) [] rest
      withDropsOf (.binary op (elabExpr ctx false a d.2.2) b'') d.1 d.2.1
    else
      let byVal := fun e => ((refSlots ctx.prog ctx.sl ctx.env e).2.bind (seqCompare op)).isNone
      let d := opDrops ctx.owned (directArgs ctx [a, b] [byVal a, byVal b]) after
      let late := lateValue ctx.prog
      let held := if isGetter ctx.prog a then placeUses ctx [a] else []
      let a' := if late a then
          elabLate ctx a (union d.2.2 (placeUses ctx ([b].filter (isGetter ctx.prog)))) (uses ctx.sl b)
        else elabExpr ctx false a (union d.2.2 (uses ctx.sl b))
      let b' := if late b then elabLate ctx b d.2.2 held else elabExpr ctx false b (union d.2.2 held)
      withDropsOf (.binary op a' b') d.1 (if top then [] else d.2.1)
  | .unary op a =>
    let d := opDrops ctx.owned (directArgs ctx [a] [true]) after
    withDropsOf (.unary op (elabExpr ctx false a d.2.2)) d.1 (if top then [] else d.2.1)
  | .list t es =>
    if t == .int then .list t (elabOps ctx es after []) else
    let d := opDrops ctx.owned (directArgs ctx es (es.map fun _ => true)) after
    withDropsOf (.list t (elabOps ctx es d.2.2 [])) d.1 (if top then [] else d.2.1)
  | .listInit u es =>
    let d := opDrops ctx.owned (directArgs ctx es []) after
    withDropsOf (.listInit u (elabOps ctx es d.2.2 [])) d.1 (if top then [] else d.2.1)
  | .copy p =>
    let d := opDrops ctx.owned [directOf ctx (.place p) false] after
    withDropsOf (.copy p) d.1 (if top then [] else d.2.1)
  | e => e

/-- Elaborates the operands `es`, evaluated in order, given the slots live
once they are read, `after`, and those that the subscripts read late
before them use, `held`. Each is evaluated while those and what the
operands after it use live; a subscript read late that gives a value is
read later, while what those after it use lives. -/
def elabOps (ctx : Ctx) (es : List Expr) (after held : List Place) : List Expr :=
  match es with
  | [] => []
  | e :: rest =>
    let held' := if isGetter ctx.prog e then union held (placeUses ctx [e]) else held
    if lateValue ctx.prog e then
      elabLate ctx e (union after (placeUses ctx (rest.filter (isGetter ctx.prog))))
        (union held (usesList ctx.sl rest)) :: elabOps ctx rest after held'
    else
      elabExpr ctx false e (union (union after held) (usesList ctx.sl rest)) ::
        elabOps ctx rest after held'

/-- Elaborates the subscript read late `e`, given the slots live once it is
read, `after`: the slots `held`, which the subscripts read late before it
and the operands after it use, live while its arguments are evaluated, in
operand order, since their getters are called, and those operands read,
later. -/
def elabLate (ctx : Ctx) (e : Expr) (after held : List Place) : Expr :=
  match e with
  | .call f args =>
    let d := opDrops ctx.owned (directArgs ctx args (callModes ctx.prog f)) after
    withDropsOf (.call f (elabOps ctx args d.2.2 held)) d.1 d.2.1
  | e => e
end

/-- The slots that the elaborated optional expression `e` destroys. -/
def droppedOpt : Option Expr → List Place
  | some e => droppedIn e
  | none => []

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
    (if late then elabLate ctx e live (union held (usesList ctx.sl rest))
      else elabExpr ctx false e (union live (usesList ctx.sl rest))) ::
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
    let e' := elabExpr ctx false e keep
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
      (droppedIn c' ++ consumedIn ctx c)
    [.ifElse c'
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
    rest (.decl x t init') (droppedOpt init' ++ (init.map (consumedIn ctx)).getD [])
  | .refDecl x e =>
    let e' := elabExpr ctx true e after
    rest (.refDecl x e') (droppedIn e' ++ consumedIn ctx e)
  | .assign p e =>
    let target := if sl.isSlot p then indexUses sl p else union (sl.of p) (indexUses sl p)
    let old := if sl.isSlot p then [p] else []
    let e' := elabExpr ctx true e (union (diff after old) target)
    rest (.assign p e') (droppedIn e' ++ consumedIn ctx e)
  | .expr e =>
    let e' := elabExpr ctx true e after
    rest (.expr e') (droppedIn e' ++ consumedIn ctx e)
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
