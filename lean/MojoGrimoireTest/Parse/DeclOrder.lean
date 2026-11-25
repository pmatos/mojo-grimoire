import MojoGrimoire.Parse.Subset

/-!
Tests of the order of declarations that the parser records (#96): the
functions and structs of a program, and the members of each struct, as
they stand in the source.
-/

namespace MojoGrimoireTest.Parse

open MojoGrimoire.Core MojoGrimoire.Parse

/-- The order of the declarations of the program whose lines are `ls`, as
parsed and inferred, or none for a syntax error. -/
private def orderOf (ls : List String) : Option (List Decl) :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some prog.order
  | .error _ => none

private def mixed : List String := [
  "def f():",
  "    pass",
  "",
  "@fieldwise_init",
  "struct S(Copyable):",
  "    var x: Int",
  "    def m(self) -> Int:",
  "        return self.x",
  "    fn __deinit__(deinit self):",
  "        pass",
  "    var y: Int",
  "    def n(self):",
  "        pass",
  "",
  "struct T:",
  "    var z: Int",
  "    fn __init__(out self):",
  "        self.z = 0",
  "",
  "def main():",
  "    f()"]

-- Functions and structs interleave in the order of the file, and each
-- struct's members keep theirs.
#guard orderOf mixed == some [.func 0,
  .struct 0 [.field 0, .method 0, .deinit, .field 1, .method 1],
  .struct 1 [.field 0, .init], .func 1]

-- A second `__init__` replaces the first, and stands where it is written.
#guard orderOf [
  "struct U:",
  "    var a: Int",
  "    fn __init__(out self):",
  "        self.a = 0",
  "    def m(self):",
  "        pass",
  "    fn __init__(out self, a: Int):",
  "        self.a = a",
  "",
  "def main():",
  "    pass"] == some [.struct 0 [.field 0, .method 0, .init], .func 0]

-- `parseSubset` keeps the order too.
#guard (match parseSubset ("\n".intercalate mixed) with
  | .ok prog => prog.order.length == 4
  | .error _ => false)

-- A program built by hand records no order.
#guard ({ structs := [], funs := [] } : Program).order == []

end MojoGrimoireTest.Parse
