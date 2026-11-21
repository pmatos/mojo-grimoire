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
array it initializes, or that initializes another type,
`List[u](e₁, …, eₙ)`, and a call of the built-in `len` that no overload
fits, of its one argument's type, or of `unknown` for another number of
arguments (#190). `transferFromElement` is a transfer out of an element
of a list or an array, or through a reference bound with `ref`: the compiler
reports both alike, as an expression with no origin of its own.
`noMatchingMethod` is a call of the method or operator `method` that has
several overloads, none of which its arguments fit, a wrong number of them
included: the compiler reports only that none fits (#88).
`missingMethod` is a method that an operator or a call needs and the type
`ty` lacks: an operator's method on its operand, or `__call__` on a
variable that is called (#176). `violatedConstraint` is a call of the
method `method` of the type `ty` whose constraint on `ty`'s parameters
fails: two arrays compared whose element type does not conform to the
trait that the operator needs (#166). `uncopyableField` is the field `field`, of
type `ty`, of a struct `struct` that declares `Copyable` but whose `ty`
cannot be copied, or declares `ImplicitlyCopyable` but whose `ty` cannot
be copied implicitly: the compiler cannot synthesize the struct's copy
initializer from its fields (#164). `valueAsType` is a type written as
the name `name` that a variable or a parameter in scope hides
(`MojoGrimoire.Core.hiddenTy`): the compiler reports the variable's value
where it expects a type (#193). -/
inductive CheckError where
  | unknownVariable (name : Name)
  | unknownFunction (name : Name)
  | unknownStruct (name : Name)
  | unknownAttribute (ty attr : Name)
  | duplicate (name : Name)
  | invalidType (ty : Ty)
  | valueAsType (name : Name)
  | recursiveStruct (name : Name)
  | uncopyableField (struct field : Name) (ty : Ty)
  | typeMismatch (expected actual : Ty)
  | notAList (ty : Ty)
  | negativeIndex (p : Place)
  | constantIndexOutOfBounds (p : Place)
  | notPrintable (ty : Ty)
  | stringOutsidePrint
  | arityMismatch (callee : Name) (expected actual : Nat)
  | noMatchingInit (ty : Ty)
  | noMatchingMethod (method : Name)
  | missingMethod (ty : Ty) (method : Name)
  | violatedConstraint (ty : Ty) (method : Name)
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

/-- The error of a parameter, a result or a variable declared with the
type `t`, which no value may have: `valueAsType` when a variable hides a
name in it, `invalidType` otherwise. -/
def typeError (t : Ty) : CheckError :=
  match t.hidden with
  | some x => .valueAsType x
  | none => .invalidType t

/-- A rejection: the error, and the declaration it was found in, a function,
a method written `S.m`, or `S` for a struct's own declaration; empty for an
error about the whole program. -/
structure Rejection where
  decl : Name
  error : CheckError
  deriving BEq

end MojoGrimoire.Check
