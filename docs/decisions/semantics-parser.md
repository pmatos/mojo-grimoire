# Current decisions: semantics, the parser and the driver

This page continues [semantics.md](semantics.md) with how the model reads a
`.mojo` file and runs it.

## The parser and the driver

`MojoGrimoire.Parse` reads a `.mojo` file into the core calculus, and
`mojo-grimoire FILE [--fuel N]` runs it (#23). It reads the subset the
model covers and fails with a syntax error, line and message, on anything
else. These choices hold:

- A struct's conformances give its copying: `ImplicitlyCopyable` implicit,
  and so `TrivialRegisterPassable`, which implies it on the pinned
  nightly (#164); `Copyable` explicit; and otherwise none. The other
  rules of `TrivialRegisterPassable` types are not modelled yet (#217).
  Other conformances, `raises` and the decorator `@fieldwise_init` aside,
  are read and ignored.
- `imm` is the immutable convention, which the checker calls `read`, as
  is a parameter with no convention; `var` is owned; `self` may omit its
  type. As in the compiler, `read` where a parameter starts, `imm` with no
  name after it, and `owned xs: T` are syntax errors, and `imm`, `read` and
  `owned` are names elsewhere (#68).
- `p += e`, `-=` and `*=` are `p = p op e`, or, when `p` is a struct, a
  call of its `__iadd__`, `__isub__` or `__imul__`, as inference decides
  ([semantics-operators.md](semantics-operators.md), #191); `print(...)`
  on a line of its own is the print statement, or a call of a variable
  named `print`; docstrings are skipped. Inside a struct's methods, `Self`
  is the struct, also as the constructor `Self(…)`; not yet as a field's
  type (#203).
- `^` after a term is binary XOR, as in the compiler's postfix loop
  (`ParserExprs.cpp`), when the next token can start an expression
  (`isPrimaryExprStart`), is not `.`, and lies in the same statement. XOR is
  outside the subset, so `x^ + 1`, `x^ (1)`, `x^ * 2` and `x^ == 3` are
  syntax errors. Otherwise `^` is a transfer: `f(x^)`, `(x^)`, `x^` at the
  end of a line, and `x^` before `<`, `and` or `or` (#54); before `if`, `in`
  or `is` it is not XOR either, but the model reads none of those forms.
  The compiler continues a statement onto a deeper-indented line, and,
  inside call arguments and subscripts, onto any line, so there `x^` with
  `+ 1` on the next line is XOR. Inside a parenthesized expression or a
  list literal it does not, and `(x^` with `+ 1)` at the statement's column
  fails to parse. The model's lexer ignores line breaks inside brackets, so
  it reads XOR in all of these, and ends the logical line outside them,
  where the indented line is a syntax error: each is a syntax error in the
  model as in the compiler.
- `x^` followed by `.` goes on as a postfix chain, as in the compiler:
  `s^.f`, `s^ .f`, `s^.m(…)`, `s^.copy()`, `s^.r.id` and `s^.r^` read a
  field or call a method of the place `s^` (#66; see the static checker in
  [semantics.md](semantics.md#the-static-checker)). `s^[0]` and `s^(…)` are
  XOR, as above.
- The parser writes the type `None` where the program leaves a type
  implicit, since no variable of the subset has that type. Inference then
  gives `var x = e` the type of `e`, and a literal `[e1, …, en]` the type
  expected where it stands, or else `Array[T, n]` (see
  [Arrays](semantics-lists.md#arrays)). A literal `[e]` of one `Int`
  element where an `Int` is expected is replaced by `e`, or, when `e` is
  made only of literals and operators or the literal is passed `mut` or
  `ref`, gets the type `Int` (#103).
  What it cannot find stays `None`, and the checker rejects it, after the
  initializer's own error, which comes first (#123). A literal
  with no expected type keeps `None` as its own type, which the checker
  replaces with its elements' type, so that the checker tells it from a
  literal that initializes an expected type (#46).
- `List[T]()` is an empty list. `List[T](e1, …, en)` with arguments is
  read as its own expression, which the checker accepts only for one
  argument that is a list or an array of `T`, or a call of `range` (see
  [Lists](semantics-lists.md#lists)). Its one argument `p^` is read as the
  place `p^`, which the compiler borrows (#103). `List[T](capacity=n)` is outside the
  subset and a syntax error.
- The exit code says how a run ended: 0 finished, 1 rejected
  (`rejected: CLASS in DECL` on standard error), 2 a run-time error
  (`run-time error: NAME`), 3 a syntax error (`syntax error: line N:
  MESSAGE`), 4 a command line or file that cannot be used. The conformance
  suite compares 0 to 2, and the printed lines, with the compiler's. It
  cannot compare a syntax error with the compiler's parse error, so the
  rejections the compiler makes while parsing (#54, #68) are pinned by
  `#guard` tests and have no suite program. Their list, with the
  compiler's first errors, is on
  [conformance.md](conformance.md#rejections-made-while-parsing).

## Outside the subset

A program outside the subset ends with exit 3, never with a checker error
class: a class claims that Mojo rejects the program, and the compiler may
accept it. The human ruled this on 2026-11-20. Where only the checker can
tell that a construct is outside the subset, the driver still exits with 3
(#180, which tracks the checker classes that break this today).

Every exclusion is temporary. The goal is a model of the whole of Mojo, so
each excluded construct is future work, not a boundary of the design. Only
the human adds a construct to the excluded list. An agent never excludes a
construct to make a disagreement with the compiler go away, because the
suite cannot compare exit 3 and would hide it.
