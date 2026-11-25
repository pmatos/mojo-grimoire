import MojoGrimoire.Check.State

/-!
What the checking of statements and blocks needs where variables end,
where a function returns, where two branches join and after a loop's body
(`MojoGrimoire.Check.Stmt`, `MojoGrimoire.Check.Block`).

Where a variable ends, at the end of its block or when the function
returns, the parts it still holds are destroyed. The compiler destroys a
struct whole, so a variable may not end with a field moved out and not
assigned again while it still holds a part, nor partly built on some path,
with a field never assigned while it holds another, as the human ruled
(R, D-0003). A variable that holds nothing may end, unless a field was
moved out of a part held whole (#51). The `self` of `__deinit__` is the
exception: its own fields may stay moved out, since it is being destroyed
field by field. When a function returns, its `mut` parameters and the
`self` of `__init__` must be wholly initialized, since the caller holds
them.

After an `if`, a part of a variable is initialized only when both branches
leave it initialized, and a branch that returns does not count; a
reference is invalidated when either branch invalidates it. A loop body
that can reach its end must leave initialized every part that was
initialized before the loop, and may not leave a field moved out that was
initialized before the loop and not moved out, or its next iteration would
use a moved value: like Mojo, the checker reports that as a use of an
uninitialized value.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- Whether the parts `hs` of a value of type `t` hold all of its part
`q`: one of them is at or above `q`, or `q` is a struct and they hold each
of its fields. A part held whole and then given a field again is recorded
as its fields, which hold it all. -/
def holdsAll (prog : Program) (t : Ty) (hs : List Path) (q : Path) : Bool :=
  go (hs.foldl (fun n h => max n h.length) 0) q
where
  /-- `holdsAll` with fuel `n`, at least the depth of the parts in `hs`. -/
  go : Nat → Path → Bool
    | 0, q => hs.any (·.isPrefixOf q)
    | n + 1, q => hs.any (·.isPrefixOf q) ||
      let fs := fieldNames prog (partTy prog t q)
      !fs.isEmpty && fs.all fun f => go n (q ++ [f])

/-- Whether a value of type `t` may be destroyed partly built, given its
uninitialized parts `us`, its parts that may hold a value `hs` and its
pieces `ps`: a part may be uninitialized while another part of it may
hold a value, unless the parts of `hs` below it hold all of it, or a part
may be held whole and another part of it uninitialized, or two disjoint
parts may be one uninitialized and the other held; or a piece may be
uninitialized while a part near it may hold one. The compiler destroys a
struct whole, and rejects a value with a field moved out; the human ruled
that a field never assigned counts the same (R, D-0003). Since `us`, `hs`
and `ps` hold what may be so on some path, a part uninitialized on one
path and held on another counts, as the compiler counts a field moved out
on one path only, unless it is held whole on every path that holds it, as
a variable assigned whole in one branch. A part built from its fields is
a piece, and the join of `hs` may fold its fields into it, so the last
condition finds it. The parts from depth `start` down are values of their
own: 1 for the `self` of `__deinit__`, destroyed field by field, and 0 for
any other value. -/
def partlyBuilt (prog : Program) (t : Ty) (us hs ps : List Path) (start : Nat) : Bool :=
  us.any (fun u => start ≤ u.length && hs.any fun h =>
      let (u', h') := (u.drop start, h.drop start)
      !initialized [u.take start] (h.take start) && u' != h' &&
        !(u'.isPrefixOf h' && holdsAll prog t hs u)) ||
    ps.any fun p => start ≤ p.length && us.any (·.isPrefixOf p) && !initialized hs p

/-- Whether a value of type `t` may not be destroyed, given its uninitialized parts
`us`, its parts moved out `ms`, its parts that may hold a value `hs`, its
touched parts `ts` and its pieces `ps`. It may not when it still holds a
part and a field was moved out of it, or it was moved out whole and then
built from its fields; when a field was moved out of a touched part; or
when it may be partly built. Parts from depth `start` down count, as in
`partlyBuilt`. -/
def cannotEnd (prog : Program) (t : Ty) (us ms hs ts ps : List Path) (start : Nat) : Bool :=
  let ms := ms.filter fun m => start == 0 || start < m.length
  let fields := ms.filter (!·.isEmpty)
  ((!fields.isEmpty || (ms.contains [] && ps.contains [])) && !hs.isEmpty) ||
    ts.any (fun c => fields.any (c.isPrefixOf ·)) ||
    partlyBuilt prog t us hs ps start

/-- Rejects the variable `v` if it may not end as it is. For the `self` of
`__deinit__`, only fields of its fields count. -/
def checkEnd (prog : Program) (v : VarState) : CheckM Unit := do
  let start := if v.access == .dying then 1 else 0
  if cannotEnd prog v.ty v.uninit v.moved v.held v.touched v.pieces start then
    flowCheck (throw (CheckError.partiallyDestroyed v.name))

/-- Rejects the state at a return: every `mut` parameter and the `self` of
`__init__` must be wholly initialized, with no part built from its fields,
and every variable must be allowed to end, checked after, as the compiler
reports a parameter left uninitialized first: the `mut` parameters in
their order, then the `self` of `__init__`. The caller uses a `mut`
parameter whole, so the compiler reports one that is itself built field by
field as a use of it. -/
def checkExit (prog : Program) : CheckM Unit := flowCheck do
  let vars := (← get).vars
  let params := vars.reverse.filter (·.access == .mutable) ++ vars.filter (·.access == .constructing)
  for v in params do
    if v.uninit.isEmpty && v.pieces == [[]] then
      throw (CheckError.uninitializedUse (.var v.name))
    if !v.uninit.isEmpty || !v.pieces.isEmpty then
      throw (CheckError.uninitializedAtExit v.name)
  for v in vars do
    if v.access != .readOnly then checkEnd prog v

/-- Ends the variables declared since the scope had `n` variables: checks
that each may end, if the end of the scope is reached, and removes them. -/
def endScope (prog : Program) (n : Nat) : CheckM Unit := do
  let s ← get
  let ended := s.vars.take (s.vars.length - n)
  if s.live then
    for v in ended do checkEnd prog v
  set { s with vars := s.vars.drop (s.vars.length - n),
               stale := s.stale.filter fun x => !ended.any (·.name == x) }

/-- The uninitialized parts after two branches: those of either. -/
def joinUninit (a b : List Path) : List Path :=
  b.foldl uninitialize a

/-- The variable `v` with the parts moved out, the parts that may hold a
value, the touched parts and the pieces of `w` added: what either of two
paths may leave. -/
def joinMay (v w : VarState) : VarState :=
  { v with moved := union v.moved w.moved, held := joinUninit v.held w.held,
           touched := union v.touched w.touched, pieces := union v.pieces w.pieces }

/-- The state after two branches that started from the same state: a part
is uninitialized, a field moved out, or a reference invalidated, when either
branch leaves it so. A branch that cannot reach its end does not count. -/
def joinStates (a b : State) : State :=
  if !a.live then b
  else if !b.live then a
  else { a with
         vars := List.zipWith (fun v w =>
             { joinMay v w with uninit := joinUninit v.uninit w.uninit })
           a.vars b.vars,
         stale := union a.stale b.stale }

/-- Rejects a loop whose body, from the state `before`, ends in the state
`after` with a part uninitialized that was initialized before, or with a
part moved out that was initialized and not moved out before: the next
iteration would use it uninitialized. A part uninitialized before the loop
may be assigned and moved out in each iteration. -/
def checkLoop (before after : State) : CheckM Unit := flowCheck do
  if after.live then
    for (v, w) in List.zip before.vars after.vars do
      let fresh := w.uninit.filter (fun u => !v.uninit.any (·.isPrefixOf u)) ++
        w.moved.filter fun m => !v.moved.contains m && !v.uninit.any (·.isPrefixOf m)
      if let some u := fresh.head? then throw (CheckError.uninitializedUse (partPlace v.name u))

end MojoGrimoire.Check
