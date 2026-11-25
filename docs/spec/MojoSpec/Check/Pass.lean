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

:::moduleDocs (fingerprint := "13053174260536702238")
:::

:::readable MojoGrimoire.Check.Below (fingerprint := "14513104375151688470")
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

:::readable MojoGrimoire.Check.lateErrors (fingerprint := "5024084900289480669")
*Definition: recording a later error.* In an argument of `range`, an error
of a later pass than typing, a use of an uninitialized or invalidated
value or a constant index out of range (`CheckError.late`), or a nested
literal's failed SIMD constraint, `noMatchingInit` of $`\mathsf{Int}`, is recorded
instead of thrown, so that the errors of all the arguments can be reported
in the compiler's order of passes (#121).
:::

:::readable MojoGrimoire.Check.Phase.rank MojoGrimoire.Check.CheckError.phase (fingerprint := "11439117272577371433")
*Definition: the phase of a later error.* The phases come in the order
type, flow, instantiation. A constant index's error is the
instantiation phase's, and a use of an uninitialized or invalidated
value the flow phase's.
:::

:::readable MojoGrimoire.Check.calleeBody MojoGrimoire.Check.instCall MojoGrimoire.Check.dropCall (fingerprint := "15877494409387414648")
*Definition: calls that instantiate.* A call of $`f` instantiates the
function $`f`, the `__init__` that the struct $`f` declares, or the method
that $`f` names. Destroying a value of a struct that declares
`__deinit__` calls it. The instantiation phase records each call
(`InstEvent`), and the order of the bodies follows them
(`MojoGrimoire.Check.checkInst`).
:::

:::readable MojoGrimoire.Check.refResult (fingerprint := "5596166513625506680")
*Definition: the result of a call.* A call or a method call that returns a
reference, used as a value, gives the value it points to, which must be
implicitly copyable, unless it is used as a reference. An argument
through the element of an $`\mathsf{Int}` passed to a parameter that the
origin names is $`\mathsf{notAList}`, as before #127: the element has no
memory origin, and the model passes the $`\mathsf{Int}` itself (#222).
:::

:::readable MojoGrimoire.Check.misfitFirst (fingerprint := "8222999464233596162")
*Rule: a misfit before a copy.* Where a value of a type is expected, as
an argument, an initial value or a returned value, a call that returns a
reference to a value that is not implicitly copyable reports a type that
does not fit before its copy: the compiler reports that copy only once the
type fits. The call is then checked again by reference, from the state
before it, for its type.
:::

:::readable MojoGrimoire.Check.rejectIntElem MojoGrimoire.Check.rejectIntElemArg MojoGrimoire.Check.plainIndices (fingerprint := "11525180496420865244")
*Rule: the element of an $`\mathsf{Int}` where the model cannot follow
the compiler.* A place through the element of an $`\mathsf{Int}` is
rejected there as $`\mathsf{notAList}`, as before #127, once its indices
are checked, a constant index out of the $`\mathsf{Int}`'s range being
$`\mathsf{notAList}` too. So it is when passed to a `mut` or `ref`
parameter: the compiler passes a temporary, written back after a `mut`
call, which the model does not model yet (#222). Its indices are checked
with every check on; an index's error of a later pass is left to the
phase that reports it. An index is plain when
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

:::readable MojoGrimoire.Check.typeFirst (fingerprint := "266373056232888975")
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
