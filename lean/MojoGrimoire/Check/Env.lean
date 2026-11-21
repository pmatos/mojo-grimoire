import MojoGrimoire.Check.Errors

/-!
What the checker looks up in a program: its structs and functions, the
fields and methods of a struct, the signature of each call and method call,
and how the values of a type are copied and destroyed. Inference, the
checker and elaboration all read the signatures of calls here.
-/

namespace MojoGrimoire.Check

open MojoGrimoire.Core

/-- The struct named `s`, if the program declares one. -/
def findStruct (prog : Program) (s : Name) : Option StructDecl :=
  prog.structs.find? (·.name == s)

/-- The function named `f`, if the program declares one. -/
def findFun (prog : Program) (f : Name) : Option FunDecl :=
  prog.funs.find? (·.name == f)

/-- The type of the field `f` of the struct `sd`, if it has one. -/
def fieldTy (sd : StructDecl) (f : Name) : Option Ty :=
  (sd.fields.find? (·.1 == f)).map (·.2)

/-- The method named `m` of the struct `sd`, if it has one. -/
def findMethod (sd : StructDecl) (m : Name) : Option FunDecl :=
  sd.methods.find? (·.name == m)

/-- What a call needs to know of what it calls, Mojo's signature: the
parameter that takes the receiver of a method, `none` for a function or a
construction; the other parameters; the result; and, for a result that is a
reference, the parameters it points into, Mojo's `ref [a, b]`. `generic`
holds when the result has a generic type, an element of a list: Mojo builds
it in place whatever type it stands for. -/
structure Signature where
  self : Option Param
  params : List Param
  result : Ty
  origin : Option (List Name)
  generic : Bool

/-- The parameters of a signature, its receiver's first. -/
def Signature.allParams (sig : Signature) : List Param :=
  sig.self.toList ++ sig.params

/-- The signature of the function `fd`, or of the method `fd` with its
first parameter as the receiver. -/
def funSig (fd : FunDecl) (method : Bool) : Signature :=
  if method then ⟨fd.params.head?, fd.params.tail, fd.result, fd.origin, false⟩
  else ⟨none, fd.params, fd.result, fd.origin, false⟩

/-- The signature of the method `m` of a list of elements of type `t` when
it is called with `n` arguments. Each method takes its `self` `mut`.
`append` takes an element and gives nothing. `pop` gives an element, and
has two overloads: `pop()` takes nothing, and `pop(i)` takes an `Int`,
which the overload for any number of arguments other than zero also
takes. -/
def listMethod (t : Ty) (m : Name) (n : Nat) : Option Signature :=
  let self : Param := ⟨.mutable, "self", .list t⟩
  match m, n with
  | "append", _ => some ⟨some self, [⟨.owned, "value", t⟩], .noneType, none, false⟩
  | "pop", 0 => some ⟨some self, [], t, none, true⟩
  | "pop", _ => some ⟨some self, [⟨.read, "i", .int⟩], t, none, true⟩
  | _, _ => none

/-- The name of the type `t`, as Mojo writes it without its parameters. -/
def typeName : Ty → Name
  | .int => "Int"
  | .bool => "Bool"
  | .str => "StringLiteral"
  | .noneType => "NoneType"
  | .unknown => "unknown"
  | .struct s => s
  | .list _ => "List"
  | .array .. => "Array"

/-- The method `fd` called as a function, its receiver first, or, when
it is `reflected`, with its first two parameters swapped
(`MojoGrimoire.Core.methodCallee`). -/
def asCallee (fd : FunDecl) (reflected : Bool) : FunDecl :=
  match reflected, fd.params with
  | true, a :: b :: ps => { fd with params := b :: a :: ps }
  | _, _ => fd

/-- The function that a call of `f` runs: the function `f`, or the
method that the callee `f` names (`MojoGrimoire.Core.methodCallee`). -/
def findCallee (prog : Program) (f : Name) : Option FunDecl :=
  match findFun prog f, calleeMethod f with
  | some fd, _ => some fd
  | none, some (s, m, reflected) =>
    ((findStruct prog s).bind (findMethod · m)).map (asCallee · reflected)
  | none, none => none

/-- The signature of a call of `f`: the construction of the struct `f`,
which takes the parameters of its `__init__` after `self`, or each field
`var` when it is `@fieldwise_init`; otherwise the function `f`, or the
method that the callee `f` names, which takes its receiver as its first
argument. A struct wins over a function of the same name. `len` has none,
since it takes a list or an array of any type, or an `Int`. A method that the callee
names and its struct lacks is `missingMethod`: inference makes such a
call only of an in-place operator, `p += e`, whose struct lacks its
method (#191). -/
def callSig (prog : Program) (f : Name) : Except CheckError Signature :=
  match findStruct prog f, findCallee prog f with
  | some sd, _ => match sd.init with
    | some fd => pure ⟨none, fd.params.tail, .struct f, none, false⟩
    | none =>
      if sd.fieldwiseInit then
        pure ⟨none, sd.fields.map fun (x, t) => ⟨.owned, x, t⟩, .struct f, none, false⟩
      else throw (.noInitializer f)
  | none, some fd => pure (funSig fd false)
  | none, none => match calleeMethod f with
    | some (s, m, _) => throw (.missingMethod (.struct s) m)
    | none => throw (.unknownFunction f)

/-- The signature of the method `m` on a value of type `t`, called with `n`
arguments: one of a list's methods, or a method of a struct, whose first
parameter takes the receiver. An array has no methods, and the other types
none either: a method that the type lacks is an unknown attribute, named
with the type's name. -/
def methodSig (prog : Program) (t : Ty) (m : Name) (n : Nat) : Except CheckError Signature :=
  match t with
  | .list u => match listMethod u m n with
    | some sig => pure sig
    | none => throw (.unknownAttribute (typeName t) m)
  | .struct s => do
    let some sd := findStruct prog s | throw (.unknownStruct s)
    let some fd := findMethod sd m | throw (.unknownAttribute s m)
    if fd.params.isEmpty then throw (.invalidSelf m)
    pure (funSig fd true)
  | t => throw (.unknownAttribute (typeName t) m)

/-- Whether a call of `f` is one of the standard library's `range`: `f` is
`range`, and the program declares no struct and no function of that name
(#121). The checker also needs that no variable in scope has that name. -/
def builtinRange (prog : Program) (f : Name) : Bool :=
  f == "range" && (findStruct prog f).isNone && (findFun prog f).isNone

/-- The parameters of the standard library's `range` called with `n`
arguments, each an `Int` taken `read`: `end`; `start` and `end`; or
`start`, `end` and `step`. With no argument it has one, and with more than
three it has three; the checker rejects a wrong number of arguments. -/
def rangeParams (n : Nat) : List Param :=
  (match n with
    | 0 | 1 => ["end"]
    | 2 => ["start", "end"]
    | _ => ["start", "end", "step"]).map (⟨.read, ·, .int⟩)

/-- How the values of the type `t` can be copied. `Int`, `Bool` and `None`
are implicitly copyable, as in Mojo; a list or an array only explicitly,
with `.copy()`, and only when its elements can be copied; string literals
are never copied. -/
def copyingOf (prog : Program) : Ty → Copying
  | .int | .bool | .noneType => .implicit
  | .struct s => (findStruct prog s).elim .none (·.copying)
  | .list t | .array t _ => if copyingOf prog t == .none then .none else .explicit
  | .str | .unknown => .none

/-- The type of the field `f` of a value of type `t`. Only a struct has
fields; on any other type the field is an unknown attribute, named with
the type's name. -/
def fieldOf (prog : Program) (t : Ty) (f : Name) : Except CheckError Ty :=
  match t with
  | .struct s => do
    let some sd := findStruct prog s | throw (.unknownStruct s)
    let some ft := fieldTy sd f | throw (.unknownAttribute s f)
    pure ft
  | t => throw (.unknownAttribute (typeName t) f)

/-- The names of the fields of a value of type `t`: none unless `t` is a
struct. -/
def fieldNames (prog : Program) : Ty → List Name
  | .struct s => (findStruct prog s).elim [] (·.fields.map (·.1))
  | _ => []

/-- Whether a parameter or a field may be declared with the type `t`:
`Int`, `Bool`, a struct of the program, or a list or an array of such
values. -/
def validTy (prog : Program) : Ty → Bool
  | .int | .bool => true
  | .struct s => (findStruct prog s).isSome
  | .list t | .array t _ => validTy prog t
  | .str | .noneType | .unknown => false

/-- The type of what a value of type `t` holds through its lists and arrays:
the element type, through any number of them, or `t` itself. -/
def elemBase : Ty → Ty
  | .list t | .array t _ => elemBase t
  | t => t

/-- Whether a variable may be declared with the type `t`, which is also
the type of a literal's elements: as a parameter may (`validTy`), or
`None`, the type of a call that returns nothing, or a list or an array of
such values (#131). A type that inference cannot find is `unknown`, which
none may have. -/
def declarableTy (prog : Program) (t : Ty) : Bool :=
  elemBase t == .noneType || validTy prog t

/-- Whether a field of type `t` holds the struct it reaches through a list:
some list wraps it, under any number of arrays and lists. -/
def throughList : Ty → Bool
  | .list _ => true
  | .array t _ => throughList t
  | _ => false

/-- The structs that the fields of the struct `u` lead to, each the struct
of a field's element type, through the fields of a type `t` for which
`edge t` holds. -/
def successors (prog : Program) (edge : Ty → Bool) (u : Name) : List Name :=
  (findStruct prog u).elim [] fun sd => sd.fields.filterMap fun (_, t) =>
    match elemBase t with
    | .struct v => if edge t then some v else none
    | _ => none

/-- The structs reached from `seen` through the fields for which `edge`
holds, in at most `fuel` more steps: each step adds the successors of
`frontier`, the structs that the last step added, not seen yet. The search
ends when a step adds nothing. It gives `none` when the fuel runs out
first, so that a caller cannot mistake a search cut short for a complete
one. -/
def reach (prog : Program) (edge : Ty → Bool) : Nat → List Name → List Name → Option (List Name)
  | _, seen, [] => some seen
  | 0, _, _ => none
  | fuel + 1, seen, frontier =>
    let next := (frontier.flatMap (successors prog edge)).eraseDups.filter (!seen.contains ·)
    reach prog edge fuel (seen ++ next) next

/-- Whether the struct `s` lies on a cycle of fields that the fixed compiler
rejects, through a field of type `t`. A field leads to the struct of its
element type, and through a list when some list wraps it. A cycle with no
field through a list is rejected: a struct that holds itself directly, or
through arrays, has no finite layout. A cycle with a field through a list
is accepted, whatever its other fields, since the list keeps it finite;
the compiler rejects some of these, a compiler bug (D-0006). So the field
is rejected when it leads back to `s` along fields none of which is
through a list. Every cycle of direct fields is one of them, which keeps
finite each walk over the direct fields of structs, such as the blank of
a struct in the interpreter.

Each step of the search adds a struct of the program not seen yet, except
perhaps the last, which can add only names that the program does not
declare, which lead nowhere. So as many steps as the program has structs,
and one more, end it. A search that runs out of fuel rejects the field: it
never accepts a field it has not finished searching. -/
def rejectedCycle (prog : Program) (s : Name) (t : Ty) : Bool :=
  match elemBase t with
  | .struct v =>
    !throughList t &&
      (reach prog (!throughList ·) (prog.structs.length + 1) [v] [v]).all (·.contains s)
  | _ => false

/-- Whether a place passed to the parameter `prm` is passed by value: to a
`var` parameter, or an `Int` or a `Bool` to a `read` one, which Mojo copies.
Any other place is passed by reference. -/
def passedByValue (prm : Param) : Bool :=
  prm.conv == .owned || (prm.conv == .read && prm.ty.byValue)

/-- The place that a method call consumes when its receiver `p` is `q^`
and its `self` has the convention `c`: `q`, when `self` is `var`. Any other
receiver is passed as its convention says. -/
def consumedReceiver (c : Conv) : Place → Option Place
  | .transferred q => if c == .owned then some q else none
  | _ => none

end MojoGrimoire.Check
