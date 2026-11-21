import MojoGrimoire.Core.Program

/-!
Types whose name a variable hides.

Inside its scope, a variable or a parameter hides a type of its name, as
it hides a function in a call (#176), so the compiler rejects the name in
a type: "cannot use a dynamic value in type specification" for a whole
type, and "cannot use a dynamic value in a parameter list" inside
`List[…]` or `Array[…]`, as the pinned nightly 1.3.0.dev2026111905 does.
The hidden name is `Int`, `Bool`, a struct of the program, or any other
name, which no struct declares. This pass marks each such name with
`hiddenTy` in the types that the program writes, before `Self` is
resolved and before inference, which writes types that the program does
not, and the checker rejects the mark as `valueAsType` (#193).

A parameter hides the types of the parameters after it and the
function's result, and a variable declared with `var` or bound with `ref`
the types after its declaration in its block, not its own. A field hides
nothing. `List` and `Array` themselves are not marked: a variable of that
name makes `List[…]` a subscript of the variable, which the compiler
reports otherwise. Nor are `None`, which no variable may be named, and
`Self`.
-/

namespace MojoGrimoire.Parse

open MojoGrimoire.Core

/-- The type `t` where the variables `vs` are in scope, with each name in
it that one of them has marked as hidden. -/
def Ty.markHidden (vs : List Name) : Ty → Ty
  | .int => if vs.contains "Int" then hiddenTy "Int" else .int
  | .bool => if vs.contains "Bool" then hiddenTy "Bool" else .bool
  | .struct s => if s != "Self" && vs.contains s then hiddenTy s else .struct s
  | .list t => .list (Ty.markHidden vs t)
  | .array t n => .array (Ty.markHidden vs t) n
  | t => t

mutual
/-- The place `p` with the types in its indices marked. -/
def Place.markHidden (vs : List Name) : Place → Place
  | .var x => .var x
  | .field p f => .field (Place.markHidden vs p) f
  | .index p i => .index (Place.markHidden vs p) (Expr.markHidden vs i)
  | .transferred p => .transferred (Place.markHidden vs p)

/-- The expression `e` with the types of `List[u]()` and `List[u](…)`
marked, wherever they stand in it. A literal's type is left for
inference, which no variable hides. -/
def Expr.markHidden (vs : List Name) : Expr → Expr
  | .place p => .place (Place.markHidden vs p)
  | .transfer p => .transfer (Place.markHidden vs p)
  | .copy p => .copy (Place.markHidden vs p)
  | .call f args => .call f (Expr.listMarkHidden vs args)
  | .method p m args => .method (Place.markHidden vs p) m (Expr.listMarkHidden vs args)
  | .unary op a => .unary op (Expr.markHidden vs a)
  | .binary op a b => .binary op (Expr.markHidden vs a) (Expr.markHidden vs b)
  | .list t es => .list (Ty.markHidden vs t) (Expr.listMarkHidden vs es)
  | .listInit u es => .listInit (Ty.markHidden vs u) (Expr.listMarkHidden vs es)
  | .withDrops e pre post => .withDrops (Expr.markHidden vs e) pre post
  | e => e

/-- The expressions `es` with their types marked. -/
def Expr.listMarkHidden (vs : List Name) : List Expr → List Expr
  | [] => []
  | e :: es => Expr.markHidden vs e :: Expr.listMarkHidden vs es
end

mutual
/-- The statement `st` with its types marked, and the variables in scope
after it. -/
def Stmt.markHidden (vs : List Name) : Stmt → Stmt × List Name
  | .decl x t init => (.decl x (Ty.markHidden vs t) (init.map (Expr.markHidden vs)), x :: vs)
  | .refDecl x e => (.refDecl x (Expr.markHidden vs e), x :: vs)
  | .assign p e => (.assign (Place.markHidden vs p) (Expr.markHidden vs e), vs)
  | .expr e => (.expr (Expr.markHidden vs e), vs)
  | .print args => (.print (Expr.listMarkHidden vs args), vs)
  | .ifElse c a b =>
    (.ifElse (Expr.markHidden vs c) (Stmt.blockMarkHidden vs a) (Stmt.blockMarkHidden vs b), vs)
  | .whileLoop c body => (.whileLoop (Expr.markHidden vs c) (Stmt.blockMarkHidden vs body), vs)
  | .ret value => (.ret (value.map (Expr.markHidden vs)), vs)
  | st => (st, vs)

/-- The statements `b` with their types marked, each where the variables
declared before it in the block are in scope too. -/
def Stmt.blockMarkHidden (vs : List Name) : List Stmt → List Stmt
  | [] => []
  | st :: rest =>
    let (st', vs') := Stmt.markHidden vs st
    st' :: Stmt.blockMarkHidden vs' rest
end

/-- The parameters `ps` with their types marked, each where the
parameters `vs` before it are in scope. -/
def Param.listMarkHidden (vs : List Name) : List Param → List Param
  | [] => []
  | p :: ps => { p with ty := Ty.markHidden vs p.ty } :: Param.listMarkHidden (p.name :: vs) ps

/-- The function `fd` with the types of its parameters, its result and its
body marked: every parameter is in scope in its result and its body. -/
def FunDecl.markHidden (fd : FunDecl) : FunDecl :=
  let vs := fd.params.map (·.name)
  { fd with params := Param.listMarkHidden [] fd.params,
            result := Ty.markHidden vs fd.result,
            body := Stmt.blockMarkHidden vs fd.body }

/-- The program `prog` with the types that a variable hides marked, in
its functions, and in the methods, initializer and destructor of each
struct. -/
def markHidden (prog : Program) : Program :=
  { structs := prog.structs.map fun sd =>
      { sd with init := sd.init.map FunDecl.markHidden,
                deinit := sd.deinit.map (Stmt.blockMarkHidden ["self"]),
                methods := sd.methods.map FunDecl.markHidden },
    funs := prog.funs.map FunDecl.markHidden }

end MojoGrimoire.Parse
