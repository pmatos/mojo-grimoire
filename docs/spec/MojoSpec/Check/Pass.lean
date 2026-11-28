import VersoManual
import MojoGrimoire.Check.Pass
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Pass`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Checking helpers: readable blocks" =>

:::moduleDocs (fingerprint := "3685599112545028131")
:::

:::readable MojoGrimoire.Check.Below (fingerprint := "14111869609950496686")
*Definition: a check below a bound.* A check of the values of a type no
larger than a list of expressions $`r`, each given with a proof of that
bound. The modules outside the mutual block of the checker of expressions
are given so the checks of the expressions and places inside the
expressions they check, so that the checker's recursion still ends (#96).
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.requireMutable (fingerprint := "3665794792439843375")
*Definition: requiring a place that may change.* A place that is assigned
to or passed `mut` must be one the function may change, and not reached
through $`q\,\hat{}`: the compiler borrows $`q` there as a value that
cannot be changed. Passed `mut` to an initializer, such a place is
reported as the initializer's misfit.
:::

:::readable MojoGrimoire.Check.lateErrors (fingerprint := "6813149190120378136")
*Definition: recording a later error.* In an argument of `range`, an error
of the instantiation phase, a constant index out of range
(`CheckError.phase`), or a nested literal's failed SIMD constraint,
`noMatchingInit` of $`\mathsf{Int}`, is recorded instead of thrown, so
that `rangeList` can report the errors of all the arguments in its order
(#121).
:::

:::readable MojoGrimoire.Check.Phase.rank MojoGrimoire.Check.CheckError.phase (fingerprint := "13428765439684746331")
*Definition: the phase of a later error.* The phases come in the order
type, flow, instantiation. A constant index's error is the
instantiation phase's, and a use of an uninitialized or invalidated
value the flow phase's.
:::

:::readable MojoGrimoire.Check.calleeBody MojoGrimoire.Check.instCall MojoGrimoire.Check.destructorOf MojoGrimoire.Check.dropCall (fingerprint := "16717970515991501688")
*Definition: calls that instantiate.* A call of $`f` instantiates the
function $`f`, the `__init__` that the struct $`f` declares, or the method
that $`f` names. Destroying a value of a struct calls the `__deinit__`
that it declares, or else the destructor that the compiler synthesizes,
`__del__`; destroying a list or an array calls its elements'. The instantiation phase records each call
(`InstEvent`), and the order of the bodies follows them
(`MojoGrimoire.Check.checkInst`).
:::

:::readable MojoGrimoire.Check.refResult (fingerprint := "3162427232764769313")
*Definition: the result of a call.* A call or a method call that returns a
reference, used as a value, gives the value it points to, which must be
implicitly copyable, unless it is used as a reference, while copies are
checked (`copyChecks`). An argument
through the element of an $`\mathsf{Int}` passed to a parameter that the
origin names is $`\mathsf{notAList}`, as before #127: the element has no
memory origin, and the model passes the $`\mathsf{Int}` itself (#222).
:::

:::readable MojoGrimoire.Check.misfitFirst (fingerprint := "8501705712298747820")
*Rule: a misfit before a copy.* Where a value of a type is expected, as
an argument, an initial value or a returned value, a call that returns a
reference to a value that is not implicitly copyable reports a type that
does not fit before its copy: the compiler reports that copy only once the
type fits. The call is then checked again by reference, from the state
before it, for its type. Any other value whose check reports an implicit
copy, a place or a literal's element, is checked again without the checks
of copies (`copyLast`, #96 part 11), so that its misfit comes first, and
the copy only when it fits.
:::

:::readable MojoGrimoire.Check.rejectIntElem MojoGrimoire.Check.rejectIntElemArg MojoGrimoire.Check.plainIndices (fingerprint := "3852440861333310310")
*Rule: the element of an $`\mathsf{Int}` where the model cannot follow
the compiler.* A place through the element of an $`\mathsf{Int}` is
rejected there as $`\mathsf{notAList}`, as before #127, once its indices
are checked, a constant index out of the $`\mathsf{Int}`'s range being
$`\mathsf{notAList}` too. So it is when passed to a `mut` or `ref`
parameter: the compiler passes a temporary, written back after a `mut`
call, which the model does not model yet (#222). Its indices are checked
with every check on; an index's error of a later pass is left to the
phase that reports it, unless an outer check has every check on. An index is plain when
it is an integer constant or a variable, which evaluating twice cannot
change.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "2500036056060291548")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`. A misfit is
reported as the call's fit says.
:::

:::readable MojoGrimoire.Check.typeFirst (fingerprint := "3074714042600590340")
*Rule: what a call types first.* Before a call reads its first argument,
a place, the receiver of an in-place method that inference made is typed,
its indices included. A subscript of a struct, which inference makes a
call of its getter, has its index typed against the getter's parameter,
as any subscript's index is, so that an unknown name or a type that does
not fit in it comes before a use of a moved or uninitialized receiver
(#191). So does an implicit copy in the index, or of a place it passes to
a `var` parameter, which the compiler reports after the types but before
such a use. Errors of a later pass do not count there, nor an index with no type there, such as a literal of
$`\mathsf{Int}`s of the wrong length, which the call reports later; the
checker's state is left as it was.
:::
