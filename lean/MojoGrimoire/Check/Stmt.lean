import MojoGrimoire.Check.Subscript
import MojoGrimoire.Check.Exit

/-!
The checking of statements. `MojoGrimoire.Check.Block` checks the blocks
themselves, and `MojoGrimoire.Check.Exit` says where variables end, how
the branches of an `if` join and what a loop's body must leave.

A block is a scope: the variables it declares end with it. A declaration
may not reuse the name of a variable in scope, so no variable hides
another, though sibling blocks may reuse a name; a variable named `print`
hides it, and printing is then a call of the variable (#176), but not
yet when its struct type declares `__call__` (#191). When inference could not
find a declaration's type, the checker checks its initializer before it
rejects the declaration, so that the initializer's own error is reported,
as the compiler does (#123). A declared type in which a variable hides a
name is `valueAsType`, before any other error of the declaration (#193).

Assigning to a part destroys its old value, so the same holds for the
part as for a variable that ends (`cannotEnd`), and a part moved out may
not be assigned whole once some of its fields were assigned. Assigning
through a reference, or to an element, needs the old value initialized,
with no field moved out.

Returning a variable that the function owns moves it out, as Mojo does; any
other place is copied, implicitly. A literal with no list or array expected
that initializes a declared variable, a place assigned to or a function's
result fits no initializer of its type (#46), nor, where an `Int` is
expected, does one of any length but 1 (#153, #154). A function that returns a reference
returns a location within its own origin, as `withinOrigin` decides.

An assignment changes its place as a whole. Into a subscript of a struct
that declares `__setitem__` but not `__getitem__`, it is `missingMethod`,
before any error of the place but its receiver's (#296). Into the element of an `Int`,
it locates the `Int` before it evaluates the value, as `__setitem__` takes
it as `self`, so the value may not invalidate that location, and reads
the index, an argument of `__setitem__`, once the value is evaluated, so
the value may not invalidate a place the index is read from (#127). As
`p op= e` is read as `p = p op e`, which evaluates the indices of `p`
twice where the compiler evaluates them once (#198), `p = p op e` into the
element of an `Int` is rejected as `notAList`, as before #127, unless each
index of `p` is a constant or a variable. A loop whose body can reach
its end and leaves a part moved out, a part that may hold a value, a
touched part, a piece or an invalidated reference that the state before
the loop lacks is checked once more from the state before it with those
added, since the next iteration starts so; the state after the loop has
them too. The changes recorded for operands start afresh with each
statement.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The type of the expression `e`, used as a value. -/
def checkExpr (prog : Program) (e : Expr) : CheckM Ty := checkExprAs prog false e

/-- Whether `print` can write a value of type `t`: an `Int`, a `Bool`, or a
list or an array of values it can write. -/
def printable : Ty → Bool
  | .int | .bool => true
  | .list t | .array t _ => printable t
  | _ => false

/-- Checks a value printed by `print`: a string literal, or a value that
`print` can write. `print` reads a place by reference, so it copies
nothing, and a call that returns a reference gives the value it points
to, uncopied. -/
def checkPrintArg (prog : Program) : Expr → CheckM Unit
  | .str _ => pure ()
  | e => do
    let t ← match e with
      | .place p => do checkIndices prog p; readPlace prog p
      | e => checkExprAs prog true e
    unless printable t do throw (CheckError.notPrintable t)

/-- Rejects the assignment of the value `e` to the place `p` inside an
element of a list when `e` is a call that builds its result in `p` and is
passed `mut` that list, or a place that holds it: Mojo reports the result
as aliased with the argument. A call, an initializer included, builds its
result in place unless the result is an `Int`, a `Bool`, `None` or a
reference; a
generic result, such as the element that a list method gives, always is.
`List[u](e)` builds its result in place too, and passes `e` by `ref`
(#103). -/
def checkConstructed (prog : Program) (p : Place) (e : Expr) : CheckM Unit := do
  let builds (sig : Signature) := sig.origin.isNone && (sig.generic || !sig.result.byValue)
  let changed ← match e with
    | .call f args => match callSig prog f with
      | .ok sig => if builds sig then changedArgs prog sig.params args else pure []
      | .error _ => pure []
    | .method q m args => match methodSig prog (← placeTy prog q) m args.length with
      | .ok sig => if builds sig then changedArgs prog sig.allParams (.place q :: args) else pure []
      | .error _ => pure []
    | .listInit u [a] => changedArgs prog [⟨.ref, "iterable", .list u⟩] [a]
    | _ => pure []
  let vars := (← get).vars
  for q in changed do
    for m in resolvePlace vars q do
      let ms ← shapeOf prog m
      for t in resolvePlace vars p do
        if invalidates ms (← shapeOf prog t) then throw (CheckError.argumentExclusivity q)

/-- Checks the value `e` that initializes a value of the type `t`, given
`value`, which checks it and gives its type. A literal with no type expected,
where `t` is not a list or an array, fits no initializer of `t`: Mojo calls
`t`'s initializer with the elements, which none takes (#46). A literal of
any length but 1 where an `Int` is expected initializes it, and fits no
initializer (`rejectIntLiteral`, #153, #154). -/
def checkInitValue (prog : Program) (t : Ty) (e : Expr) (value : CheckM Ty) : CheckM Unit := do
  if let some es := wrongIntLiteral e then
    rejectIntElems prog (.init t) es (fun p _ => typePlace prog p) (fun a _ => checkExpr prog a)
  if let .list .unknown es := e then
    unless t matches .list _ | .array .. do
      checkOperands prog es
      throw (CheckError.noMatchingInit t)
  misfitFirst e .call t fun r => if r then checkExprAs prog true e else value

/-- The type of the value of `return e`: a variable that the function owns
is moved out, and any other expression is checked as usual. -/
def checkReturnValue (prog : Program) : Expr → CheckM Ty
  | .place (.var x) => do
    let v ← lookup x
    if v.access == .owned then transferPlace prog (.var x) else copyPlace prog (.var x)
  | e => checkExpr prog e

/-- Checks the statement `s` of the function `sig`, whose name, result type
and origin a `return` is checked against, when it holds no block: an `if`
and a loop are checked by `MojoGrimoire.Check.checkStmt`. -/
def checkSimple (prog : Program) (sig : FunDecl) : Stmt → CheckM Unit
  | .pass => pure ()
  | .decl x t init => do
    rejectHidden t
    if (← get).vars.any (·.name == x) then throw (CheckError.duplicate x)
    unless declarableTy prog t do
      if let (.unknown, some e) := (t, init) then let _ ← checkExpr prog e
      throw (CheckError.invalidType t)
    let us ← match init with
      | some e => do checkInitValue prog t e (checkExpr prog e); pure []
      | none => pure [[]]
    let hs := if us.isEmpty then [[]] else []
    modify fun s => { s with vars := ⟨x, t, .owned, us, [], hs, [], []⟩ :: s.vars }
  | .refDecl x e => do
    if (← get).vars.any (·.name == x) then throw (CheckError.duplicate x)
    let (t, origins, m) ← refTarget prog sig.name e
    modify fun s => { s with vars := ⟨x, t, .alias origins m, [], [], [], [], []⟩ :: s.vars }
  | .assign p e => do
    rejectSetterOnly prog p
    if let some g ← valueSubscript prog p then
      return ← assignGetter prog p g fun t => checkInitValue prog t e (checkExpr prog e)
    let k ← mark
    if let .binary _ (.place q) _ := e then
      if q == p && !plainIndices p then rejectIntElem prog p (checkIndices prog p)
    let t ← if e matches .list .unknown _ || (wrongIntLiteral e).isSome then do
        let u ← placeTy prog p
        checkInitValue prog u e (checkExpr prog e)
        pure u
      else tryCatch (checkExpr prog e) fun err => do
        if err matches .implicitCopy _ && e matches .call .. | .method .. then
          expect (← placeTy prog p) (← tryCatch (checkExprAs prog true e) fun _ => throw err)
        throw err
    checkIndices prog p
    expect (← placeTy prog p) t
    checkConstructed prog p e
    requireMutable p
    if let .index q i := p then
      if (← placeTy prog q) == .int then
        requireUnchanged prog q k
        recheckPlaces prog [i] [k]
    changePlace prog p
    let (x, path) := splitPlace p
    let v ← lookup x
    if splitPlace.indexed p || v.access matches .alias .. then
      let _ ← readPlace prog p
      return
    let ts := (if (above path v.touched).isEmpty then [] else [[]]) ++ atOrBelow path v.touched
    if cannotEnd prog (partTy prog v.ty path) (partsWithin path v.uninit) (atOrBelow path v.moved)
        (partsWithin path v.held) ts (atOrBelow path v.pieces) 0 then
      throw (CheckError.partiallyDestroyed x)
    let uninit := initPart prog v.uninit v.ty path
    let outside (us : List Path) := us.filter (!path.isPrefixOf ·)
    let pieces := union (outside v.pieces) ((above path v.uninit).flatMap (piecesTo · path))
    let whole := v.access == .constructing && !v.moved.contains [] && uninit.isEmpty
    setVar { v with uninit, moved := outside v.moved, held := uninitialize v.held path,
                    touched := union (outside v.touched) (above path v.held),
                    pieces := if whole then pieces.filter (!·.isEmpty) else pieces }
  | .expr e => do
    checkSetter prog e
    let _ ← checkExpr prog e
  | .print args => do
    rejectCalledVar prog "print" (typeArgs prog args)
    let ks ← args.attach.mapM fun ⟨e, _⟩ => do checkPrintArg prog e; mark
    recheckPlaces prog args ks
  | .ret value => do
    match value, sig.origin with
    | none, _ => unless sig.result == .noneType do throw (CheckError.invalidReturn sig.name)
    | some e, none => do
      if sig.result == .noneType then throw (CheckError.invalidReturn sig.name)
      checkInitValue prog sig.result e (checkReturnValue prog e)
    | some e, some os => do
      let (t, origins, _) ← refTarget prog sig.name e sig.result
      expect sig.result t
      unless ← origins.allM (withinOrigin prog os) do
        throw (CheckError.escapingReference sig.name)
    checkExit prog
    modify fun s => { s with live := false }
  | .drop p => do
    let _ ← transferPlace prog p
  | .ifElse .. | .whileLoop .. => pure ()

end MojoGrimoire.Check
