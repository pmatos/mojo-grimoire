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

:::moduleDocs (fingerprint := "12609668123975707695")
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

:::readable MojoGrimoire.Check.lateErrors (fingerprint := "2068864695038659814")
*Definition: recording a later error.* In an argument of `range`, an error
of a later pass than typing, a use of an uninitialized or invalidated
value or a constant index out of range (`CheckError.late`), is recorded
instead of thrown, so that the errors of all the arguments can be reported
in the compiler's order of passes (#121).
:::

:::readable MojoGrimoire.Check.refResult (fingerprint := "4791063665474045528")
*Definition: the result of a call.* A call or a method call that returns a
reference, used as a value, gives the value it points to, which must be
implicitly copyable, unless it is used as a reference.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "2500036056060291548")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`. A misfit is
reported as the call's fit says.
:::
