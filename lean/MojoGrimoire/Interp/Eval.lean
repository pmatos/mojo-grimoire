import MojoGrimoire.Interp.Machine
import MojoGrimoire.Check.Env

/-!
The big-step evaluation of elaborated programs.

Evaluation goes left to right, as in Mojo. The operands of an operation, the
arguments of a call, the elements of a list literal or the values printed,
are evaluated in order, but an operand that is a place passed by value, or
a call that returns a reference, is only located then: as in Mojo, it is
read once every operand has been evaluated, so a call among the later
operands may change it first. The operand of a unary operator, and those
of `and` and `or`, are read at once. An `Int`
or a `Bool` passed to a `read` parameter is passed by value: Mojo copies
it. Every function of the evaluator takes fuel, which each step spends; a
run that spends it all stops with `outOfFuel`, so every run ends, even of a
program that loops forever.

A value is destroyed where elaboration put a `drop` or a `withDrops`, when
it is replaced by an assignment, when a temporary passed to a borrowing
parameter is no longer needed after its call, when a call's result is not
used, when `len` has read the length of a list that is neither a place
nor a reference that a call returns, and when a function returns, for
every value it still owns. A method whose `self` is `var`, called on
`p^`, takes the value out of `p`. Destroying a
struct runs its `__deinit__`, whose elaborated body destroys its fields; a
struct without one has its fields destroyed in order, and a list its
elements. A value that `print` writes is not destroyed after it: it holds
only `Int`s and `Bool`s, so destroying it would do nothing.
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core MojoGrimoire.Check

/-- An argument as a call receives it: a place, passed by reference, or a
value, passed by moving or copying it. `temp` is a value passed to a
borrowing parameter, which the caller destroys after the call. -/
inductive Arg where
  | place (r : Ref)
  | value (v : Value)
  | temp (v : Value)

/-- An operand as evaluation first finds it: a place passed by value, or
the reference that a call returns, located but not yet read, or the value
of any other expression. -/
inductive Operand where
  | loc (r : Ref)
  | val (v : Value)

/-- The value of an operand, once every operand has been evaluated. -/
def Operand.load : Operand → EvalM Value
  | .loc r => readRef r
  | .val v => pure v

/-- An argument before the operands passed by value are read: `load o` is
read into a value when the call is made. -/
inductive Pending where
  | arg (a : Arg)
  | load (o : Operand)

/-- The arguments of a call, once every argument has been evaluated: each
pending operand is read. -/
def Pending.loadAll (ps : List Pending) : EvalM (List Arg) :=
  ps.mapM fun
    | .arg a => pure a
    | .load o => do pure (.value (← o.load))

/-- The variables a function starts with: its parameters bound to the
arguments, each owned when it is passed `var`. The temporaries are given
locations of their own. -/
def bindParams : List Param → List Arg → EvalM Env
  | prm :: prms, a :: args => do
    let rest ← bindParams prms args
    let b ← match a with
      | .place r => pure ⟨r, false⟩
      | .value v => do pure ⟨← alloc v, prm.conv == .owned⟩
      | .temp v => do pure ⟨← alloc v, false⟩
    pure ((prm.name, b) :: rest)
  | _, _ => pure []

/-- The value of an `Int` or `Bool` written by `print`, or of a literal. -/
def asInt : Value → EvalM Int
  | .int n => pure n
  | _ => stuck "expected an Int"

/-- The truth value of a condition. -/
def asBool : Value → EvalM Bool
  | .bool b => pure b
  | _ => stuck "expected a Bool"

/-- The binding of the variable `x`. -/
def lookupVar (env : Env) (x : Name) : EvalM Ref := do
  let some b := env.lookup x | stuck s!"unknown variable {x}"
  pure b.ref

mutual
/-- Destroys the value `v`. -/
def destroy (prog : Program) (fuel : Nat) (v : Value) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match v with
    | .struct s fs => do
      let some sd := findStruct prog s | stuck s!"unknown struct {s}"
      match sd.deinit with
      | some body => do
        let r ← alloc v
        let _ ← runBody prog n false [("self", ⟨r, false⟩)] body
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
    if b.owned then
      let v ← readRef b.ref
      writeRef b.ref .uninit
      destroy prog n v

/-- The reference that the place `p` names. An index is checked against the
length of the list. -/
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
      let .list es ← readRef r | stuck "index into a value that is not a list"
      let j ← position es.length k
      pure { r with path := r.path ++ [.elem j] }
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
    | .transfer p => do
      let r ← placeRef prog n env p
      let v ← readRef r
      writeRef r .uninit
      pure v
    | .unary op a => do unary op (← evalExpr prog n env a)
    | .binary .and a b => do
      if ← asBool (← evalExpr prog n env a) then evalExpr prog n env b else pure (.bool false)
    | .binary .or a b => do
      if ← asBool (← evalExpr prog n env a) then pure (.bool true) else evalExpr prog n env b
    | .binary op a b => do
      let x ← evalOperand prog n env a
      let y ← evalOperand prog n env b
      binary op (← x.load) (← y.load)
    | .list _ es => do
      let os ← es.mapM (evalOperand prog n env)
      pure (.list (← os.mapM Operand.load))
    | e => do
      match ← evalResult prog n env e with
      | .value v => pure v
      | .ref r => readRef r

/-- What the expression `e` gives: for a call, what it returns, which is a
reference for a call that returns one; for any other expression, its
value. -/
def evalResult (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .call .. | .method .. => evalCall prog n env e []
    | .withDrops e pre post => do
      let r ← match e with
        | .call .. | .method .. => evalCall prog n env e pre
        | e => do
          let v ← evalExpr prog n env e
          dropAll prog n env pre
          pure (.value v)
      dropAll prog n env post
      pure r
    | e => do pure (.value (← evalExpr prog n env e))

/-- Takes the value out of the place `p` and destroys it. -/
def dropPlace (prog : Program) (fuel : Nat) (env : Env) (p : Place) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => do
    let r ← placeRef prog n env p
    let v ← readRef r
    writeRef r .uninit
    destroy prog n v

/-- Destroys the values in the places `ps`, in order. -/
def dropAll (prog : Program) (fuel : Nat) (env : Env) (ps : List Place) : EvalM Unit :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => ps.forM (dropPlace prog n env)

/-- The operand `e`: a place, or a call that returns a reference, is
located, and any other expression evaluated. -/
def evalOperand (prog : Program) (fuel : Nat) (env : Env) (e : Expr) : EvalM Operand :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .place p => do pure (.loc (← placeRef prog n env p))
    | e => do
      match ← evalResult prog n env e with
      | .ref r => pure (.loc r)
      | .value v => pure (.val v)

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
          | .owned, a => do pure (.load (← evalOperand prog n env a))
          | .read, .place p =>
            if prm.ty.byValue then do pure (.load (← evalOperand prog n env (.place p)))
            else do pure (.arg (.place (← placeRef prog n env p)))
          | _, .place p => do pure (.arg (.place (← placeRef prog n env p)))
          | _, a => do
            match ← evalResult prog n env a with
            | .ref r =>
              if passedByValue prm then pure (.load (.loc r))
              else pure (.arg (.place r))
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

/-- Evaluates a call, a construction or a method call. The values in the
places `pre` are destroyed once the arguments are read, before the call is
made. -/
def evalCall (prog : Program) (fuel : Nat) (env : Env) (e : Expr) (pre : List Place) :
    EvalM Result :=
  match fuel with
  | 0 => fail .outOfFuel
  | n + 1 => match e with
    | .call f args =>
      match findStruct prog f, findFun prog f, f, args with
      | some sd, _, _, _ => do
        match sd.init with
        | some fd => do
          let self ← alloc (emptyStruct sd)
          let rest ← Pending.loadAll (← evalArgs prog n env fd.params.tail args)
          dropAll prog n env pre
          let _ ← callFun prog n fd (.place self :: rest)
          pure (.value (← readRef self))
        | none => do
          let os ← args.mapM (evalOperand prog n env)
          let vs ← os.mapM Operand.load
          dropAll prog n env pre
          pure (.value (.struct sd.name (sd.fields.zip vs |>.map fun ((x, _), v) => (x, v))))
      | none, some fd, _, _ => do
        let args ← Pending.loadAll (← evalArgs prog n env fd.params args)
        dropAll prog n env pre
        callFun prog n fd args
      | none, none, "len", [a] => do
        let .list es ← evalListArg prog n env a | stuck "len of a value that is not a list"
        dropAll prog n env pre
        pure (.value (.int es.length))
      | _, _, _, _ => stuck s!"unknown function {f}"
    | .method p m args => do
      let r ← placeRef prog n env p
      match ← readRef r with
      | .list _ => match m, args with
        | "append", [a] => do
          let v ← evalExpr prog n env a
          dropAll prog n env pre
          let .list es ← readRef r | stuck "append to a value that is not a list"
          writeRef r (.list (es ++ [v]))
          pure (.value .none)
        | "pop", [] => do
          dropAll prog n env pre
          let .list es ← readRef r | stuck "pop from a value that is not a list"
          let some v := es.getLast? | fail .indexOutOfBounds
          writeRef r (.list es.dropLast)
          pure (.value v)
        | "pop", [a] => do
          let k ← asInt (← evalExpr prog n env a)
          dropAll prog n env pre
          let .list es ← readRef r | stuck "pop from a value that is not a list"
          let j ← position es.length k
          let some v := es[j]? | fail .indexOutOfBounds
          writeRef r (.list (es.eraseIdx j))
          pure (.value v)
        | _, _ => stuck s!"unknown list method {m}"
      | .struct s _ => do
        let some fd := (findStruct prog s).bind (findMethod · m) | stuck s!"unknown method {m}"
        let some self := fd.params.head? | stuck "a method with no self"
        let rest ← evalArgs prog n env fd.params.tail args
        let recv ← if self.conv == .owned then do pure (Arg.value (← readRef r))
          else pure (Arg.place r)
        let args ← Pending.loadAll rest
        if (consumedReceiver self.conv p).isSome then writeRef r .uninit
        dropAll prog n env pre
        callFun prog n fd (recv :: args)
      | _ => stuck "a method call on a value that is not a struct"
    | _ => stuck "not a call"

/-- The list that `len` reads: a place, or the reference that a call
returns, read where it is, or any other expression, whose value is then
destroyed. -/
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
    | .decl x _ init => do
      let v ← match init with
        | some e => evalExpr prog n env e
        | none => pure .uninit
      pure ((x, ⟨← alloc v, true⟩) :: env)
    | .refDecl x e => do pure ((x, ⟨← evalRef prog n env e, false⟩) :: env)
    | .assign p e => do
      let v ← evalExpr prog n env e
      let r ← placeRef prog n env p
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
      let parts ← os.mapM fun
        | .inl t => pure t
        | .inr o => do pure (← o.load).show
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
      dropPlace prog n env p
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
      let v ← readRef b.ref
      if b.owned then writeRef b.ref .uninit
      pure (.value v)
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
