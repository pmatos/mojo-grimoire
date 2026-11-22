import MojoGrimoire.Parse.Expr

/-!
The parsing of statements, blocks, functions, structs and programs.

A block follows a `:`: either one simple statement on the same line, or
statements on the lines after it, indented further. `elif` is an `if` in
the `else` block. `print(…)` is a statement of its own, and `x += e`,
`x -= e` and `x *= e` are calls of the callees `+=`, `-=` and `*=` with
`x` and `e`, which inference replaces: by `x.__iadd__(e)` when `x` is a
struct, and otherwise by `x = x + e`, `x = x - e` or `x = x * e` (#191).
No name of a program is such a callee. A string literal on a line of its
own, a docstring, is skipped. The line where each statement starts is
recorded with its function, for the check of the constructs outside the
subset (`MojoGrimoire.Parse.Subset`).

A struct's `self` parameters may be written without a type: the struct is
their type. A struct's conformances say how it is copied:
`ImplicitlyCopyable` implicitly, as `TrivialRegisterPassable`, which
implies it (#164); `Copyable` explicitly; and otherwise not at all.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- The augmented assignment operators. -/
def augOps : List (String × BinOp) := [("+=", .add), ("-=", .sub), ("*=", .mul)]

/-- The callee of the augmented assignment of the operator `op`, as the
parser reads it, for inference to replace. -/
def augCallee (op : BinOp) : Name :=
  ((augOps.find? (·.2 == op)).map (·.1)).getD "+="

/-- The statement that an expression on a line of its own stands for: a
call of `print` is a `print` statement. -/
def exprStmt : Expr → Stmt
  | .call "print" args => .print args
  | e => .expr e

mutual
/-- Reads a simple statement, one that holds no block. -/
def simpleStmt (fuel : Nat) : P Stmt :=
  match fuel with
  | 0 => fail "a statement too deeply nested"
  | n + 1 => do
    if ← acceptKw "pass" then pure .pass
    else if ← acceptKw "return" then
      if (← peek) == some .newline then pure (.ret none) else pure (.ret (some (← expr n)))
    else if ← acceptKw "var" then
      let x ← name
      let t ← if ← acceptSym ":" then ty n else pure .unknown
      let init ← if ← acceptSym "=" then pure (some (← expr n)) else pure none
      pure (.decl x t init)
    else if ← acceptKw "ref" then
      let x ← name
      expectSym "="
      pure (.refDecl x (← expr n))
    else
      match ← chain n with
      | .expr e => do pure (exprStmt (← exprTail n e))
      | .place lhs => do
        if ← acceptSym "=" then pure (.assign lhs (← expr n))
        else match ← acceptOp augOps with
          | some op => pure (.expr (.call (augCallee op) [.place lhs, ← expr n]))
          | none => pure (exprStmt (← exprTail n (.place lhs)))

/-- Reads the rest of an expression whose first postfix chain is `e`. -/
def exprTail (fuel : Nat) (e : Expr) : P Expr :=
  match fuel with
  | 0 => fail "an expression too long"
  | n + 1 => do
    let e ← sumRest n (← productRest n e)
    let e ← match ← acceptOp compOps with
      | some op => pure (.binary op e (← sum n))
      | none => pure e
    orRest n (← andRest n e)

/-- Reads a statement and the end of its line, and records where it
starts. -/
def stmt (fuel : Nat) : P Stmt :=
  match fuel with
  | 0 => fail "a statement too deeply nested"
  | n + 1 => do
    markStmt
    if ← acceptKw "if" then ifRest n
    else if ← acceptKw "while" then
      let c ← expr n
      pure (.whileLoop c (← block n))
    else
      let s ← simpleStmt n
      expectNewline
      pure s

/-- Reads the rest of an `if` or `elif`, after its keyword. An `elif` is a
statement of its own, in the `else` block, and is recorded so. -/
def ifRest (fuel : Nat) : P Stmt :=
  match fuel with
  | 0 => fail "a statement too deeply nested"
  | n + 1 => do
    let c ← expr n
    let a ← block n
    if ← acceptKw "elif" then
      markStmt
      pure (.ifElse c a [← ifRest n])
    else if ← acceptKw "else" then pure (.ifElse c a (← block n))
    else pure (.ifElse c a [])

/-- Reads a block, from its `:`. A simple statement on the same line is
recorded where it starts. -/
def block (fuel : Nat) : P (List Stmt) :=
  match fuel with
  | 0 => fail "a block too deeply nested"
  | n + 1 => do
    expectSym ":"
    if (← peek) == some .newline then
      expectNewline
      unless (← peek) == some .indent do fail "expected an indented block"
      let _ ← next
      stmts n
    else
      markStmt
      let s ← simpleStmt n
      expectNewline
      pure [s]

/-- Reads statements up to the end of their block, and the dedent that ends
it. A docstring is skipped. -/
def stmts (fuel : Nat) : P (List Stmt) :=
  match fuel with
  | 0 => fail "a block too long"
  | n + 1 => do
    match ← peek with
    | some .dedent => let _ ← next; pure []
    | some .newline => let _ ← next; stmts n
    | some (.str _) =>
      if (← peek2) == some .newline then
        let _ ← next
        let _ ← next
        stmts n
      else pure ((← stmt n) :: (← stmts n))
    | _ => pure ((← stmt n) :: (← stmts n))
end

/-- Reads an argument convention, if one is next. `imm` is the immutable
convention, which the checker calls `read`. As in the compiler, `read` where
a parameter starts is an error, and `owned` is a name. -/
def conv : P (Option Conv) := do
  match ← peek, ← peek2 with
  | some (.ident "read"), _ => fail "`read` was removed; use `imm`"
  | some (.ident "imm"), _ => let _ ← next; pure (some .read)
  | some (.ident k), some (.ident _) =>
    let c? : Option Conv := match k with
      | "mut" => some .mutable
      | "var" => some .owned
      | "ref" => some .ref
      | "out" => some .out
      | "deinit" => some .deinit
      | _ => none
    if c?.isSome then let _ ← next
    pure c?
  | _, _ => pure none

/-- Reads the parameters of a function, up to `)`. `self` has the type
`selfTy`, when the function is a method of a struct. -/
def params (selfTy : Option Ty) : Nat → P (List Param)
  | 0 => fail "too many parameters"
  | n + 1 => do
    if ← acceptSym ")" then return []
    let c := (← conv).getD .read
    let x ← name
    let t ← if ← acceptSym ":" then ty n else
      match selfTy, x with
      | some t, "self" => pure t
      | _, _ => fail s!"the parameter `{x}` has no type"
    let p : Param := ⟨c, x, t⟩
    if ← acceptSym "," then pure (p :: (← params selfTy n)) else
      expectSym ")"
      pure [p]

/-- Reads the names of an origin, `[a, b]`, after its `[`. -/
def originNames : Nat → P (List Name)
  | 0 => fail "an origin too long"
  | n + 1 => do
    let x ← name
    if ← acceptSym "," then pure (x :: (← originNames n)) else
      expectSym "]"
      pure [x]

/-- Reads a function, from its `def` or `fn`, with the type of `self` for a
method, and records it with the lines where its statements start. -/
def funDecl (selfTy : Option Ty) (fuel : Nat) : P FunDecl := do
  modify fun s => { s with lines := [] }
  let f ← name
  expectSym "("
  let ps ← params selfTy fuel
  let _ ← acceptKw "raises"
  let (origin, result) ← if ← acceptSym "->" then
      if ← acceptKw "ref" then
        expectSym "["
        let os ← originNames fuel
        pure (some os, ← ty fuel)
      else pure (none, ← ty fuel)
    else pure (none, .noneType)
  let body ← block fuel
  let fd : FunDecl := ⟨f, ps, result, body, origin⟩
  modify fun s => { s with bodies := (fd, s.lines.reverse) :: s.bodies }
  pure fd

/-- Reads the conformances of a struct, after its `(`, and gives how its
values are copied. -/
def conformances : Nat → Copying → P Copying
  | 0, _ => fail "too many conformances"
  | n + 1, c => do
    let t ← name
    let c' := match t, c with
      | "ImplicitlyCopyable", _ | "TrivialRegisterPassable", _ => Copying.implicit
      | "Copyable", .none => .explicit
      | _, c => c
    if ← acceptSym "," then conformances n c' else
      expectSym ")"
      pure c'

/-- The state `st` with the destructor of the struct `s` just recorded
given `self` alone as its parameter: the later passes check its body with
`self` alone in scope, whatever its parameters. -/
def PState.deinitScope (s : Name) (st : PState) : PState :=
  match st.bodies with
  | (fd, ls) :: rest =>
    { st with bodies := ({ fd with params := [⟨.deinit, "self", .struct s⟩] }, ls) :: rest }
  | [] => st

/-- Reads the members of a struct up to the dedent that ends them: fields,
methods, `pass` and docstrings. -/
def members (s : Name) : Nat → StructDecl → P StructDecl
  | 0, _ => fail "a struct too long"
  | n + 1, sd => do
    match ← peek with
    | some .dedent => let _ ← next; pure sd
    | some .newline | some (.str _) => let _ ← next; members s n sd
    | some (.ident "pass") => let _ ← next; expectNewline; members s n sd
    | some (.ident "var") =>
      let _ ← next
      let f ← name
      expectSym ":"
      let t ← ty n
      expectNewline
      members s n { sd with fields := sd.fields ++ [(f, t)] }
    | some (.ident "def") | some (.ident "fn") =>
      let _ ← next
      let fd ← funDecl (some (.struct s)) n
      match fd.name with
      | "__init__" => members s n { sd with init := some fd }
      | "__deinit__" => do
        modify (PState.deinitScope s)
        members s n { sd with deinit := some fd.body }
      | _ => members s n { sd with methods := sd.methods ++ [fd] }
    | _ => fail "expected a field or a method"

/-- Reads a struct, from its `struct`, with whether it is
`@fieldwise_init`. -/
def structDecl (fieldwise : Bool) (fuel : Nat) : P StructDecl := do
  let s ← name
  let copying ← if ← acceptSym "(" then conformances fuel .none else pure .none
  expectSym ":"
  expectNewline
  unless (← peek) == some .indent do fail "expected an indented struct body"
  let _ ← next
  members s fuel ⟨s, [], copying, fieldwise, none, none, []⟩

/-- Reads the declarations of a program up to the end of the file. -/
def decls : Nat → Program → P Program
  | 0, _ => fail "a program too long"
  | n + 1, prog => do
    match ← peek with
    | none => pure prog
    | some .newline => let _ ← next; decls n prog
    | some (.sym "@") =>
      let _ ← next
      let d ← name
      unless d == "fieldwise_init" do fail s!"unknown decorator @{d}"
      expectNewline
      expectKw "struct"
      decls n { prog with structs := prog.structs ++ [← structDecl true n] }
    | some (.ident "struct") =>
      let _ ← next
      decls n { prog with structs := prog.structs ++ [← structDecl false n] }
    | some (.ident "def") | some (.ident "fn") =>
      let _ ← next
      decls n { prog with funs := prog.funs ++ [← funDecl none n] }
    | _ => fail "expected a struct or a function"

/-- Parses the text of a `.mojo` file, before inference, and gives each
function, method, initializer and destructor in the order of the file,
with the lines where its statements start, in the order that a walk of its
body visits them, each statement before the statements it holds. -/
def parseLines (source : String) : Except SyntaxError (Program × List (FunDecl × List Nat)) := do
  let toks ← lex source
  let (prog, st) ← (decls (10 * toks.length + 100) { structs := [], funs := [] }).run ⟨toks, [], []⟩
  pure (prog, st.bodies.reverse)

/-- Parses the text of a `.mojo` file, before inference. -/
def parseRaw (source : String) : Except SyntaxError Program := do
  pure (← parseLines source).1

end MojoGrimoire.Parse
