import MojoGrimoire.Check.Methods

/-!
The checking of expressions and of the arguments of calls.

An expression is checked from left to right, as Mojo evaluates it, and the
state follows: a transfer `p^` leaves `p` uninitialized for what comes
after it (`MojoGrimoire.Check.Transfer`). Before a field or a method, `p^`
borrows `p`, which must be whole and could be transferred, and cannot be
changed through it; a method whose `self` is `var` takes it, once the
arguments are read. A place passed as an argument is passed by its
parameter's convention (`passPlace`), and so is a call that returns a
reference and is a located operand (`MojoGrimoire.Check.locOf`), passed to
a `read`, `mut` or `ref` parameter or to `len`: it is not copied, and it
stands for its origins. The operands read late, and the places that a call
changes, are checked as `MojoGrimoire.Check.Change` says. An argument that
does not fit is reported as `MojoGrimoire.Check.Fit` says, which also gives
the rules of literals, of `List[u](…)` and of its `range` argument. An
operator or a call that its operands' types reject, a method that a type
lacks or no overload that fits, is reported before they are read, as
`MojoGrimoire.Check.Methods` says.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

mutual
/-- The type of the expression `e`. A string literal has no type here: it may
only be printed, which `checkPrint` checks. A call that returns a reference
gives the value it points to, which is copied implicitly, unless `asRef`
holds: then the reference itself is bound, by `ref`. -/
def checkExprAs (prog : Program) (asRef : Bool) : Expr → CheckM Ty
  | .int _ => pure .int
  | .bool _ => pure .bool
  | .str _ => throw CheckError.stringOutsidePrint
  | .place p => do checkIndices prog p; copyPlace prog p
  | .transfer p => do requireOwnOrigin prog p; checkIndices prog p; transferPlace prog p
  | .copy p => do
    rejectNoneCopy prog p (typePlace prog p)
    checkIndices prog p
    let t ← readPlace prog p
    if copyingOf prog t == .none then throw (CheckError.notCopyable t)
    pure t
  | .call f args => do
    if let .place p :: _ := args then
      if inPlaceCallee f then
        let s ← get
        typePlace prog p
        set s
    requireInPlace f args
    rejectCalledVar prog f (typeArgs prog args)
    match callSig prog f with
    | .ok sig =>
      let params := sig.params
      let fit := if (findStruct prog f).isSome then Fit.init (.struct f) else .call
      checkExclusive (← locationArgs prog params args)
      recheckLocs prog (← checkArgs prog fit f params args params.length args.length)
      for q in ← changedArgs prog params args do changePlace prog q
      refResult prog asRef sig
    | .error err =>
      match f, args, err with
      | "len", [e], .unknownFunction _ => do
        let _ ← lift (elemOf (← match e with
          | .place p => do checkIndices prog p; readPlace prog p
          | e => do checkExprAs prog (← locOf prog e).isSome e))
        pure .int
      | "len", _, .unknownFunction _ => throw (CheckError.arityMismatch f 1 args.length)
      | _, _, .missingMethod .. => rejectAfter (typeArgs prog args) err
      | _, _, _ => throw err
  | .method p m args => do
    checkIndices prog p
    let t ← placeTy prog p
    let sig ← lift (methodSig prog t m args.length)
    methodCall prog asRef p t m args sig (typeArgs prog args) fun fit =>
      checkArgs prog fit m sig.params args sig.params.length args.length
  | .unary op a => do
    rejectMisfit (unaryMisfit prog op (← operandTy prog a)) (do let _ ← typeArg prog a)
    lift (methodUnaryTy prog op (← checkExprAs prog false a))
  | .binary op a b => do
    rejectMisfit (binaryMisfit prog op (← operandTy prog a) (← operandTy prog b))
      (do let _ ← typeArg prog a; let _ ← typeArg prog b)
    let ta ← checkExprAs prog false a
    let ka ← mark
    let tb ← if intLiteral a && op != .and && op != .or then do
        let m := binaryMethod op
        let _ ← checkArg prog (.overload m) m ⟨.read, "rhs", .int⟩ b
        pure .int
      else checkExprAs prog false b
    let kb ← mark
    unless op == .and || op == .or do recheckPlaces prog [a, b] [ka, kb]
    lift (methodBinaryTy prog op ta tb)
  | .list .unknown [] => throw (CheckError.invalidType .unknown)
  | .list .unknown (e :: es) => do
    let u ← checkExprAs prog false e
    let t := Ty.array u (es.length + 1)
    unless declarableTy prog u do throw (CheckError.invalidType t)
    let k ← mark
    recheckLocs prog ((if let .place p := e then [p] else [], k) ::
      (← checkArgs prog .call "Array" (es.map fun _ => ⟨.owned, "value", u⟩) es
        es.length es.length))
    pure t
  | .list .int [e] => do expect .int (← checkExprAs prog false e); pure .int
  | .list .int es => rejectIntLiteral prog .call (intMisfit prog es) (readIntElems prog es)
  | .list t es => do
    let u ← literalElem prog (.init t) t es.length
    recheckLocs prog (← checkArgs prog (.init t) (typeName t)
      (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length)
    pure t
  | .listInit u [e] => do
    let t ← match e with
      | .place p => do
        checkIndices prog p
        iterableFits prog u (← placeTy prog p)
        readPlace prog p
      | .str _ => throw (CheckError.noMatchingInit (.list u))
      | e => do
        let t ← match e with
          | .list .unknown es => do iterableLiteralTy prog u (← checkIterableElems prog u es)
          | .call f args =>
            if builtinRange prog f && (← findVar f).isNone then
              rangeList prog u args.length (typeRangeArgs prog true args) (readRangeArgs prog args)
            else do checkExprAs prog (← locOf prog (.call f args)).isSome (.call f args)
          | e => do checkExprAs prog (← locOf prog e).isSome e
        iterableFits prog u t
        pure t
    for q in ← changedArgs prog [⟨.ref, "iterable", t⟩] [e] do changePlace prog q
    pure (.list u)
  | .listInit u args => do
    checkOperands prog args
    throw (CheckError.noMatchingInit (.list u))
  | .withDrops e _ _ => checkExprAs prog asRef e
  termination_by e => (sizeOf e, 0)

/-- Checks the elements `es` of a literal with no type expected that is
the argument of `List[u](…)`, in order, each as passed to a `var`
parameter, and gives the type of each, with the places it is read from
once every element is evaluated and how many changes were recorded once
it was checked; `iterableLiteralTy` gives the literal's type. -/
def checkIterableElems (prog : Program) (u : Ty) : List Expr → CheckM (List (Ty × List Place × Nat))
  | [] => pure []
  | e :: es => do
    let t ← match e with
      | .list .unknown es' => do iterableLiteralTy prog u (← checkIterableElems prog u es')
      | e => checkExprAs prog false e
    let k ← mark
    pure ((t, ← lateLocs prog e, k) :: (← checkIterableElems prog u es))
  termination_by es => (sizeOf es, 2)

/-- Types the arguments of the standard library's `range` in the argument
of `List[u](…)`, each in `State.typing`, and gives whether one fits no form
of `range`, and whether one is an open literal of `Int`s, which the
compiler takes for an `Int` and rejects only when it instantiates the call
(#121). An error of typing is thrown, in any argument; a literal is typed
by `typeLiteral`, and any other argument by `typeArg`. A literal whose first
element, at any depth, is an empty literal fits no form as the `first`
argument, and is such a literal of `Int`s after it. -/
def typeRangeArgs (prog : Program) (first : Bool) : List Expr → CheckM (Bool × Bool)
  | [] => pure (false, false)
  | a :: as => do
    modify State.typing
    let (misfit, literal) ← match a with
      | .list .unknown es | .list .int es@([]) | .list .int es@(_ :: _ :: _) => do
        let (ints, empty) ← typeLiteral prog es
        pure (if ints && !(first && empty) then (false, true) else (true, false))
      | a => do pure ((← typeArg prog a) != .int, false)
    let (misfit', literal') ← typeRangeArgs prog false as
    pure (misfit || misfit', literal || literal')
  termination_by as => (sizeOf as, 2)

/-- Types the elements `es` of an open literal that is an argument of
`range`, and gives whether every element that is not a literal, at any
depth, is an `Int`, and whether its first element, at any depth, is an
empty literal: such a literal fits no form of `range` (#121). -/
def typeLiteral (prog : Program) : List Expr → CheckM (Bool × Bool)
  | [] => pure (true, true)
  | e :: es => do
    let (ints, empty) ← match e with
      | .list .unknown es' | .list .int es'@([]) | .list .int es'@(_ :: _ :: _) => typeLiteral prog es'
      | e => do pure ((← typeArg prog e) == .int, false)
    let (ints', _) ← typeLiteral prog es
    pure (ints && ints', empty)
  termination_by es => (sizeOf es, 2)

/-- The type of the argument `e` of `range`, or of an element of one, as
the compiler types it before it finds the form of `range` that fits. One
that holds a string or a call of the standard library's `range`
(`holdsStrOrRange`) fits none: it
is typed only in its other parts, and has no type here, `unknown`. So has a
literal in it. A place is typed by `typePlace`. One whose check gives an
error that the compiler reports after its types, or after the misfit, a
call's implicit copy of the value it returns a reference to, has its
`lateElemTy`. -/
def typeArg (prog : Program) (e : Expr) : CheckM Ty :=
  if holdsStrOrRange prog e then do
    match e with
    | .call _ es | .list _ es => typeArgs prog es
    | .unary _ a => let _ ← typeArg prog a
    | .binary _ a b => do let _ ← typeArg prog a; let _ ← typeArg prog b
    | _ => pure ()
    pure .unknown
  else
    match e with
    | .place p => do
      try typePlace prog p catch err => unless err.late || err == .noMatchingInit .int do throw err
      placeTy prog p
    | .list .unknown es | .list .int es@([]) | .list .int es@(_ :: _ :: _) => do typeArgs prog es; pure .unknown
    | e => try checkExprAs prog false e catch err => do
        let t ← lateElemTy prog e
        if err.late || err == .noMatchingInit .int ||
          (e matches .call .. | .method .. && err == .implicitCopy t) then pure t
        else throw err
  termination_by (sizeOf e, 1)

/-- Types each of the expressions `es` (`typeArg`). -/
def typeArgs (prog : Program) : List Expr → CheckM Unit
  | [] => pure ()
  | e :: es => do let _ ← typeArg prog e; typeArgs prog es
  termination_by es => (sizeOf es, 2)

/-- Reads the arguments `args` of `range`, typed by `typeRangeArgs`, in
order, as `Int`s passed to `read` parameters, and an open literal's
elements in turn. An error of a later pass than typing is recorded
(`lateErrors`), and the arguments and elements after it still read. -/
def readRangeArgs (prog : Program) : List Expr → CheckM RangeArgs
  | [] => pure {}
  | a :: as => do
    let r ← match a with
      | .list .unknown es | .list .int es@([]) | .list .int es@(_ :: _ :: _) => readRangeArgs prog es
      | .place p => lateErrors (do
        checkIndices prog p
        let _ ← readPlace prog p
        pure { locs := [([p], ← mark)] })
      | a => lateErrors (do
        let _ ← checkExprAs prog false a
        pure { locs := [(← lateLocs prog a, ← mark)] })
    pure (r.append (← readRangeArgs prog as))
  termination_by as => (sizeOf as, 2)

/-- Checks each of the arguments `args` of `List[u](…)` on its own: a place
is located, and any other expression checked, before the call is rejected. -/
def checkOperands (prog : Program) : List Expr → CheckM Unit
  | [] => pure ()
  | .place p :: args => do
    checkIndices prog p
    let _ ← placeTy prog p
    checkOperands prog args
  | e :: args => do
    let _ ← checkExprAs prog false e
    checkOperands prog args
  termination_by es => (sizeOf es, 2)

/-- The type of the first of the elements `es` of a literal where an `Int`
is expected that is no `Int`, nor such a literal of `Int`s. Each is typed
in `State.typing`, a place by `typePlace`; one whose check gives an error
that the compiler reports later has its `lateElemTy`. -/
def intMisfit (prog : Program) : List Expr → CheckM (Option Ty)
  | [] => pure none
  | e :: es => do
    modify State.typing
    let u ← match e with
      | .place p => do
        try typePlace prog p catch err =>
          unless err.late || err == .noMatchingInit .int do throw err
        placeTy prog p
      | .list .int es' => do pure ((← intMisfit prog es').getD .int)
      | e => try checkExprAs prog false e catch err =>
          if err.late || err == .noMatchingInit .int then lateElemTy prog e else throw err
    if u == .int then intMisfit prog es else pure (some u)
  termination_by es => (sizeOf es, 2)

/-- Reads the elements `es` of such a literal of `Int`s, as `Int`s passed
`var`, a nested one's elements in turn, and gives what each reads late. -/
def readIntElems (prog : Program) : List Expr → CheckM (List (List Place × Nat))
  | [] => pure []
  | e :: es => do
    let ks ← match e with
      | .list .int [] => pure []
      | .list .int es'@(_ :: _ :: _) => readIntElems prog es'
      | e => do expect .int (← checkExprAs prog false e); let k ← mark; pure [(← lateLocs prog e, k)]
    pure (ks ++ (← readIntElems prog es))
  termination_by es => (sizeOf es, 2)

/-- Checks the index expressions of the place `p`: each is an `Int`, and
one that Mojo computes when it compiles the program may not be negative,
nor, into an array, beyond its last element. Mojo locates `q` in `q[i]`
before it evaluates `i`, so `i` may not invalidate `q`. Each `q^` in `p`
needs `q` whole, and a value that `q^` could transfer. -/
def checkIndices (prog : Program) : Place → CheckM Unit
  | .var _ => pure ()
  | .field p _ => checkIndices prog p
  | .index p i => do
    checkIndices prog p
    let k ← mark
    checkIndex prog (← operandTy prog (.place p)) i
    requireUnchanged prog p k
    if let some k := constInt i then
      if k < 0 then throw (CheckError.negativeIndex (.index p i))
      if let .array _ n := (← placeTy prog p) then
        if n ≤ k then throw (CheckError.constantIndexOutOfBounds (.index p i))
  | .transferred p => do
    requireOwnOrigin prog p
    checkIndices prog p
    let _ ← requireTransferable prog p
  termination_by p => (sizeOf p, 2)

/-- Checks the index `i` of a place of type `base`, an `Int`. An index of a
list or an array is an argument of `__getitem__`, which has several
overloads (`overloaded`). -/
def checkIndex (prog : Program) (base : Option Ty) (i : Expr) : CheckM Unit :=
  let m := "__getitem__"
  if base.any (overloaded · m) then do let _ ← checkArg prog (.overload m) m ⟨.read, "idx", .int⟩ i
  else do expect .int (← checkExprAs prog false i)
  termination_by (sizeOf i, 4)

/-- Rejects `p^` when the value in `p` has no origin of its own
(`noOwnOrigin`), as the compiler does once it has typed `p` (#85, #119):
before it looks at what is initialized or invalidated, at a constant
index, or at the parameter `p^` is passed to. -/
def requireOwnOrigin (prog : Program) (p : Place) : CheckM Unit := do
  typePlace prog p
  if ← noOwnOrigin p then throw (CheckError.transferFromElement p)
  termination_by (sizeOf p, 1)

/-- Types the place `p` as the compiler does, from its variable outward,
each indexed place, but an `Int` (#127), before its index, each index as
an `Int`, and each `q^` in it, but of an `Int` or a `Bool`, which is the
place `q`, as one that could transfer `q`, initialized or not. An index's error that the compiler reports later (`CheckError.late`)
is left out: the transfer is rejected first. -/
def typePlace (prog : Program) : Place → CheckM Unit
  | .var x => do let _ ← lookup x
  | .field p f => do typePlace prog p; let _ ← placeTy prog (.field p f)
  | .index p i => do
    typePlace prog p
    let t ← placeTy prog p
    unless t == .int do let _ ← lift (elemOf t)
    try checkIndex prog (some t) i catch e => unless e.late do throw e
    let _ ← placeTy prog (.index p i)
  | .transferred p => do
    typePlace prog p
    unless (← placeTy prog p).byValue do
      if ← noOwnOrigin p then throw (CheckError.transferFromElement p)
      unless (← lookup (splitPlace p).1).access.canChange do
        throw (CheckError.transferFromBorrowed p)
  termination_by p => (sizeOf p, 0)

/-- Checks the arguments `args` of a call of `callee` against its parameters
`params`, in order, and gives, for each, the places it is read from once
every argument is evaluated, with how many changes were recorded once it
was checked. A call that returns a reference, passed by reference, is
passed as a location, uncopied, when it is a located operand, and for
`mut` it must be mutable; the origin it is reported by is its first. One
with a temporary origin argument is checked as a value. `n` and `m` are
the numbers of parameters and arguments, for the error when they differ.
The call's fit `fit` says how a misfit is reported; a literal passed to a
function or a method is converted to its parameter's type. -/
def checkArgs (prog : Program) (fit : Fit) (callee : Name) :
    List Param → List Expr → Nat → Nat → CheckM (List (List Place × Nat))
  | [], [], _, _ => pure []
  | prm :: prms, e :: args, n, m => do
    let l ← checkArg prog fit callee prm e
    pure (l :: (← checkArgs prog fit callee prms args n m))
  | _, _, n, m => throw (fit.misfit (CheckError.arityMismatch callee n m))
  termination_by _ args _ _ => (sizeOf args, 2)

/-- Checks the argument `e` of a call of `callee` of fit `fit`, passed to
the parameter `prm`, as `checkArgs` says, and gives the places it is read
from once every argument is evaluated, with how many changes were
recorded once it was checked. A string literal fits no overload. -/
def checkArg (prog : Program) (fit : Fit) (callee : Name) (prm : Param) :
    Expr → CheckM (List Place × Nat)
  | .place p => do
    checkIndices prog p
    passPlace prog fit callee prm.conv prm.ty p
    pure ([p], ← mark)
  | .list t es => do
    passValue fit callee prm.conv
    let t' ← if t == .int && es.length != 1 then
        rejectIntLiteral prog fit (intMisfit prog es) (readIntElems prog es)
      else if !(t matches .list _ | .array ..) || fit matches .init _ then
        checkExprAs prog false (.list t es)
      else do
        let u ← literalElem prog .call t es.length
        recheckLocs prog (← checkArgs prog .call (typeName t)
          (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length)
        pure t
    expectArg fit prm.ty t'
    let k ← mark
    let late ← if let [x] := es then if t == .int then lateLocs prog x else pure [] else pure []
    pure (late, k)
  | e => do
    if e matches .str _ && fit matches .overload _ then
      throw (fit.misfit (CheckError.typeMismatch prm.ty .str))
    if prm.conv == .out || prm.conv == .deinit then
      throw (CheckError.invalidConvention callee)
    match ← if passedByValue prm then pure none else locOf prog e with
    | some (os, mq) =>
      expectArg fit prm.ty (← checkExprAs prog true e)
      if prm.conv == .mutable && !mq then
        throw (fit.misfit (CheckError.immutablePlace (os.headD (.var callee))))
      pure (os, ← mark)
    | none =>
      if prm.conv == .mutable then
        if let .transfer p := e then
          requireOwnOrigin prog p
          unless ← placeMutable p do
            throw (CheckError.transferFromBorrowed p)
        throw (fit.misfit (CheckError.notAPlace callee))
      expectArg fit prm.ty (← checkExprAs prog false e)
      let k ← mark
      pure (← lateLocs prog e, k)
  termination_by e => (sizeOf e, 3)

end

/-- The type of the expression `e`, used as a value. -/
def checkExpr (prog : Program) (e : Expr) : CheckM Ty := checkExprAs prog false e

end MojoGrimoire.Check
