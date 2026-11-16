import VersoManual
import MojoGrimoire.Check.Env
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Env`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The program's tables: readable blocks" =>

:::moduleDocs (fingerprint := "1588124030301744694")
:::

:::readable MojoGrimoire.Check.findStruct MojoGrimoire.Check.findFun MojoGrimoire.Check.fieldTy MojoGrimoire.Check.findMethod MojoGrimoire.Check.fieldOf MojoGrimoire.Check.fieldNames (fingerprint := "12927198337935588870")
*Definition: lookups.* The checker finds a struct or a function of the
program by its name, the first one declared with that name, and a field or
method of a struct by its name. `fieldOf` gives the type of the field
$`f` of a value of type $`t`, and rejects $`t` when it is not a struct,
or when the struct is unknown or has no field $`f`. `fieldNames` gives
the names of the fields of a struct type, and none for any other type.
:::

:::readable MojoGrimoire.Check.copyingOf (fingerprint := "4318683737232947193")
*Definition: how a type is copied.* $`\mathsf{Int}` and
$`\mathsf{Bool}` are implicitly copyable, as in Mojo; a struct is copied as
it declares; a list or an array is copied only explicitly, with
`.copy()`, and only when its elements can be copied; string literals and $`\mathsf{None}` are
never copied.
:::

:::readable MojoGrimoire.Check.hasDeinit (fingerprint := "18219250075115973939")
*Definition: types with a destructor.* A type has a destructor of its own
when it is a struct that declares `__deinit__`.
:::

:::readable MojoGrimoire.Check.validTy (fingerprint := "2209953286527928859")
*Definition: declarable types.* A variable, parameter or field may have the
type $`\mathsf{Int}`, $`\mathsf{Bool}`, a struct of the program, or a
list or an array of values of such a type, and no other.
:::

:::readable MojoGrimoire.Check.contains (fingerprint := "16104821665075561169")
*Definition: containment.* A type $`t` contains the struct $`S` when it is
$`S`, a struct with a field whose type contains $`S`, or an array of a
type that contains $`S`: an array holds its elements inline, while a list
holds them apart, so a list of $`S` does not count. The search is
bounded by the number of structs of the program, since a longer chain of
fields repeats a struct. A struct whose field contains the struct itself
would be infinite, and is rejected.
:::
