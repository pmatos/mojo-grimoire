# Current decisions: semantics, the parser and the driver

This page continues [semantics.md](semantics.md) with how the model reads a
`.mojo` file and runs it.

## The parser and the driver

`MojoGrimoire.Parse` reads a `.mojo` file into the core calculus, and
`mojo-grimoire FILE [--fuel N]` runs it (#23). It fails with a syntax
error, line and message, on what it cannot read, and the constructs it
reads but the subset excludes end with exit 3 too
([below](#outside-the-subset)). These choices hold:

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
  type (#203). Before that, each name in a type that a variable or a
  parameter in scope hides is marked, and the checker rejects it as
  `valueAsType`
  ([conformance-classes.md](conformance-classes.md#types-that-a-variable-hides),
  #193).
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
- The parser writes the type `unknown`, which is no Mojo type, where the
  program leaves a type implicit, so that a failed inference and a real
  `None` differ (#131). Inference then
  gives `var x = e` the type of `e`, and a literal `[e1, …, en]` the type
  expected where it stands, or else `Array[T, n]` (see
  [Arrays](semantics-lists.md#arrays)). A literal `[e]` of one `Int`
  element where an `Int` is expected is replaced by `e`, or, when `e` is
  made only of literals and operators or the literal is passed `mut` or
  `ref`, gets the type `Int` (#103).
  What it cannot find stays `unknown`, and the checker rejects it, after
  the initializer's own error, which comes first (#123). A literal
  with no expected type keeps `unknown` as its own type, which the checker
  replaces with its elements' type, so that the checker tells it from a
  literal that initializes an expected type (#46).
- A value of type `None`, from a call that returns nothing, is a value as
  in the nightly: a variable may hold one, with or without the annotation
  `None`, copy it implicitly, and transfer it, which has no effect, as for
  `Int`; a literal may hold them, as `Array[None, n]`. `print` cannot
  write one (`notPrintable`), and it has no operator methods
  (`missingMethod`) and no `.copy()` (`unknownAttribute`, "'None' has no
  attributes"). The human ruled this on 2026-11-20 (#131). `None` written
  as an expression, and parameters and fields of type `None`, are not
  modelled yet (#183): the parser reads `None` as an expression as a name,
  as before. `None` as a type argument, `List[None]`, is such a value
  where the compiler expects a type, which it rejects; the parser reads it
  as `unknown`, which the checker rejects as `invalidType`.
- `List[T]()` is an empty list. `List[T](e1, …, en)` with arguments is
  read as its own expression, which the checker accepts only for one
  argument that is a list or an array of `T`, or a call of `range` (see
  [Lists](semantics-lists.md#lists)). Its one argument `p^` is read as the
  place `p^`, which the compiler borrows (#103). `List[T](capacity=n)` is outside the
  subset and a syntax error.
- The exit code says how a run ended: 0 finished, 1 rejected
  (`rejected: CLASS in DECL` on standard error), 2 a run-time error
  (`run-time error: NAME`), 3 a syntax error (`syntax error: line N:
  MESSAGE`) or a program outside the subset (`outside the subset: line N:
  MESSAGE`, [below](#outside-the-subset)), 4 a command line or file that
  cannot be used. The conformance
  suite compares 0 to 2, and the printed lines, with the compiler's. It
  cannot compare a syntax error with the compiler's parse error, so the
  rejections the compiler makes while parsing (#54, #68) are pinned by
  `#guard` tests and have no suite program. Their list, with the
  compiler's first errors, is on
  [conformance.md](conformance.md#rejections-made-while-parsing).

## Outside the subset

A program outside the subset ends with exit 3, never with a checker error
class: a class claims that Mojo rejects the program, and the compiler may
accept it. The human ruled this on 2026-11-20. What the parser cannot read
is a syntax error, as above. The parser reads the excluded constructs
below, and `MojoGrimoire.Parse.Subset` finds them (#180). Each one needs
only the syntax and the names in scope, so the check runs on the parsed program
before inference, which rewrites `p += e` and a `print` statement of a
variable into other forms. The program is outside the subset wherever the
construct stands, whatever other error it has; a syntax error anywhere
comes first. The driver prints `outside the subset: line N: MESSAGE` on
standard error and exits with 3. `N` is the line where the statement that
holds the first construct in the order of the file starts, and `MESSAGE`
names the construct: `` a string literal outside `print` ``,
`` a call of `range` outside `List[T](...)` ``, `` a `break` statement ``
or `` a `continue` statement ``.

The excluded constructs, each temporary:

- A string literal anywhere but as an argument of the `print` statement,
  such as `P("a")` (#175), `len("a")`, `xs["a"]` or
  `List[Int](range(u + "a"))`. The Phase 1 subset that the human approved
  ([process.md](process.md#phase-1-the-core-calculus-in-lean)) has no
  string type, and `print` alone takes string literals
  ([semantics.md](semantics.md#the-static-checker)). A variable or a
  parameter named `print` makes the statement a call of it, so its string
  literals are outside the subset too; a function or a struct of the
  program named `print` does not yet, as in the checker (#244). Covering
  them is #238.
- A call of the standard library's `range` anywhere but as the one
  argument of `List[T](…)`, such as `var r = range(3)`, `len(range(3))`
  or `List[Int](range(p.x + range(2)))`: the human ruled on 2026-11-19
  that the model takes `range` only there (#121). A variable or a parameter in scope, or
  a struct or a function of the program, named `range` hides it, as in a
  call (#176). A destructor's body has `self` alone in scope, as in the
  checker. Covering a range as a value is #239.
- The statements `break` and `continue`, wherever they stand: in a loop,
  in a block on the line of its `:`, or outside any loop, which the
  compiler rejects after parsing ("'break' is not inside a loop"). The
  human ruled on 2026-11-22 (#268) that they are excluded now and
  supported after #96's flow parts, so that the flow checks across loop
  exits are written once. The parser reads each as a call of a callee of
  its name, which no function or struct of a program has. As names, both are keywords: a
  variable, a parameter, a function or a field named `break` or
  `continue` is a syntax error, as the compiler fails to parse it
  ([conformance.md](conformance.md#rejections-made-while-parsing)). A
  method's name in a struct and the name after `.` may be either word, or
  any other keyword, as in the compiler (#278). Supporting them is #276.

Constructs that the checker still rejects with a class where the compiler
accepts them, and that no ruling puts outside the subset, are not
excluded: they wait for the human's ruling. The type `String` and the
standard-library calls that the model lacks are #243; the others are
#183, #198 and #222.

The suite cannot compare exit 3, so it holds no program with one of
these constructs. The human ruled on 2026-11-21 (#180) that the four suite
programs that held one leave the suite, and `#guard` tests in
`MojoGrimoireTest.Parse.Subset` pin their exit 3, line and message:
`rejected/range_string_argument` and `rejected/range_of_range`, which the
compiler rejects as `noMatchingInit`, and
`rejected/no_matching_method_index_string` and
`rejected/no_matching_method_pop_string`, as `noMatchingMethod`. #238 and
#239 list them, so that covering the construct brings them back.

Every exclusion is temporary. The goal is a model of the whole of Mojo, so
each excluded construct is future work, not a boundary of the design. Only
the human adds a construct to the excluded list. An agent never excludes a
construct to make a disagreement with the compiler go away, because the
suite cannot compare exit 3 and would hide it.
