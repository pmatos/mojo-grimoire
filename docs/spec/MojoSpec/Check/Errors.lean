import VersoManual
import MojoGrimoire.Check.Errors
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Errors`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Errors: readable blocks" =>

:::moduleDocs (fingerprint := "1398389244927822096")
:::

:::readable MojoGrimoire.Check.CheckError (fingerprint := "12810947781111785992")
*Definition: the classes of error.* The checker rejects a program with one
of these classes, each with the names or types it concerns:

* names: an unknown variable, function, struct, field or method, and a name
  declared twice where it must be unique (`duplicate`);
* types: a type that may not be declared, such as that of string literals
  (`invalidType`), a struct that contains itself (`recursiveStruct`), a
  type other than the one expected (`typeMismatch`), an index into a
  value that is not a list (`notAList`), a value that
  `print` cannot print (`notPrintable`), a string literal outside
  `print` (`stringOutsidePrint`), and a call with the wrong number of
  arguments (`arityMismatch`);
* declarations: a parameter of a convention its function may not have
  (`invalidConvention`), a method or initializer whose `self` is wrong
  (`invalidSelf`), a construction of a struct with no initializer
  (`noInitializer`), a `return` that does not fit the result type
  (`invalidReturn`), a function with a result that can end without
  returning (`missingReturn`), a program with no `main` (`noMain`), and
  an origin that names something other than a parameter passed as a
  location (`invalidOrigin`);
* ownership: a use of a part that is not initialized
  (`uninitializedUse`), an implicit copy of a value that is not implicitly
  copyable (`implicitCopy`), `.copy()` of a value that is not copyable
  (`notCopyable`), a transfer out of a value the function does not own
  (`transferFromBorrowed`) or out of an element of a list
  (`transferFromElement`), a change to a place the function may not
  change (`immutablePlace`), a `mut` argument that is not a place
  (`notAPlace`) or that aliases another argument
  (`argumentExclusivity`), a loop that moves a value from before it
  (`movedInLoop`), a `mut` parameter or the `self` of `__init__`
  not wholly initialized when the function returns
  (`uninitializedAtExit`), and a value with a destructor of its own that
  ends with a field moved out (`partiallyDestroyed`);
* references: a `ref` binding to something that is not a location
  (`notAReference`), and a returned reference that may point outside the
  function's origin (`escapingReference`).
:::

:::readable MojoGrimoire.Check.Rejection (fingerprint := "11806667538347354827")
*Definition: a rejection.* A rejection is a class of error and the
declaration it was found in: a function `f`, a method `S.m`, an
initializer `S.__init__`, a destructor `S.__deinit__`, a struct `S` for
its fields, or nothing for an error about the whole program.
:::
