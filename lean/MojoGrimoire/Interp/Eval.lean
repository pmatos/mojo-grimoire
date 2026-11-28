import MojoGrimoire.Interp.Args

/-!
The big-step evaluation of elaborated programs.

Evaluation goes left to right, as in Mojo: operands, arguments, list
elements and printed values in order; `MojoGrimoire.Interp.Args` says
when each is read. A literal of type `Int`, `[e]`, is the value of `e`,
read into a temporary when passed `ref`. A method callee `S.m` runs the
method `m` of `S` on its receiver, the first argument (#191); `and` and
`or` on structs give the operand that decides (`evalLogic`). Every
function takes fuel, which each step spends: a run that spends it all
stops with `outOfFuel`, so every run ends. The standard library's
`range`, which only `List[u](…)` takes (#121), gives the list of its
`Int`s, whose length the fuel left at the call bounds.

When values are destroyed is in `MojoGrimoire.Interp.Machine`.
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core MojoGrimoire.Check

mutual
/-- Destroys the value `v`. -/
def destroy (prog : Program) (fuel : Nat) (v : Value) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => if v.empty then pure () else match v with
    | .struct s fs => do
      if fs.any (·.2.empty) then stuck s!"destroying a partly built {s}"
      let some sd := findStruct prog s | stuck s!"unknown struct {s}"
      match sd.deinit with
      | some body => do
        let r ← alloc v
        let _ ← runBody prog n false [("self", ⟨r, false, .struct s⟩)] body
      | none => fs.forM fun (_, w) => destroy prog n w
    | .list es => es.forM (destroy prog n)
    | _ => pure ()

/-- Runs a function body from the variables `env`, and gives back what it
returns: a reference when `refs` holds, for a function with an origin.
Whatever the function still owns is destroyed when it returns. -/
def runBody (prog : Program) (fuel : Nat) (refs : Bool) (env : Env) (body : List Stmt) :
    EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => tryCatch (do
      let env' ← execBlock prog n refs env body
      destroyOwned prog n env'
      pure (.value .none)) fun
      | .returned r => pure r
      | e => throw e

/-- Destroys what is left of each owned variable of `env`, in the order of
their declaration. -/
def destroyOwned (prog : Program) (fuel : Nat) (env : Env) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => env.reverse.forM fun (_, b) => do
    if b.owned then destroy prog n (← take b.ref)

/-- The reference that the place `p` names. An index is checked against the
length of the list, or, into an `Int`, which is its own one element, against
1 (#127). -/
def placeRef (prog : Program) (fuel : Nat) (env : Env) (p : Place) : EvalM Ref :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match p with
    | .var x => lookupVar env x
    | .field q f => do
      let r ← placeRef prog n env q
      pure { r with path := r.path ++ [.field f] }
    | .index q i => do
      let r ← placeRef prog n env q
      let k ← asInt (← evalExpr prog n env i)
      match ← readRef r with
      | .list es => do
        let j ← position es.length k
        pure { r with path := r.path ++ [.elem j] }
      | .int _ => do let _ ← position 1 k; pure r
      | _ => stuck "index into a value that is not a list"
    | .transferred q => placeRef prog n env q

/-- The value of the expression `e`. A call that returns a reference gives
the value it points to. -/
def evalExpr (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Value :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .int k => pure (.int k)
    | .bool b => pure (.bool b)
    | .str _ => stuck "a string outside print"
    | .place p | .copy p => do readRef (← placeRef prog n env p)
    | .transfer p => do take (← placeRef prog n env p)
    | .unary op a => do unary op (← evalExpr prog n env a)
    | .binary .and a b => evalLogic prog n env false a b [] []
    | .binary .or a b => evalLogic prog n env true a b [] []
    | .binary op a b => do
      let os := [← evalOperand prog n env a, ← evalOperand prog n env b]
      let [x, y] ← loadFirst Operand.rank (loadOperand prog n env) os | stuck "two operands"
      binary op x y
    | .list .int [e] => evalExpr prog n env e
    | .list _ es => do
      let os ← es.mapM (evalOperand prog n env)
      pure (.list (← os.mapM (loadOperand prog n env)))
    | .listInit _ [a] => evalListArg prog n env a
    | e => do (← evalResult prog n env e).read

/-- What the expression `e` gives: for a call, what it returns, which is a
reference for a call that returns one; for any other expression, its
value. -/
def evalResult (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .call .. | .method .. => evalCall prog n env e []
    | .temp x e => do pure (.ref (← fillTemp env x (← evalExpr prog n env e)))
    | .withDrops e pre post => do
      if let .binary op a b := e then if op == .and || op == .or then
        return .value (← evalLogic prog n env (op == .or) a b pre post)
      let r ← match e with
        | .call .. | .method .. => evalCall prog n env e pre
        | e => do
          let v ← evalExpr prog n env e
          dropAll prog n env pre
          pure (.value v)
      dropAll prog n env post
      pure r
    | e => do pure (.value (← evalExpr prog n env e))

/-- Takes the values out of the places `ps` and destroys them, in order. -/
def dropAll (prog : Program) (fuel : Nat) (env : Env) (ps : List Place) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => ps.forM fun p => do destroy prog n (← take (← placeRef prog n env p))

/-- The operand `e`: a place, or a call that returns a reference, is
located, a subscript read late has its arguments evaluated, its getter
called once the operand is read, and any other expression is evaluated. -/
def evalOperand (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Operand :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .place p => do pure (.loc (← placeRef prog n env p))
    | e => match lateCall prog e with
      | some (f, args, pre, post) => do
        let some fd := findCallee prog f | stuck s!"unknown function {f}"
        pure (.getter fd (← evalArgs prog n env fd.params args) pre post)
      | none => do
        match ← evalResult prog n env e with
        | .ref r => pure (.loc r)
        | .value v => pure (.val v)

/-- The value of the operand `o`, once every operand of its operation has
been evaluated. -/
def loadOperand (prog : Program) (fuel : Nat) (env : Env) (o : Operand) : EvalM Value :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match o with
    | .loc r => readRef r
    | .val v => pure v
    | .getter fd args pre post => do (← loadGetter prog n env fd args pre post).read

/-- Calls the getter `fd` of a subscript read late, with the arguments
`args`, destroying `pre` once they are read and `post` once it is done. -/
def loadGetter (prog : Program) (fuel : Nat) (env : Env) (fd : FunDecl) (args : List Pending)
    (pre post : List Place) : EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => do
    let args ← loadArgs prog n env args
    dropAll prog n env pre
    let r ← callFun prog n fd args
    dropAll prog n env post
    pure r

/-- The arguments of a call, once every argument has been evaluated: each
pending operand is read, the subscripts read late first (`loadFirst`). -/
def loadArgs (prog : Program) (fuel : Nat) (env : Env) (ps : List Pending) :
    EvalM (List Arg) :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => loadFirst Pending.rank (loadArg prog n env) ps

/-- The argument that the pending argument `p` gives once it is read. -/
def loadArg (prog : Program) (fuel : Nat) (env : Env) (p : Pending) : EvalM Arg :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match p with
    | .arg a => pure a
    | .load o | .copy o => do pure (.value (← loadOperand prog n env o))
    | .temp (.getter fd as pre post) => do
      match ← loadGetter prog n env fd as pre post with
      | .ref r => pure (.place r)
      | .value v => pure (.temp v)
    | .temp o => do pure (.temp (← loadOperand prog n env o))

/-- `a and b`, or `a or b` when `isOr`: `b` runs only when `a` does not
decide. On structs it gives the operand that decides, which `__bool__`
tests by reference, or a copy of it to a `var self` (#191): `a` copied,
or moved out of its temporary,
which dies when `b` decides. A test of `a` that inference made gives a
`var self` a copy (`copiedTest`), and a temporary dies once copied.
`pre` dies once `a` is tested, after `post` when it decides; `b`
destroys what it uses. A subscript read late is read at once, its getter
called once, as one of a struct with no setter is (#211). -/
def evalLogic (prog : Program) (fuel : Nat) (env : Env) (isOr : Bool) (a b : Expr)
    (pre post : List Place) : EvalM Value :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => do
    let o ← match copiedTest prog a with
      | some (fd, e) => do
        let v ← match ← evalOperand prog n env e with
          | .loc r => readRef r
          | .val v => do destroy prog n v; pure v
          | .getter fd as p q => do match ← loadGetter prog n env fd as p q with
            | .ref r => readRef r
            | .value v => do destroy prog n v; pure v
        pure (Operand.val (← (← callFun prog n fd [.value v]).read))
      | none => evalOperand prog n env a
    let (v, r, temp) ← match o with
      | .getter fd as p q => do
        match ← loadGetter prog n env fd as p q with
        | .ref r => pure (← readRef r, some r, false)
        | .value v@(.struct ..) => pure (v, some (← alloc v), true)
        | .value v => pure (v, none, false)
      | .loc r => do pure (← readRef r, some r, false)
      | .val v@(.struct ..) => do pure (v, some (← alloc v), true)
      | .val v => pure (v, none, false)
    let decides ← match v, r with
      | .struct s _, some r => do
        let some fd := (findStruct prog s).bind (findMethod · "__bool__")
          | stuck s!"a {s} with no __bool__"
        let arg := if fd.params.head?.any (·.conv == .owned) then Arg.value v else .place r
        pure ((← asBool (← (← callFun prog n fd [arg]).read)) == isOr)
      | v, _ => do pure ((← asBool v) == isOr)
    if decides then
      let w ← match r with
        | some r => do
          let w ← if temp then take r else readRef r
          dropAll prog n env post
          pure w
        | none => do dropAll prog n env post; pure v
      dropAll prog n env pre
      pure w
    else
      if let (true, some r) := (temp, r) then destroy prog n (← take r)
      dropAll prog n env pre
      evalExpr prog n env b

/-- The arguments `args` passed to the parameters `params`, before the
places and returned references passed by value are read. A place passed
to a `read`, `mut` or `ref` parameter is passed by reference, except an
`Int` or a `Bool` passed `read`, and so is the reference that a call
returns; anything else is passed by value. -/
def evalArgs (prog : Program) (fuel : Nat) (env : Env) :
    List Param → List Expr → EvalM (List Pending)
  | prms, args => match fuel with
    | 0 => fail .outOfFuel
    | n + 1 => match prms, args with
      | prm :: prms, a :: args => do
        let x ← match prm.conv, a with
          | .owned, a => do pure (.copy (← evalOperand prog n env a))
          | .read, .place p =>
            if prm.ty.byValue then do pure (.load (← evalOperand prog n env (.place p)))
            else do pure (.arg (.place (← placeRef prog n env p)))
          | _, .place p => do pure (.arg (.place (← placeRef prog n env p)))
          | _, .list .int [e] => do pure (.load (← evalOperand prog n env e))
          | _, a => match lateCall prog a with
            | some _ => do
              let o ← evalOperand prog n env a
              pure (if passedByValue prm then .load o else .temp o)
            | none => do match ← evalResult prog n env a with
              | .ref r => if passedByValue prm then pure (.load (.loc r)) else pure (.arg (.place r))
              | .value v => pure (.arg (.temp v))
        pure (x :: (← evalArgs prog n env prms args))
      | _, _ => pure []

/-- Calls the function `fd` with the arguments `args`, then destroys the
temporaries among them. -/
def callFun (prog : Program) (fuel : Nat) (fd : FunDecl) (args : List Arg) : EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => do
    let env ← bindParams fd.params args
    let r ← runBody prog n fd.origin.isSome env fd.body
    for a in args do
      if let .temp v := a then destroy prog n v
    pure r

/-- Evaluates a call, a construction or a method call, destroying `pre`
once the arguments are read, before the call is made. -/
def evalCall (prog : Program) (fuel : Nat) (env : Env) (e : Expr) (pre : List Place) :
    EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .call f args =>
      match findStruct prog f, findCallee prog f, f, args with
      | some sd, _, _, _ => do
        match sd.init with
        | some fd => do
          let self ← alloc (← emptyStruct prog n sd)
          let rest ← loadArgs prog n env (← evalArgs prog n env fd.params.tail args)
          dropAll prog n env pre
          let _ ← callFun prog n fd (.place self :: rest)
          pure (.value (← readRef self))
        | none => do
          let os ← args.mapM (evalOperand prog n env)
          let vs ← loadFirst (fun (o, t) => fieldRank o t) (loadOperand prog n env ·.1)
            (os.zip (sd.fields.map (·.2)))
          dropAll prog n env pre
          pure (.value (.struct sd.name (sd.fields.zip vs |>.map fun ((x, _), v) => (x, v))))
      | none, some fd, _, _ => do
        let args ← loadArgs prog n env (← evalArgs prog n env fd.params args)
        dropAll prog n env pre
        callFun prog n fd args
      | none, none, "len", [a] => do
        let k ← match ← evalListArg prog n env a with
          | .list es => pure es.length
          | .int _ => pure 1
          | _ => stuck "len of a value that is not a list or an Int"
        dropAll prog n env pre
        pure (.value (.int k))
      | none, none, "range", args => do
        let vs ← loadArgs prog n env (← evalArgs prog n env (rangeParams args.length) args)
        dropAll prog n env pre
        pure (.value (← rangeOf n vs))
      | _, _, _, _ => stuck s!"unknown function {f}"
    | .method p m args => do
      let r ← placeRef prog n env p
      match ← readRef r with
      | .list _ => do
        let vs ← args.mapM (evalExpr prog n env)
        dropAll prog n env pre
        listMethodOn r m vs
      | .struct s _ => do
        let some fd := (findStruct prog s).bind (findMethod · m) | stuck s!"unknown method {m}"
        let some self := fd.params.head? | stuck "a method with no self"
        let rest ← evalArgs prog n env fd.params.tail args
        let recv ← if self.conv == .owned then do pure (Arg.value (← readRef r))
          else pure (Arg.place r)
        let args ← loadArgs prog n env rest
        if (consumedReceiver self.conv p).isSome then let _ ← take r
        dropAll prog n env pre
        callFun prog n fd (recv :: args)
      | _ => stuck "a method call on a value that is not a struct"
    | _ => stuck "not a call"

/-- The list or `Int` that `len` reads, or the list that `List[u](e)`
copies: a place or a returned reference, read where it is, or a value,
then destroyed. -/
def evalListArg (prog : Program) (fuel : Nat) (env : Env) (a : Expr) : EvalM Value :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match a with
    | .place p => do readRef (← placeRef prog n env p)
    | a => do
      match ← evalResult prog n env a with
      | .ref r => readRef r
      | .value v => do
        destroy prog n v
        pure v

/-- The reference that `e` names, for a `ref` binding or the `return` of a
function with an origin: a place, or a call that returns a reference. -/
def evalRef (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Ref :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .place p => placeRef prog n env p
    | e => do
      let .ref r ← evalResult prog n env e | stuck "a call that returns no reference"
      pure r

/-- Runs the statement `s` of a function that returns a reference when
`refs` holds, and gives the variables in scope after it. -/
def execStmt (prog : Program) (fuel : Nat) (refs : Bool) (env : Env) (s : Stmt) :
    EvalM Env :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match s with
    | .pass => pure env
    | .decl x t init => do
      let v ← match init with
        | some e => evalExpr prog n env e
        | none => blankOf prog n t
      pure ((x, ⟨← alloc v, true, t⟩) :: env)
    | .refDecl x e => do pure ((x, ⟨← evalRef prog n env e, false, refTy prog env e⟩) :: env)
    | .assign p e => do
      let (v, r) ← match intElem prog env p with
        | some (q, i) => do
          let r ← placeRef prog n env q
          let o ← evalOperand prog n env i
          let v ← evalExpr prog n env e
          let _ ← position 1 (← asInt (← loadOperand prog n env o))
          pure (v, r)
        | none => do
          let q ← fixIndices (fun i => do asInt (← evalExpr prog n env i)) (placeRef prog n env) p
          let v ← evalExpr prog n env e
          pure (v, ← placeRef prog n env q)
      let old ← readRef r
      writeRef r v
      destroy prog n old
      pure env
    | .expr e => do
      destroy prog n (← evalExpr prog n env e)
      pure env
    | .print args => do
      let os ← args.mapM fun
        | .str t => pure (Sum.inl t)
        | a => do pure (Sum.inr (← evalOperand prog n env a))
      let late := fun | Sum.inr (o : Operand) => o.rank | .inl _ => 2
      let parts ← loadFirst late (fun
        | .inl t => pure t
        | .inr o => do pure (← loadOperand prog n env o).show) os
      emit (" ".intercalate parts)
      pure env
    | .ifElse c a b => do
      let _ ← execBlock prog n refs env (if ← asBool (← evalExpr prog n env c) then a else b)
      pure env
    | .whileLoop c body => do
      if ← asBool (← evalExpr prog n env c) then
        let _ ← execBlock prog n refs env body
        execStmt prog n refs env (.whileLoop c body)
      else pure env
    | .ret value => do
      let r ← match value with
        | none => pure (Result.value .none)
        | some e =>
          if refs then do pure (Result.ref (← evalRef prog n env e))
          else evalReturn prog n env e
      destroyOwned prog n env
      throw (.returned r)
    | .drop p => do
      dropAll prog n env [p]
      pure env

/-- What `return e` gives back in a function that returns a value: `return
x` of a variable the function owns moves it out, and any other expression
is evaluated. -/
def evalReturn (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .place (.var x) => do
      let some b := env.lookup x | stuck s!"unknown variable {x}"
      pure (.value (← if b.owned then take b.ref else readRef b.ref))
    | e => do pure (.value (← evalExpr prog n env e))

/-- Runs the statements of a block in order. -/
def execBlock (prog : Program) (fuel : Nat) (refs : Bool) (env : Env) (b : List Stmt) :
    EvalM Env :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match b with
    | [] => pure env
    | s :: rest => do execBlock prog n refs (← execStmt prog n refs env s) rest
end

end MojoGrimoire.Interp
