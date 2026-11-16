import MojoGrimoire.Core.Program

/-!
The ways the static checker rejects a program. Each rejection names a class
of error and the declaration it was found in. The classes are what the
conformance suite compares with the compiler's diagnostics; the compiler's
wording is not compared.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The classes of error that the checker reports. `unknownAttribute` is a
field or a method that the type named `ty` does not have: the compiler
reports both alike, so the model does not tell them apart. For the same
reason, `noMatchingInit` is any initialization of the type `ty` whose
arguments fit no initializer: a construction `S(…)` with a wrong number of
arguments or a wrong one, a literal whose elements do not fit the list or
array it initializes, or that initializes another type, and
`List[u](e₁, …, eₙ)`. -/
inductive CheckError where
  | unknownVariable (name : Name)
  | unknownFunction (name : Name)
  | unknownStruct (name : Name)
  | unknownAttribute (ty attr : Name)
  | duplicate (name : Name)
  | invalidType (ty : Ty)
  | recursiveStruct (name : Name)
  | typeMismatch (expected actual : Ty)
  | notAList (ty : Ty)
  | negativeIndex (p : Place)
  | constantIndexOutOfBounds (p : Place)
  | notPrintable (ty : Ty)
  | stringOutsidePrint
  | arityMismatch (callee : Name) (expected actual : Nat)
  | noMatchingInit (ty : Ty)
  | invalidConvention (name : Name)
  | invalidSelf (name : Name)
  | noInitializer (struct : Name)
  | uninitializedUse (p : Place)
  | implicitCopy (ty : Ty)
  | notCopyable (ty : Ty)
  | transferFromBorrowed (p : Place)
  | transferFromElement (p : Place)
  | immutablePlace (p : Place)
  | notAPlace (callee : Name)
  | argumentExclusivity (p : Place)
  | uninitializedAtExit (name : Name)
  | partiallyDestroyed (name : Name)
  | missingReturn (name : Name)
  | invalidReturn (name : Name)
  | noMain
  | notAReference
  | invalidOrigin (name : Name)
  | escapingReference (name : Name)
  | invalidatedReference (p : Place)
  deriving BEq

/-- A rejection: the error, and the declaration it was found in, a function,
a method written `S.m`, or `S` for a struct's own declaration; empty for an
error about the whole program. -/
structure Rejection where
  decl : Name
  error : CheckError
  deriving BEq

end MojoGrimoire.Check
