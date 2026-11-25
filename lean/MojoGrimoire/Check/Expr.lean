import MojoGrimoire.Check.Logic
import MojoGrimoire.Check.Elems
import MojoGrimoire.Check.Range

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
the rules of literals, of `List[u](…)` and of its `range` argument; the
elements of some literals are checked as `MojoGrimoire.Check.Elems` says,
and the arguments of `range` as `MojoGrimoire.Check.Range` says. An
operator or a call that its operands' types reject, a method that a type
lacks, no overload that fits or a comparison that does not fit, is
reported before they are read, as
`MojoGrimoire.Check.Methods` and `MojoGrimoire.Check.Compare` say.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

mutual
/-- The type of the expression `e`. A string literal has no type here: it may
only be printed, which `checkPrint` checks. A call that returns a reference
gives the value it points to, which is copied implicitly, unless `asRef`
holds: then the reference itself is bound, by `ref`, and a place is read. -/
def checkExprAs (prog : Program) (asRef : Bool) : Expr → CheckM Ty
  | .int _ => pure .int
  | .bool _ => pure .bool
  | .str _ => throw CheckError.stringOutsidePrint
  | .place p => do checkIndices prog p; usePlace prog asRef p
  | .transfer p => do requireOwnOrigin prog p; checkIndices prog p; transferPlace prog p
  | .copy p => do
    rejectNoneCopy prog p (typePlace prog p)
    checkIndices prog p
    let t ← readPlace prog p
    if copyingOf prog t == .none then throw (CheckError.notCopyable t)
    pure t
  | .call f args => do
    let f ← mainOperator prog f args (typeArgs prog args)
    if let .place p :: rest := args then
      typeFirst prog f (typePlace prog p) (rest.attach.map fun ⟨a, _⟩ => (a, typeArg prog a))
    requireInPlace f args
    rejectCalledVar prog f (typeArgs prog args)
    match callSig prog f with
    | .ok sig =>
      let params ← testParams f sig.params
      let fit := if (findStruct prog f).isSome then Fit.init (.struct f) else .call
      let locs ← locationArgs prog params args
      let ks ← callOrder (ownArgs prog args) (arityMisfit fit f params.length args.length) locs
        (checkArgs prog fit f params args params.length args.length)
      recheckArgs prog args ks
      for q in ← changedArgs prog params args do changePlace prog q
      instCall prog f
      refResult prog asRef sig args
    | .error err =>
      match f, args, err with
      | "len", [e], .unknownFunction _ => lenCall prog args (typeArgs prog args) (match e with
        | .place p => do checkIndices prog p; readPlace prog p
        | e => do checkExprAs prog (← locOf prog e).isSome e)
      | "len", _, .unknownFunction _ => lenCall prog args (typeArgs prog args) (pure .unknown)
      | _, _, .missingMethod .. => rejectAfter (typeArgs prog args) err
      | _, _, _ => throw err
  | .method p m args => do
    checkIndices prog p
    let t ← placeTy prog p
    let sig ← lift (methodSig prog t m args.length)
    let r ← methodCall prog asRef p t m args sig (ownArgs prog args) fun fit =>
      checkArgs prog fit m sig.params args sig.params.length args.length
    if let .struct s := t then instCall prog (methodCallee s m)
    pure r
  | .unary op a => do
    rejectMisfit (unaryMisfit prog op (← operandTy prog a)) (do let _ ← typeArg prog a)
    lift (methodUnaryTy prog op (← notOperand prog a (checkExprAs prog false a)))
  | .binary op a b => do
    if (← get).phase == .type then
      if ← typedSimdLeft prog op a b then
        let _ ← typeArg prog a
        let _ ← checkExprAs prog true b
        return .bool
    rejectMisfit (← operandMisfit prog op a b (mainFormTy prog))
      (do let _ ← typeArg prog a; let _ ← typeArg prog b)
    let right ← rightParamOf prog op a b
    let s ← get
    let ta ← mainRead prog a (checkExprAs prog (← byRef prog op a b) a)
    let sa ← get
    let ka ← mark
    let tb ← match right ta with
      | some (fit, prm) => do let _ ← checkArg prog fit (binaryMethod op) prm b; pure prm.ty
      | none => mainRead prog b (checkExprAs prog (← byRef prog op b a true) b)
    checkedBinaryTy prog op a b ta tb ka (← mark) s sa
  | .list .unknown [] => throw (CheckError.invalidType .unknown)
  | .list .unknown (e :: es) => do
    let u ← checkExprAs prog false e
    let t := Ty.array u (es.length + 1)
    unless declarableTy prog u do throw (CheckError.invalidType t)
    let k ← mark
    recheckLocs prog ((← firstElemLocs prog e, k) ::
      (← checkArgs prog .call "Array" (es.map fun _ => ⟨.owned, "value", u⟩) es
        es.length es.length))
    pure t
  | .list .int [e] => do expect .int (← checkExprAs prog false e); pure .int
  | .list .int es => do
    rejectIntElems prog .call es (fun p _ => typePlace prog p) (fun a _ => checkExprAs prog false a)
    pure .int
  | .list t es => do
    let u ← literalElem prog (.init t) t es.length
    recheckLocs prog (← checkArgs prog (.init t) (typeName t)
      (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length)
    pure t
  | .listInit u [e] => do
    rejectHidden u
    let t ← match e with
      | .place p => do
        checkIndices prog p
        iterableFits prog u (← placeTy prog p)
        readPlace prog p
      | .str _ => throw (CheckError.noMatchingInit (.list u))
      | e => do
        let t ← match e with
          | .list .unknown es => do
            iterableLiteralTy prog u (← checkIterableElems prog u
              (fun a _ => checkExprAs prog false a) es (Nat.le_refl _))
          | .call f args =>
            if builtinRange prog f && (← findVar f).isNone then
              rangeList prog u args.length
                (typeRangeArgs (fun a _ => typeArg prog a) true args (Nat.le_refl _))
                (readRangeArgs prog (fun p _ => checkIndices prog p)
                  (fun a _ => checkExprAs prog false a) args (Nat.le_refl _))
            else do checkExprAs prog (← locOf prog (.call f args)).isSome (.call f args)
          | e => do checkExprAs prog (← locOf prog e).isSome e
        iterableFits prog u t
        pure t
    for q in ← changedArgs prog [⟨.ref, "iterable", t⟩] [e] do changePlace prog q
    pure (.list u)
  | .listInit u args => do
    rejectHidden u
    checkOperands prog args
    throw (CheckError.noMatchingInit (.list u))
  | .withDrops e _ _ => checkExprAs prog asRef e
  termination_by e => (sizeOf e, 0)

/-- The type of the argument `e` of `range`, or of an element of one, as
the compiler types it before it finds the form of `range` that fits. One
that holds a string or a call of the standard library's `range`
(`holdsStrOrRange`) fits none: it
is typed only in its other parts, and has no type here, `unknown`. So has a
literal in it. A place is typed by `typePlace`, in the phase the caller
types in (`inTypePhase`). A call whose check gives the implicit copy of the
value it returns a reference to, which the compiler reports after the
misfit, has the type of its result (`callResultTy`). -/
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
      typePlace prog p
      placeTy prog p
    | .list .unknown es | .list .int es@([]) | .list .int es@(_ :: _ :: _) => do typeArgs prog es; pure .unknown
    | e => try checkExprAs prog false e catch err => do
        let t ← callResultTy prog e
        if (e matches .call .. | .method ..) && err == .implicitCopy t then pure t else throw err
  termination_by (sizeOf e, 1)

/-- Types each of the expressions `es` (`typeArg`). -/
def typeArgs (prog : Program) : List Expr → CheckM Unit
  | [] => pure ()
  | e :: es => do let _ ← typeArg prog e; typeArgs prog es
  termination_by es => (sizeOf es, 2)

/-- Types the own expressions of the arguments `es` of a call, as the
compiler does before it matches them with the parameters (#89): a literal
by its elements, since converting it to its parameter's type is part of
the match, and any other argument by `typeArg`. -/
def ownArgs (prog : Program) : List Expr → CheckM Unit
  | [] => pure ()
  | .list _ es :: rest => do ownArgs prog es; ownArgs prog rest
  | e :: rest => do let _ ← typeArg prog e; ownArgs prog rest
  termination_by es => (sizeOf es, 2)

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

/-- Checks the index expressions of the place `p` (`indicesOf`). The
compiler types a place from its variable outward, the variable, then each
field and each subscript in turn, and each index once the place it
indexes is typed (#142, #227, #96 part 10): so when the check fails with
an error of the type phase, `p` is typed in that order first
(`typePlace`), and an unknown variable or field, or a type that cannot
be indexed, comes before an index's error. -/
def checkIndices (prog : Program) (p : Place) : CheckM Unit :=
  tryCatch (indicesOf prog p) fun err =>
    if err.phase == .type then rejectAfter (typePlace prog p) err else throw err
  termination_by (sizeOf p, 3)

/-- Checks the index expressions of the place `p`: each is an `Int`, and
one that Mojo computes when it compiles the program may not be negative,
nor, into an array or an `Int`, beyond its last element. Mojo locates `q` in `q[i]`
before it evaluates `i`, then subscripts it (`subscript`). Each `q^` in `p`
needs `q` whole, and a value that `q^` could transfer. -/
def indicesOf (prog : Program) : Place → CheckM Unit
  | .var _ => pure ()
  | .field p _ => indicesOf prog p
  | .index p i => do
    indicesOf prog p
    let k ← mark
    checkIndex prog (← operandTy prog (.place p)) i
    subscript prog p k
    if let some k := constInt i then
      let n := fixedLength (← placeTy prog p)
      if k < 0 then
        let err := CheckError.negativeIndex (.index p i)
        if n.isSome then instThrow err else instRecord (.fail err)
      if let some n := n then
        if n ≤ k then instThrow (CheckError.constantIndexOutOfBounds (.index p i))
  | .transferred p => do
    requireOwnOrigin prog p
    indicesOf prog p
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
each indexed place before its index, each index as
an `Int`, and each `q^` in it, but of an `Int` or a `Bool`, which is the
place `q`, as one that could transfer `q`, initialized or not. An index's
error of a later phase is not found in the type phase, so the transfer is
rejected first. -/
def typePlace (prog : Program) : Place → CheckM Unit
  | .var x => do let _ ← lookup x
  | .field p f => do typePlace prog p; let _ ← placeTy prog (.field p f)
  | .index p i => do
    typePlace prog p
    let t ← placeTy prog p
    let _ ← lift (indexedOf t)
    checkIndex prog (some t) i
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
    rejectIntElemArg prog prm.conv p (checkIndices prog p)
    checkIndices prog p
    passPlace prog fit callee prm.conv prm.ty p
    pure ([p], ← mark)
  | .list t es => do
    passValue fit callee prm.conv
    let t' ← if t == .int && es.length != 1 then do
        rejectIntElems prog fit es (fun p _ => typePlace prog p) (fun a _ => checkExprAs prog false a)
        pure prm.ty
      else if !(t matches .list _ | .array ..) || fit matches .init _ then
        checkExprAs prog false (.list t es)
      else do
        let u ← literalElem prog .call t es.length
        recheckLocs prog (← checkArgs prog .call (typeName t)
          (es.map fun _ => ⟨.owned, "value", u⟩) es es.length es.length)
        pure t
    expectArg fit prm.ty t'
    let k ← mark
    pure (← nestedLocs prog (.list t es), k)
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
        throw (notPlaceError prog fit callee e)
      misfitFirst e fit prm.ty (checkExprAs prog · e)
      let k ← mark
      pure (← lateLocs prog e, k)
  termination_by e => (sizeOf e, 3)

end

end MojoGrimoire.Check
