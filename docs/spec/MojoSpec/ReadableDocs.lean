import MojoSpec.Reference
import MojoSpec.Core.Types
import MojoSpec.Core.Syntax
import MojoSpec.Core.Equality
import MojoSpec.Core.Program
import MojoSpec.Check.Errors
import MojoSpec.Check.Env
import MojoSpec.Check.State
import MojoSpec.Check.Loc
import MojoSpec.Check.Fit
import MojoSpec.Check.Change
import MojoSpec.Check.Transfer
import MojoSpec.Check.Operators
import MojoSpec.Check.Expr
import MojoSpec.Check.Ref
import MojoSpec.Check.Stmt
import MojoSpec.Check.Program
import MojoSpec.Elab.Live
import MojoSpec.Elab.Origins
import MojoSpec.Elab.Elaborate
import MojoSpec.Elab.Strip
import MojoSpec.Interp.Value
import MojoSpec.Interp.Machine
import MojoSpec.Interp.Eval
import MojoSpec.Interp.Run
import MojoSpec.Parse.Lexer
import MojoSpec.Parse.Parser
import MojoSpec.Parse.Expr
import MojoSpec.Parse.Stmt
import MojoSpec.Parse.Infer
import MojoSpec.Driver.Main

/-!
The readable documents that `MojoSpec.lean` renders with `{includeReadable}`,
one per module of `lean/MojoGrimoire` (ADR-2026-11-15-2030). They are imported
here, not in `MojoSpec.lean`, so that the document stays within the file-size
budget (ADR-2026-11-15-1901) as modules are added. A new module adds the
import of its document here.
-/
