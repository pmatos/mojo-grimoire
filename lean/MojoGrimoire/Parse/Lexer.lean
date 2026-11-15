/-!
The lexer: from the text of a `.mojo` file to a list of tokens.

Mojo, like Python, marks blocks by indentation. The lexer turns the start of
each logical line into `newline`, and a change of indentation into `indent`
or `dedent`, so that the parser sees blocks as brackets. A line that is
empty or holds only a comment does not count. Inside parentheses or square
brackets, a line break does not end the line. A comment runs from `#` to
the end of the line.
-/

namespace MojoGrimoire.Parse

/-- A token: a name or keyword, an integer literal, a string literal, a
symbol, the end of a logical line, or a change of indentation. -/
inductive Tok where
  | ident (name : String)
  | int (value : Nat)
  | str (value : String)
  | sym (s : String)
  | newline
  | indent
  | dedent
  deriving DecidableEq, Repr

/-- A token and the line it starts on, counted from 1. -/
structure Token where
  tok : Tok
  line : Nat
  deriving DecidableEq, Repr

/-- An error in the text of a program, found by the lexer or the parser: its
line and what went wrong. -/
structure SyntaxError where
  line : Nat
  message : String
  deriving DecidableEq, Repr

/-- The symbols, longest first, so that `//` is read before `/`. -/
def symbols : List String :=
  ["->", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "(", ")", "[", "]", ",", ":", ".",
   "=", "+", "-", "*", "%", "<", ">", "^", "@"]

/-- Whether `c` may start a name. -/
def isNameStart (c : Char) : Bool := c.isAlpha || c == '_'

/-- Whether `c` may continue a name. -/
def isNameChar (c : Char) : Bool := c.isAlphanum || c == '_'

/-- The tokens of the characters `cs` of one line, given the bracket depth
before them, with the bracket depth after them. Each step reads at least
one character, so `fuel`, the number of characters, is enough. -/
def lexChars (line : Nat) : Nat → List Char → Nat → Except SyntaxError (List Token × Nat)
  | _, [], depth => pure ([], depth)
  | 0, _ :: _, _ => throw ⟨line, "a line too long to read"⟩
  | fuel + 1, c :: cs, depth =>
    let next (t : Tok) (rest : List Char) (depth' : Nat) := do
      let (toks, d) ← lexChars line fuel rest depth'
      pure (⟨t, line⟩ :: toks, d)
    if c == ' ' || c == '\t' || c == '\r' then lexChars line fuel cs depth
    else if c == '#' then pure ([], depth)
    else if c.isDigit then
      let digits := (c :: cs).takeWhile Char.isDigit
      let value := digits.foldl (fun n d => 10 * n + (d.toNat - '0'.toNat)) 0
      next (.int value) ((c :: cs).dropWhile Char.isDigit) depth
    else if isNameStart c then
      let name := (c :: cs).takeWhile isNameChar
      next (.ident (String.ofList name)) ((c :: cs).dropWhile isNameChar) depth
    else if c == '"' && cs.take 2 == ['"', '"'] then
      let body := cs.drop 2
      let rec close : List Char → List Char → Option (List Char × List Char)
        | '"' :: '"' :: '"' :: rest, acc => some (acc.reverse, rest)
        | x :: rest, acc => close rest (x :: acc)
        | [], _ => none
      match close body [] with
      | some (text, rest) => next (.str (String.ofList text)) rest depth
      | none => throw ⟨line, "a docstring that does not close on its line"⟩
    else if c == '"' then
      match cs.dropWhile (· != '"') with
      | _ :: rest => next (.str (String.ofList (cs.takeWhile (· != '"')))) rest depth
      | [] => throw ⟨line, "a string literal with no closing quote"⟩
    else
      match symbols.find? fun s => (c :: cs).take s.length == s.toList with
      | some s =>
        let depth' :=
          if s == "(" || s == "[" then depth + 1
          else if s == ")" || s == "]" then depth - 1
          else depth
        next (.sym s) ((c :: cs).drop s.length) depth'
      | none => throw ⟨line, s!"unexpected character {c}"⟩

/-- The tokens of the characters `cs` of one line, given the bracket depth
before them, with the bracket depth after them. -/
def lexLine (line : Nat) (cs : List Char) (depth : Nat) : Except SyntaxError (List Token × Nat) :=
  lexChars line cs.length cs depth

/-- The indentation of a line: its leading spaces. -/
def indentation (cs : List Char) : Nat := (cs.takeWhile (· == ' ')).length

/-- Whether a line is blank or holds only a comment. -/
def isBlank (cs : List Char) : Bool :=
  match cs.dropWhile (fun c => c == ' ' || c == '\t' || c == '\r') with
  | [] => true
  | c :: _ => c == '#'

/-- The tokens of the lines `lines`, numbered from `n`, given the stack of
enclosing indentations and the bracket depth. A line inside brackets
continues the logical line before it. -/
def lexLines : List String → Nat → List Nat → Nat → Except SyntaxError (List Token)
  | [], n, stack, _ =>
    pure ((stack.dropLast.map fun _ => ⟨.dedent, n⟩) ++ [⟨.newline, n⟩])
  | l :: ls, n, stack, depth => do
    let cs := l.toList
    if isBlank cs then lexLines ls (n + 1) stack depth
    else if depth > 0 then
      let (toks, d) ← lexLine n cs depth
      let nl : List Token := if d > 0 then [] else [⟨.newline, n⟩]
      pure (toks ++ nl ++ (← lexLines ls (n + 1) stack d))
    else
      let col := indentation cs
      let top := stack.headD 0
      let (layout, stack') ←
        if col > top then pure ([⟨.indent, n⟩], col :: stack)
        else if col == top then pure ([], stack)
        else
          let popped := stack.takeWhile (· > col)
          let rest := stack.dropWhile (· > col)
          if rest.headD 0 != col then throw ⟨n, "a dedent to no enclosing indentation"⟩
          pure (popped.map fun _ => ⟨.dedent, n⟩, rest)
      let (toks, d) ← lexLine n cs 0
      let nl : List Token := if d > 0 then [] else [⟨.newline, n⟩]
      pure (layout ++ toks ++ nl ++ (← lexLines ls (n + 1) stack' d))

/-- The tokens of a `.mojo` file. -/
def lex (source : String) : Except SyntaxError (List Token) :=
  lexLines (source.splitOn "\n") 1 [0] 0

end MojoGrimoire.Parse
