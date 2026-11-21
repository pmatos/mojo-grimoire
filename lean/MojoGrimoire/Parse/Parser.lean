import MojoGrimoire.Parse.Lexer
import MojoGrimoire.Core.Program

/-!
The parser's monad, its token helpers, and the parsing of types.

The parser reads tokens from the front of a list and may fail with a
syntax error at the line of the token it stopped at. Every recursive
function of the parser takes fuel, which each call spends, so parsing is
total; a run that spends it all reports a program too deeply nested to
parse. Fuel of a few times the number of tokens is always enough, since
each call either reads a token or descends a fixed number of levels.

A type left for inference is written `unknown`, which is no Mojo type, so
the placeholder cannot be confused with a type the program declares, such
as `None` (#131). Inference replaces it.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- The parser's monad: the tokens left to read, and failure with a syntax
error. -/
abbrev P := StateT (List Token) (Except SyntaxError)

/-- The next token, if any. -/
def peek : P (Option Tok) := do pure ((← get).head?.map (·.tok))

/-- The token after the next one, if any. -/
def peek2 : P (Option Tok) := do pure ((← get).drop 1 |>.head? |>.map (·.tok))

/-- The line of the next token. -/
def curLine : P Nat := do pure ((← get).head?.map (·.line) |>.getD 0)

/-- Fails with a syntax error at the next token. -/
def fail {α : Type} (message : String) : P α := do throw ⟨← curLine, message⟩

/-- Reads the next token. -/
def next : P Tok := do
  match ← get with
  | t :: rest => set rest; pure t.tok
  | [] => fail "unexpected end of file"

/-- Whether the next token is the symbol `s`. -/
def atSym (s : String) : P Bool := do pure ((← peek) == some (.sym s))

/-- Whether the next token is the name or keyword `k`. -/
def atKw (k : String) : P Bool := do pure ((← peek) == some (.ident k))

/-- Reads the symbol `s` if it is next, and says whether it was. -/
def acceptSym (s : String) : P Bool := do
  if ← atSym s then let _ ← next; pure true else pure false

/-- Reads the keyword `k` if it is next, and says whether it was. -/
def acceptKw (k : String) : P Bool := do
  if ← atKw k then let _ ← next; pure true else pure false

/-- Reads the symbol `s`, or fails. -/
def expectSym (s : String) : P Unit := do
  unless ← acceptSym s do fail s!"expected `{s}`"

/-- Reads the keyword `k`, or fails. -/
def expectKw (k : String) : P Unit := do
  unless ← acceptKw k do fail s!"expected `{k}`"

/-- Reads the end of a logical line, or fails. -/
def expectNewline : P Unit := do
  unless (← peek) == some .newline do fail "expected the end of the line"
  let _ ← next

/-- Skips the ends of empty logical lines. -/
def skipNewlines : Nat → P Unit
  | 0 => pure ()
  | fuel + 1 => do if (← peek) == some .newline then let _ ← next; skipNewlines fuel

/-- The keywords, which are not names. -/
def keywords : List String :=
  ["def", "fn", "struct", "var", "ref", "if", "elif", "else", "while", "return", "pass",
   "and", "or", "not", "True", "False", "out", "mut", "deinit", "raises"]

/-- Reads a name, or fails. -/
def name : P Name := do
  match ← next with
  | .ident x => if keywords.contains x then fail s!"`{x}` is a keyword" else pure x
  | _ => fail "expected a name"

/-- A type argument of `List` or `Array` as the parser reads it: `None`
there is a value where Mojo expects a type, which the compiler rejects. It
is read as `unknown`, which the checker rejects as `invalidType`, as it
did before `None` was a type a variable may have (#183). -/
def typeArgument : Ty → Ty
  | .noneType => .unknown
  | t => t

/-- Reads a type: `Int`, `Bool`, `None`, `List[T]`, `Array[T, N]` with
`N` a literal, or the name of a struct. -/
def ty : Nat → P Ty
  | 0 => fail "a type too deeply nested"
  | fuel + 1 => do
    match ← name with
    | "Int" => pure .int
    | "Bool" => pure .bool
    | "None" => pure .noneType
    | "List" => do
      expectSym "["
      let t ← ty fuel
      expectSym "]"
      pure (.list (typeArgument t))
    | "Array" => do
      expectSym "["
      let t ← ty fuel
      expectSym ","
      let .int n ← next | fail "expected the size of an array"
      expectSym "]"
      pure (.array (typeArgument t) n)
    | s => pure (.struct s)

end MojoGrimoire.Parse
