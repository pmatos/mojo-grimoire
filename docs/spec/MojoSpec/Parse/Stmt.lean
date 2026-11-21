import VersoManual
import MojoGrimoire.Parse.Stmt
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Stmt`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Statements and declarations: readable blocks" =>

:::moduleDocs (fingerprint := "5291466686812682013")
:::

:::readable MojoGrimoire.Parse.augOps MojoGrimoire.Parse.augCallee MojoGrimoire.Parse.exprStmt (fingerprint := "14674107341489909627")
*Definition: sugar.* `p += e`, `p -= e` and `p *= e` are read as calls of
the callees `+=`, `-=` and `*=` with $`p` and $`e`, which no name of a
program is: inference replaces each with a call of the in-place method of
$`p`'s struct, or with `p = p + e`, `p = p - e` or `p = p * e` (#191). A
call of `print` on a line of its own is the $`\mathsf{print}` statement;
any other expression there is evaluated and its value discarded.
:::

:::readable MojoGrimoire.Parse.simpleStmt MojoGrimoire.Parse.exprTail MojoGrimoire.Parse.stmt MojoGrimoire.Parse.ifRest MojoGrimoire.Parse.block MojoGrimoire.Parse.stmts (fingerprint := "13287827973192454830")
*Definition: statements and blocks.*

$$`\begin{array}{lcl}
s & ::= & \mathsf{pass} \mid \mathsf{return}~e^? \\
 & \mid & \mathsf{var}~x~(:\mathit{type})^?~(= e)^? \mid \mathsf{ref}~x = e \\
 & \mid & p = e \mid p \mathrel{\mathit{op}{=}} e \mid e \\
 & \mid & \mathsf{if}~e~\mathit{block}~(\mathsf{elif}~e~\mathit{block})^*~(\mathsf{else}~\mathit{block})^? \\
 & \mid & \mathsf{while}~e~\mathit{block} \\
\mathit{block} & ::= & :~s \mid :~\mathsf{newline}~\mathsf{indent}~s^*~\mathsf{dedent}
\end{array}`

A block follows a `:`: one simple statement on the same line, or an
indented sequence of statements. `elif` is an `if` alone in the `else`
block. A string literal alone on a line, a docstring, is skipped. A
statement that starts with a postfix chain is an assignment when the chain
is a place followed by `=`, an augmented assignment, read as a call of
its callee (`augCallee`), when it is followed by an augmented operator,
and otherwise an expression whose first operand is that chain. The line
where each statement starts is recorded, an `elif`'s and a simple
statement's on the line of its block's `:` included, each statement
before the statements it holds.
:::

:::readable MojoGrimoire.Parse.conv MojoGrimoire.Parse.params MojoGrimoire.Parse.originNames MojoGrimoire.Parse.funDecl (fingerprint := "9777558907402154166")
*Definition: functions.*

$$`\begin{array}{lcl}
\mathit{fun} & ::= & (\mathsf{def} \mid \mathsf{fn})~f(\mathit{param}^*)~\mathsf{raises}^?~(\to \mathit{result})^?~\mathit{block} \\
\mathit{param} & ::= & \mathit{conv}^?~x~(:\mathit{type})^? \\
\mathit{conv} & ::= & \mathsf{imm} \mid \mathsf{mut} \mid \mathsf{var} \mid \mathsf{ref} \mid \mathsf{out} \mid \mathsf{deinit} \\
\mathit{result} & ::= & \mathit{type} \mid \mathsf{ref}~[x^+]~\mathit{type}
\end{array}`

`imm` is $`\mathsf{read}`, as is a parameter without a convention, and
`var` is $`\mathsf{owned}`. As in the compiler, `read` where a parameter
starts is a syntax error, "`read` was removed; use `imm`", `imm` must be
followed by the parameter's name, and `owned` is a name, not a convention:
`owned xs: T` lacks a type. A parameter must have a type, except `self` in
a method, whose type is its struct. A function without a result returns
$`\mathsf{None}`. `raises` is read and ignored: the subset raises no
errors. A result `ref [a, b] T` is a reference with the origins of the
parameters named; it names at least one. Each function is recorded with
the lines where the statements of its body start.
:::

:::readable MojoGrimoire.Parse.conformances MojoGrimoire.Parse.PState.deinitScope MojoGrimoire.Parse.members MojoGrimoire.Parse.structDecl (fingerprint := "11028547165630557114")
*Definition: structs.*

$$`\begin{array}{lcl}
\mathit{struct} & ::= & (@\mathsf{fieldwise\_init})^?~\mathsf{struct}~S~((\mathit{name}^+))^?:~\mathit{member}^* \\
\mathit{member} & ::= & \mathsf{var}~x:\mathit{type} \mid \mathit{fun} \mid \mathsf{pass} \mid \mathit{string}
\end{array}`

A struct's conformances say how its values are copied: `ImplicitlyCopyable`
implicitly, and so `TrivialRegisterPassable`, which implies it (#164);
`Copyable` explicitly; and otherwise not at all. Other conformances, such
as `Movable`, are read and ignored. Parentheses after
the name hold at least one conformance. The method `__init__` is the
initializer and the body of `__deinit__` is the destructor; every other
function is a method. The destructor is recorded with `self` alone as its
parameter (`deinitScope`), the scope in which the later passes check it.
:::

:::readable MojoGrimoire.Parse.decls MojoGrimoire.Parse.parseLines MojoGrimoire.Parse.parseRaw (fingerprint := "17787779178842599508")
*Definition: programs.* A program is a sequence of structs and functions,
in any order. The only decorator is `@fieldwise_init`. The parser is given
ten times the number of tokens, plus a hundred, as fuel, which is more than
any program spends. `parseLines` also gives every function, method,
initializer and destructor in the order of the file, with the lines of its
statements.
:::
