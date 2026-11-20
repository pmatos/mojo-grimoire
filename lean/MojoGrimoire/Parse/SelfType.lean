import MojoGrimoire.Parse.Stmt

/-!
`Self` in the methods of a struct.

Inside a struct's methods, its initializer and its destructor, the type
`Self` is the struct itself: in the types of parameters and results, of
the variables declared and of the literals `List[Self]()` and
`List[Self](…)`. The parser reads `Self` as the name of a struct, and this
pass replaces it, before inference. The ruling on #191 brings `Self` as a
parameter type into the model, which every operator method that takes
another value of its struct needs. `Self` as the type of a field, and
outside a struct, is left as it is: the checker rejects the struct that
no program declares.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- The type `t` with `Self` replaced by the struct `s`. -/
def Ty.withSelf (s : Name) : Ty → Ty
  | .struct "Self" => .struct s
  | .list t => .list (Ty.withSelf s t)
  | .array t n => .array (Ty.withSelf s t) n
  | t => t

mutual
/-- The place `p` with `Self` replaced by `s` in its indices. -/
def Place.withSelf (s : Name) : Place → Place
  | .var x => .var x
  | .field p f => .field (Place.withSelf s p) f
  | .index p i => .index (Place.withSelf s p) (Expr.withSelf s i)
  | .transferred p => .transferred (Place.withSelf s p)

/-- The expression `e` with `Self` replaced by `s` in its types. -/
def Expr.withSelf (s : Name) : Expr → Expr
  | .place p => .place (Place.withSelf s p)
  | .transfer p => .transfer (Place.withSelf s p)
  | .copy p => .copy (Place.withSelf s p)
  | .call f args => .call f (Expr.listWithSelf s args)
  | .method p m args => .method (Place.withSelf s p) m (Expr.listWithSelf s args)
  | .unary op a => .unary op (Expr.withSelf s a)
  | .binary op a b => .binary op (Expr.withSelf s a) (Expr.withSelf s b)
  | .list t es => .list (Ty.withSelf s t) (Expr.listWithSelf s es)
  | .listInit u es => .listInit (Ty.withSelf s u) (Expr.listWithSelf s es)
  | .withDrops e pre post => .withDrops (Expr.withSelf s e) pre post
  | e => e

/-- The expressions `es` with `Self` replaced by `s` in their types. -/
def Expr.listWithSelf (s : Name) : List Expr → List Expr
  | [] => []
  | e :: es => Expr.withSelf s e :: Expr.listWithSelf s es
end

mutual
/-- The statement `st` with `Self` replaced by `s` in its types. -/
def Stmt.withSelf (s : Name) : Stmt → Stmt
  | .decl x t init => .decl x (Ty.withSelf s t) (init.map (Expr.withSelf s))
  | .refDecl x e => .refDecl x (Expr.withSelf s e)
  | .assign p e => .assign (Place.withSelf s p) (Expr.withSelf s e)
  | .expr e => .expr (Expr.withSelf s e)
  | .print args => .print (Expr.listWithSelf s args)
  | .ifElse c a b => .ifElse (Expr.withSelf s c) (Stmt.blockWithSelf s a) (Stmt.blockWithSelf s b)
  | .whileLoop c body => .whileLoop (Expr.withSelf s c) (Stmt.blockWithSelf s body)
  | .ret value => .ret (value.map (Expr.withSelf s))
  | st => st

/-- The statements `b` with `Self` replaced by `s` in their types. -/
def Stmt.blockWithSelf (s : Name) : List Stmt → List Stmt
  | [] => []
  | st :: rest => Stmt.withSelf s st :: Stmt.blockWithSelf s rest
end

/-- The method `fd` of the struct `s` with `Self` replaced by `s` in its
parameters, its result and its body. -/
def FunDecl.withSelf (s : Name) (fd : FunDecl) : FunDecl :=
  { fd with params := fd.params.map fun p => { p with ty := Ty.withSelf s p.ty },
            result := Ty.withSelf s fd.result,
            body := Stmt.blockWithSelf s fd.body }

/-- The program `prog` with `Self` replaced, in the methods, initializer
and destructor of each struct, by the struct. -/
def resolveSelf (prog : Program) : Program :=
  { prog with structs := prog.structs.map fun sd =>
      { sd with init := sd.init.map (FunDecl.withSelf sd.name),
                deinit := sd.deinit.map (Stmt.blockWithSelf sd.name),
                methods := sd.methods.map (FunDecl.withSelf sd.name) } }

end MojoGrimoire.Parse
