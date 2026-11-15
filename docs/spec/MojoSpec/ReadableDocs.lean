import MojoSpec.Reference

/-!
The readable documents that `MojoSpec.lean` renders with `{includeReadable}`,
one per module of `lean/MojoGrimoire` (ADR-2026-11-15-2030). They are imported
here, not in `MojoSpec.lean`, so that the document stays within the file-size
budget (ADR-2026-11-15-1901) as modules are added. A new module adds the
import of its document here.
-/
