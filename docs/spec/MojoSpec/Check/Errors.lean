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

:::moduleDocs (fingerprint := "12161194175526071246")
:::

:::readable MojoGrimoire.Check.CheckError (fingerprint := "16771763470733647822")
*Definition: the classes of error.* The checker rejects a program with one
of these classes, each with the names or types it concerns:

* names: an unknown variable, function or struct, a field or a method that
  a type does not have (`unknownAttribute`, one class, since the compiler
  reports both alike), and a name declared twice where it must be unique
  (`duplicate`);
* types: a type that may not be declared, such as that of string literals
  (`invalidType`), a struct that contains itself (`recursiveStruct`), a
  type other than the one expected (`typeMismatch`), an index into a
  value that is neither a list nor an array (`notAList`), an index that
  Mojo computes when it compiles the program and that is negative
  (`negativeIndex`) or, into an array, past its last element
  (`constantIndexOutOfBounds`), a value that
  `print` cannot print (`notPrintable`), a string literal outside
  `print` (`stringOutsidePrint`), a call with the wrong number of
  arguments (`arityMismatch`), and an initialization of a type whose
  arguments fit no initializer (`noMatchingInit`, one class however they
  misfit, since the compiler reports them alike): a construction with
  wrong arguments, a literal that does not fit the list or array it
  initializes, or that initializes another type, and `List[u](e1, …, en)`;
* declarations: a parameter of a convention its function may not have
  (`invalidConvention`), a method or initializer whose `self` is wrong
  (`invalidSelf`), a construction of a struct with no initializer
  (`noInitializer`), a `return` that does not fit the result type
  (`invalidReturn`), a function with a result that can end without
  returning (`missingReturn`), a program with no `main` (`noMain`), and
  an origin that names something other than a parameter passed as a
  location (`invalidOrigin`);
* ownership: a use of a part that is not initialized, such as a loop
  body that moves a value from before the loop (`uninitializedUse`), an implicit copy of a value that is not implicitly
  copyable (`implicitCopy`), `.copy()` of a value that is not copyable
  (`notCopyable`), a transfer out of a value the function does not own
  (`transferFromBorrowed`) or out of an element of a list or an array
  (`transferFromElement`), a change to a place the function may not
  change (`immutablePlace`), a `mut` argument that is not a place
  (`notAPlace`) or that aliases another argument, or a call that builds
  its result into an element of a list it changes
  (`argumentExclusivity`), a `mut` parameter or the `self` of `__init__`
  not wholly initialized when the function returns
  (`uninitializedAtExit`), and a struct that ends or is overwritten with
  a field moved out and not assigned again, or with a part moved out below
  a destructor of its own (`partiallyDestroyed`);
* references: a `ref` binding to something that is not a location
  (`notAReference`), a returned reference that may point outside the
  function's origin (`escapingReference`), and a use of a reference into
  an element of a list after the list changed (`invalidatedReference`).
:::

:::readable MojoGrimoire.Check.Rejection (fingerprint := "11806667538347354827")
*Definition: a rejection.* A rejection is a class of error and the
declaration it was found in: a function `f`, a method `S.m`, an
initializer `S.__init__`, a destructor `S.__deinit__`, a struct `S` for
its fields, or nothing for an error about the whole program.
:::
