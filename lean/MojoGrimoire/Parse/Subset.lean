import MojoGrimoire.Parse.Infer

/-!
The constructs outside the subset that the model covers (#180).

A program outside the subset ends with exit 3, never with a checker error
class: a class claims that Mojo rejects the program, and the compiler may
accept it. The human ruled this on 2026-11-20. Every exclusion is
temporary, since the goal is a model of the whole of Mojo, and only the
human adds a construct to the list on `docs/decisions/semantics-parser.md`.
Three constructs are on it today, each a ruling or a decision page puts
outside the subset:

- a string literal anywhere but as an argument of the `print` statement:
  the Phase 1 subset has no string type, and `print` alone takes string
  literals;
- a call of the standard library's `range` anywhere but as the one
  argument of `List[T](…)`, by the ruling of 2026-11-19 on #121;
- the statements `break` and `continue`, wherever they stand, by the
  ruling of 2026-11-22 on #268, until #276 supports them after #96's flow
  parts. The parser reads each as a call of a callee of its name
  (`loopExits`), which no name of a program is, since both are keywords.

Telling whether `print` and `range` are the standard library's needs the
names in scope: a variable or a parameter named `print` makes the `print`
statement a call of it, whose string arguments are outside the subset, and
a variable, a parameter, a struct or a function named `range` hides the
standard library's `range` (#176). A destructor's body has `self` alone in
scope, as in the checker. It needs no types, so this check runs on
the program as parsed, before inference, which rewrites `p += e` and the
`print` statement of a variable into other forms. Docstrings are skipped by
the parser and are not string literals of the program.

The program is outside the subset wherever the construct stands, whatever
other error it has: the check reports the first construct in the order of
the file, at the line where the statement that holds it starts, and the
driver prints `outside the subset: line N: MESSAGE` and exits with 3.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- A construct outside the subset: the line where the statement that
holds it starts, and what the construct is. -/
structure Outside where
  line : Nat
  message : String
  deriving DecidableEq, Repr

/-- Why the text of a `.mojo` file is no program of the subset: a syntax
error, or a construct outside the subset. -/
inductive ReadError where
  | syntax (e : SyntaxError)
  | outside (o : Outside)
  deriving DecidableEq, Repr

/-- What a string literal outside the `print` statement is. -/
def outsideString : String := "a string literal outside `print`"

/-- What a call of the standard library's `range` outside `List[T](…)` is. -/
def outsideRange : String := "a call of `range` outside `List[T](...)`"

/-- What the statement `break` or `continue`, named `k`, is. -/
def outsideLoopExit (k : Name) : String := s!"a `{k}` statement"

/-- The statement `break` or `continue` that the expression `e` on a line
of its own stands for, as the parser reads it, if it is one. -/
def loopExit : Expr → Option String
  | .call k [] => if loopExits.contains k then some (outsideLoopExit k) else none
  | _ => none

/-- Whether a call of `range`, where the names `vs` are in scope, calls the
standard library's: no variable or parameter in scope has that name, and
nor does a struct or a function of the program `prog`, as the checker
decides (`MojoGrimoire.Check.builtinRange`). -/
def stdRange (prog : Program) (vs : List Name) : Bool :=
  MojoGrimoire.Check.builtinRange prog "range" && !vs.contains "range"

mutual
/-- The first construct outside the subset in the indices of the place
`p`, where the names `vs` are in scope. -/
def Place.outside (prog : Program) (vs : List Name) : Place → Option String
  | .var _ => none
  | .field p _ => Place.outside prog vs p
  | .index p i => Place.outside prog vs p <|> Expr.outside prog vs i
  | .transferred p => Place.outside prog vs p

/-- The first construct outside the subset in the expression `e`, in the
order of its text, where the names `vs` are in scope. The one argument of
`List[T](…)` may be a call of `range`, whose own arguments are checked. -/
def Expr.outside (prog : Program) (vs : List Name) : Expr → Option String
  | .int _ | .bool _ => none
  | .str _ => some outsideString
  | .place p | .transfer p | .copy p => Place.outside prog vs p
  | .call f args =>
    if f == "range" && stdRange prog vs then some outsideRange
    else Expr.listOutside prog vs args
  | .method p _ args => Place.outside prog vs p <|> Expr.listOutside prog vs args
  | .unary _ a => Expr.outside prog vs a
  | .binary _ a b => Expr.outside prog vs a <|> Expr.outside prog vs b
  | .list _ es => Expr.listOutside prog vs es
  | .listInit _ [.call "range" args] => Expr.listOutside prog vs args
  | .listInit _ es => Expr.listOutside prog vs es
  | .withDrops e _ _ => Expr.outside prog vs e

/-- The first construct outside the subset in the expressions `es`. -/
def Expr.listOutside (prog : Program) (vs : List Name) : List Expr → Option String
  | [] => none
  | e :: es => Expr.outside prog vs e <|> Expr.listOutside prog vs es
end

/-- Fails with the construct `found`, if any, of the statement whose index
is `k`. -/
def foundIn (k : Nat) : Option String → Except (Nat × String) Unit
  | some m => throw (k, m)
  | none => pure ()

mutual
/-- Walks the statement `st`, whose index is `k`, where the names `vs` are
in scope: fails with the index of the statement that holds the first
construct outside the subset, and the construct, or gives the index of the
statement after `st` and those it holds, and the names in scope after it.
A variable declared with `var` or bound with `ref` is in scope after its
declaration in its block, not in its own initializer. The arguments of the
`print` statement may be string literals. -/
def Stmt.outside (prog : Program) (vs : List Name) (k : Nat) :
    Stmt → Except (Nat × String) (Nat × List Name)
  | .pass | .drop _ => pure (k + 1, vs)
  | .decl x _ init => do foundIn k (init.bind (Expr.outside prog vs)); pure (k + 1, x :: vs)
  | .refDecl x e => do foundIn k (Expr.outside prog vs e); pure (k + 1, x :: vs)
  | .assign p e => do
    foundIn k (Place.outside prog vs p <|> Expr.outside prog vs e)
    pure (k + 1, vs)
  | .expr e => do foundIn k (loopExit e <|> Expr.outside prog vs e); pure (k + 1, vs)
  | .print args => do
    foundIn k (Expr.listOutside prog vs
      (if vs.contains "print" then args else args.filter (!· matches .str _)))
    pure (k + 1, vs)
  | .ifElse c a b => do
    foundIn k (Expr.outside prog vs c)
    let k' ← Stmt.blockOutside prog vs (k + 1) a
    pure (← Stmt.blockOutside prog vs k' b, vs)
  | .whileLoop c body => do
    foundIn k (Expr.outside prog vs c)
    pure (← Stmt.blockOutside prog vs (k + 1) body, vs)
  | .ret value => do foundIn k (value.bind (Expr.outside prog vs)); pure (k + 1, vs)

/-- Walks the statements `b` of a block, from the index `k`, as
`Stmt.outside` does, and gives the index after them. -/
def Stmt.blockOutside (prog : Program) (vs : List Name) (k : Nat) :
    List Stmt → Except (Nat × String) Nat
  | [] => pure k
  | st :: rest => do
    let (k', vs') ← Stmt.outside prog vs k st
    Stmt.blockOutside prog vs' k' rest
end

/-- The first construct outside the subset in the body of the function
`fd`, whose parameters are in scope, at the line where its statement
starts: `lines` gives the line of each statement of the body, in the
order that `Stmt.blockOutside` walks them. -/
def FunDecl.outside (prog : Program) (fd : FunDecl) (lines : List Nat) : Option Outside :=
  match Stmt.blockOutside prog (fd.params.map (·.name)) 0 fd.body with
  | .error (k, m) => some ⟨lines.getD k 0, m⟩
  | .ok _ => none

/-- The first construct outside the subset of the program `prog`, in the
order of its file: `bodies` gives each function, method, initializer and
destructor in that order, with the lines of its statements. -/
def outsideSubset (prog : Program) : List (FunDecl × List Nat) → Option Outside
  | [] => none
  | (fd, lines) :: rest => FunDecl.outside prog fd lines <|> outsideSubset prog rest

/-- Parses the text of a `.mojo` file into a program of the subset, as
`parse` does, unless it has a syntax error or a construct outside the
subset, which is checked before inference. -/
def parseSubset (source : String) : Except ReadError Program := do
  let (raw, bodies) ← (parseLines source).mapError ReadError.syntax
  if let some o := outsideSubset raw bodies then throw (ReadError.outside o)
  pure (inferRaw raw)

end MojoGrimoire.Parse
