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

:::moduleDocs (fingerprint := "2868174857376798766")
:::

:::readable MojoGrimoire.Check.findStruct MojoGrimoire.Check.findFun MojoGrimoire.Check.fieldTy MojoGrimoire.Check.findMethod MojoGrimoire.Check.fieldOf MojoGrimoire.Check.fieldNames (fingerprint := "12927198337935588870")
*Definition: lookups.* The checker finds a struct or a function of the
program by its name, the first one declared with that name, and a field or
method of a struct by its name. `fieldOf` gives the type of the field
$`f` of a value of type $`t`, and rejects $`t` when it is not a struct,
or when the struct is unknown or has no field $`f`. `fieldNames` gives
the names of the fields of a struct type, and none for any other type.
:::

:::readable MojoGrimoire.Check.copyingOf (fingerprint := "11280189753430556999")
*Definition: how a type is copied.* $`\mathsf{Int}` and
$`\mathsf{Bool}` are implicitly copyable, as in Mojo; a struct is copied as
it declares; string literals and $`\mathsf{None}` are never copied.
:::

:::readable MojoGrimoire.Check.hasDeinit (fingerprint := "18219250075115973939")
*Definition: types with a destructor.* A type has a destructor of its own
when it is a struct that declares `__deinit__`.
:::

:::readable MojoGrimoire.Check.validTy (fingerprint := "13108216207009917757")
*Definition: declarable types.* A variable, parameter or field may have the
type $`\mathsf{Int}`, $`\mathsf{Bool}` or a struct of the program, and
no other.
:::

:::readable MojoGrimoire.Check.contains (fingerprint := "16104821665075561169")
*Definition: containment.* A type $`t` contains the struct $`S` when it is
$`S`, or is a struct with a field whose type contains $`S`. The search is
bounded by the number of structs of the program, since a longer chain of
fields repeats a struct. A struct whose field contains the struct itself
would be infinite, and is rejected.
:::
