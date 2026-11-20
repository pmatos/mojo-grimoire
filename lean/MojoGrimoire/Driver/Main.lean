import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
The command-line driver: `mojo-grimoire FILE.mojo [--fuel N]` parses,
checks, elaborates and runs a `.mojo` file, as the compiler's `mojo run`
does.

The lines the program prints go to standard output. How the run ends is
the exit code, with a line on standard error that names the class of the
error, which the conformance suite compares with the compiler's:

- 0: the program finished;
- 1: the checker rejected it, `rejected: CLASS in DECL`;
- 2: it failed at run time, `run-time error: NAME`;
- 3: it has a syntax error, `syntax error: line N: MESSAGE`;
- 4: the command line or the file could not be used.

The executable's entry point, the top-level `main`, is the module
`MojoGrimoireCli`, which only calls `MojoGrimoire.Driver.main`. It is
outside this library, whose modules the spec document imports, since the
spec is an executable with a `main` of its own.
-/

namespace MojoGrimoire.Driver

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Interp

/-- The name of a class of error, as the driver reports it. -/
def CheckError.className : CheckError → String
  | .unknownVariable .. => "unknownVariable"
  | .unknownFunction .. => "unknownFunction"
  | .unknownStruct .. => "unknownStruct"
  | .unknownAttribute .. => "unknownAttribute"
  | .duplicate .. => "duplicate"
  | .invalidType .. => "invalidType"
  | .recursiveStruct .. => "recursiveStruct"
  | .typeMismatch .. => "typeMismatch"
  | .notAList .. => "notAList"
  | .negativeIndex .. => "negativeIndex"
  | .constantIndexOutOfBounds .. => "constantIndexOutOfBounds"
  | .notPrintable .. => "notPrintable"
  | .stringOutsidePrint => "stringOutsidePrint"
  | .arityMismatch .. => "arityMismatch"
  | .noMatchingInit .. => "noMatchingInit"
  | .noMatchingMethod .. => "noMatchingMethod"
  | .missingMethod .. => "missingMethod"
  | .invalidConvention .. => "invalidConvention"
  | .invalidSelf .. => "invalidSelf"
  | .noInitializer .. => "noInitializer"
  | .uninitializedUse .. => "uninitializedUse"
  | .implicitCopy .. => "implicitCopy"
  | .notCopyable .. => "notCopyable"
  | .transferFromBorrowed .. => "transferFromBorrowed"
  | .transferFromElement .. => "transferFromElement"
  | .immutablePlace .. => "immutablePlace"
  | .notAPlace .. => "notAPlace"
  | .argumentExclusivity .. => "argumentExclusivity"
  | .uninitializedAtExit .. => "uninitializedAtExit"
  | .partiallyDestroyed .. => "partiallyDestroyed"
  | .missingReturn .. => "missingReturn"
  | .invalidReturn .. => "invalidReturn"
  | .noMain => "noMain"
  | .notAReference => "notAReference"
  | .invalidOrigin .. => "invalidOrigin"
  | .escapingReference .. => "escapingReference"
  | .invalidatedReference .. => "invalidatedReference"

/-- The name of a run-time error, as the driver reports it. -/
def RunError.name : RunError → String
  | .outOfFuel => "outOfFuel"
  | .indexOutOfBounds => "indexOutOfBounds"
  | .stuck what => s!"stuck ({what})"

/-- The fuel of a run unless the command line gives another. -/
def defaultFuel : Nat := 100000000

/-- The file and the fuel that the command-line arguments give. -/
def parseArgs : List String → Option (String × Nat)
  | [file] => some (file, defaultFuel)
  | [file, "--fuel", n] => n.toNat?.map (file, ·)
  | _ => none

/-- Runs the driver on the command-line arguments `args`, and gives the
exit code. -/
def main (args : List String) : IO UInt32 := do
  let some (file, fuel) := parseArgs args
    | IO.eprintln "usage: mojo-grimoire FILE.mojo [--fuel N]"; pure 4
  let source ← try IO.FS.readFile file catch e => do
    IO.eprintln s!"cannot read {file}: {e}"
    return 4
  match MojoGrimoire.Parse.parse source with
  | .error e =>
    IO.eprintln s!"syntax error: line {e.line}: {e.message}"
    pure 3
  | .ok prog =>
    match run prog fuel with
    | .rejected r =>
      IO.eprintln s!"rejected: {CheckError.className r.error} in {r.decl}"
      pure 1
    | .finished out =>
      out.forM IO.println
      pure 0
    | .failed e out =>
      out.forM IO.println
      IO.eprintln s!"run-time error: {RunError.name e}"
      pure 2

end MojoGrimoire.Driver
