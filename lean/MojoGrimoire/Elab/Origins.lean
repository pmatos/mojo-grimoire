import MojoGrimoire.Elab.Live
import MojoGrimoire.Check.Ref

/-!
The slots that each reference of a function body may point into.

A reference bound with `ref r = e` points into the slots of the place `e`,
or, when `e` calls a function or a method that returns a reference, into
the slots of the arguments passed to the parameters its origin names, the
receiver of a method among them; an argument that is such a call points
into the slots of its own origin arguments. Elaboration counts
every use of `r` as a use of those slots, so that the values a reference
may point into live as long as it is used: Mojo extends their lifetimes to
the reference's last use.

To find the signature of the method a call names, elaboration needs the
type of the receiver. It follows the types of the variables declared so far, which a
body that the checker accepts gives.
-/

namespace MojoGrimoire.Elab

open MojoGrimoire.Core MojoGrimoire.Check

/-- The types of the variables declared so far, by name. -/
abbrev TyEnv := List (Name × Ty)

/-- The type of the place `p`, if the variables `env` give it one. -/
def placeTyOf (prog : Program) (env : TyEnv) : Place → Option Ty
  | .var x => env.lookup x
  | .field p f => (placeTyOf prog env p).bind fun t => (fieldOf prog t f).toOption
  | .index p _ => (placeTyOf prog env p).bind fun t => (elemOf t).toOption

/-- The signature of what the expression `e` calls, with its arguments, the
receiver of a method first. -/
def refCallee (prog : Program) (env : TyEnv) : Expr → Option (Signature × List Expr)
  | .call f args => (callSig prog f).toOption.map (·, args)
  | .method p m args =>
    ((placeTyOf prog env p).bind fun t => (methodSig prog t m args.length).toOption).map
      (·, .place p :: args)
  | _ => none

mutual
/-- The slots that the located operand `e` may point into: those of a place,
or those of the origin arguments of a call that returns a reference, the
receiver of a method among them, which may be such a call in turn. -/
def locSlots (prog : Program) (sl : Slots) (env : TyEnv) : Expr → List Place
  | .place p => sl.of p
  | .call f args =>
    match callSig prog f with
    | .ok sig => originArgs prog sl env (sig.origin.getD []) sig.params args
    | .error _ => []
  | .method p m args =>
    match (placeTyOf prog env p).bind fun t => (methodSig prog t m args.length).toOption with
    | some sig =>
      let os := sig.origin.getD []
      union (if sig.self.any (os.contains ·.name) then sl.of p else [])
        (originArgs prog sl env os sig.params args)
    | none => []
  | .withDrops e _ _ => locSlots prog sl env e
  | _ => []

/-- The slots of the arguments `args` passed to the parameters named `os`
among `params`. -/
def originArgs (prog : Program) (sl : Slots) (env : TyEnv) (os : List Name) :
    List Param → List Expr → List Place
  | prm :: prms, a :: args =>
    let rest := originArgs prog sl env os prms args
    if os.contains prm.name then union (locSlots prog sl env a) rest else rest
  | _, _ => []
end

/-- The slots that the reference `e` names may point into, and its type. -/
def refSlots (prog : Program) (sl : Slots) (env : TyEnv) (e : Expr) :
    List Place × Option Ty :=
  match e with
  | .place p => (sl.of p, placeTyOf prog env p)
  | e => (locSlots prog sl env e, (refCallee prog env e).map (·.1.result))

/-- Adds the reference `x`, which may point into the slots `os`. Two
references of the same name, in sibling blocks, share one entry. -/
def addAlias (sl : Slots) (x : Name) (os : List Place) : Slots :=
  { sl with aliases := (x, union ((sl.aliases.lookup x).getD []) os) ::
      sl.aliases.filter (·.1 != x) }

mutual
/-- The references and variable types after the statement `s`. -/
def aliasStmt (prog : Program) (acc : Slots × TyEnv) : Stmt → Slots × TyEnv
  | .decl x t _ => (acc.1, (x, t) :: acc.2)
  | .refDecl x e =>
    let (os, t) := refSlots prog acc.1 acc.2 e
    (addAlias acc.1 x os, match t with | some t => (x, t) :: acc.2 | none => acc.2)
  | .ifElse _ a b => aliasBlock prog (aliasBlock prog acc a) b
  | .whileLoop _ body => aliasBlock prog acc body
  | _ => acc

/-- The references and variable types after the block `b`. -/
def aliasBlock (prog : Program) (acc : Slots × TyEnv) : List Stmt → Slots × TyEnv
  | [] => acc
  | s :: rest => aliasBlock prog (aliasStmt prog acc s) rest
end

/-- The slots of a function body with the parameters `params`: `fieldwise`
as given, and every reference the body binds. -/
def slotsOf (prog : Program) (fieldwise : Option (List Name)) (params : List Param)
    (body : List Stmt) : Slots :=
  (aliasBlock prog (⟨fieldwise, []⟩, params.map fun prm => (prm.name, prm.ty)) body).1

end MojoGrimoire.Elab
