import MojoGrimoire.Elab.Origins

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
last declared first. The value of a `return` uses them until it is read.
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

/-- Whether each argument of a call of `f` is passed by value, when it is a
place, as its signature says. `len`, which has none, takes its list by
reference. -/
def callModes (prog : Program) (f : Name) : List Bool :=
  match callSig prog f with
  | .ok sig => sig.params.map passedByValue
  | .error _ => []

/-- Whether the receiver `p` of a call of the method `m` with `n` arguments,
and each argument, is passed by value, as the method's signature says. -/
def methodModes (prog : Program) (env : TyEnv) (p : Place) (m : Name) (n : Nat) :
    Bool × List Bool :=
  match (placeTyOf prog env p).bind fun t => (methodSig prog t m n).toOption with
  | some sig => (sig.self.any passedByValue, sig.params.map passedByValue)
  | none => (false, [])

/-- What elaboration knows inside a function: the program, its slots, the
slots it owns in the order they die when several die at once, and the types
of the variables declared so far. -/
structure Ctx where
  prog : Program
  sl : Slots
  owned : List Place
  env : TyEnv

/-- The slot that a call of the method `m` with `n` arguments on the
receiver `p` consumes: `q`, when `p` is `q^`, `q` is a whole slot, and the
method takes `var self`. The call moves it away, so nothing destroys it. -/
def consumedSlot (ctx : Ctx) (p : Place) (m : Name) (n : Nat) : List Place :=
  let self := (placeTyOf ctx.prog ctx.env p).bind fun t =>
    (methodSig ctx.prog t m n).toOption.bind (·.self)
  match self.bind (consumedReceiver ·.conv p) with
  | some q => if ctx.sl.isSlot q then [q] else []
  | none => []

mutual
/-- The slots that the method calls in `e` consume. -/
def consumedIn (ctx : Ctx) : Expr → List Place
  | .method p m args => union (consumedSlot ctx p m args.length) (consumedList ctx args)
  | .call _ args | .list _ args | .listInit _ args => consumedList ctx args
  | .binary _ a b => union (consumedIn ctx a) (consumedIn ctx b)
  | .unary _ a | .withDrops a _ _ => consumedIn ctx a
  | _ => []

/-- The slots that the method calls in `es` consume. -/
def consumedList (ctx : Ctx) : List Expr → List Place
  | [] => []
  | e :: es => union (consumedIn ctx e) (consumedList ctx es)
end

/-- The slots that the operand `e` uses directly, with whether it is passed
by value `m`. A literal `[e]` of type `Int` uses those of `e`, read by
value: a place uses its slots and those of its indices; any other
operand is an operation of its own, which destroys what it last uses. A
call that returns a reference also uses the slots it points into: passed
by reference, they live until the operation is done; passed by value, until
the operands are read, since Mojo reads the reference then, and those the
function owns die then in the order of `owned`. -/
def directOf (ctx : Ctx) (e : Expr) (m : Bool) : List Place × Bool :=
  match e with
  | .place p => (union (ctx.sl.of p) (indexUses ctx.sl p), m)
  | .list .int [x] => directOf ctx x true
  | e =>
    let ls := locSlots ctx.prog ctx.sl ctx.env e
    (if m then ctx.owned.filter (ls.contains ·) else ls, m)

/-- The direct uses of the operands `es`, passed by value as `ms` says. -/
def directArgs (ctx : Ctx) : List Expr → List Bool → List (List Place × Bool)
  | [], _ => []
  | e :: es, ms => directOf ctx e (ms.headD false) :: directArgs ctx es ms.tail

/-- The values that an operation destroys, given the direct uses of its
operands, `direct`, and the slots live once it is done, `after`: those read
by value die once the operands are read, in the order they are read, and
those used by reference once it is done, in the order of `owned`. Also the
slots live once every operand is evaluated. -/
def opDrops (owned : List Place) (direct : List (List Place × Bool)) (after : List Place) :
    List Place × List Place × List Place :=
  let byRef := (direct.filter (!·.2)).foldl (fun acc d => union acc d.1) []
  let byVal := (direct.filter (·.2)).foldl (fun acc d => union acc d.1) []
  let atLoad := union after byRef
  (byVal.filter fun x => owned.contains x && !atLoad.contains x,
   owned.filter fun x => byRef.contains x && !after.contains x,
   union atLoad byVal)

/-- The operation `e`, destroying `pre` once its operands are read and
`post` once it is done; `e` itself when it destroys nothing. -/
def withDropsOf (e : Expr) (pre post : List Place) : Expr :=
  if pre.isEmpty && post.isEmpty then e else .withDrops e pre post

mutual
/-- Elaborates the expression `e`, given the slots live once it is
evaluated, `after`: each operation in it destroys the values whose last use
it is, and a place is left as it is, for the operation or the statement
that uses it. At the top of a statement, `top`, an operation leaves what
dies once it is done to the statement, which destroys it with the
statement's other values. The right operand of `and` and `or` may not run,
so the operation destroys what it uses. -/
def elabExpr (ctx : Ctx) (top : Bool) (e : Expr) (after : List Place) : Expr :=
  match e with
  | .call f args =>
    let d := opDrops ctx.owned (directArgs ctx args (callModes ctx.prog f)) after
    withDropsOf (.call f (elabOps ctx args d.2.2)) d.1 (if top then [] else d.2.1)
  | .method p m args =>
    let ms := methodModes ctx.prog ctx.env p m args.length
    let d := opDrops ctx.owned (directOf ctx (.place p) ms.1 :: directArgs ctx args ms.2)
      after
    let gone := consumedSlot ctx p m args.length
    withDropsOf (.method p m (elabOps ctx args d.2.2)) (diff d.1 gone)
      (if top then [] else diff d.2.1 gone)
  | .binary op a b =>
    if op == .and || op == .or then
      let d := opDrops ctx.owned [directOf ctx a true, (uses ctx.sl b, false)] after
      withDropsOf (.binary op (elabExpr ctx false a d.2.2) b) d.1 (if top then [] else d.2.1)
    else
      let d := opDrops ctx.owned (directArgs ctx [a, b] [true, true]) after
      withDropsOf (.binary op (elabExpr ctx false a (union d.2.2 (uses ctx.sl b)))
        (elabExpr ctx false b d.2.2)) d.1 (if top then [] else d.2.1)
  | .unary op a =>
    let d := opDrops ctx.owned [directOf ctx a true] after
    withDropsOf (.unary op (elabExpr ctx false a d.2.2)) d.1 (if top then [] else d.2.1)
  | .list t es =>
    if t == .int then .list t es else
    let d := opDrops ctx.owned (directArgs ctx es (es.map fun _ => true)) after
    withDropsOf (.list t (elabOps ctx es d.2.2)) d.1 (if top then [] else d.2.1)
  | .listInit u es =>
    let d := opDrops ctx.owned (directArgs ctx es []) after
    withDropsOf (.listInit u (elabOps ctx es d.2.2)) d.1 (if top then [] else d.2.1)
  | .copy p =>
    let d := opDrops ctx.owned [directOf ctx (.place p) false] after
    withDropsOf (.copy p) d.1 (if top then [] else d.2.1)
  | e => e

/-- Elaborates the operands `es`, evaluated in order, given the slots live
once the last is evaluated. -/
def elabOps (ctx : Ctx) (es : List Expr) (after : List Place) : List Expr :=
  match es with
  | [] => []
  | e :: rest => elabExpr ctx false e (union after (usesList ctx.sl rest)) :: elabOps ctx rest after
end

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

/-- The slots that the elaborated optional expression `e` destroys. -/
def droppedOpt : Option Expr → List Place
  | some e => droppedIn e
  | none => []

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
it, given what its expressions destroy or consume, dies right after it. -/
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
    let e' := elabExpr ctx true e (union after target)
    rest (.assign p e') (droppedIn e' ++ consumedIn ctx e)
  | .expr e =>
    let e' := elabExpr ctx true e after
    rest (.expr e') (droppedIn e' ++ consumedIn ctx e)
  | .print args =>
    let args' := elabOps ctx args (union after (placeUses ctx args))
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
  ⟨prog.structs.map (elabStruct prog), prog.funs.map (elabFun prog)⟩

end MojoGrimoire.Elab
