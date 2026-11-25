# The checker reports errors in the compiler's three tiers

Status: accepted
Tier: direction; area: semantics

## Decision

`MojoGrimoire.Check.checkProgram` runs three phases over the whole
program and reports the first error of the first phase that finds one:

1. the type phase, the errors the compiler reports while parsing, with
   every variable taken as initialized;
2. the flow phase, on a program the type phase accepts: the errors of
   the compiler's pass manager, such as missing returns and uses of
   uninitialized values; a missing `main` follows it;
3. the instantiation phase, on a program the flow phase accepts: a
   literal of `Int`s of the wrong length and a constant index out of
   range.

Each check belongs to one phase; a class may come from two, as
`noMatchingInit` does. The phases are one traversal of each body with
the phase as a parameter, and each skips the checks of later phases.
Each phase visits the declarations in the order in which the compiler
checks its tier, which the area page records with its evidence;
`MojoGrimoire.Core.Program` keeps their source order for it.
`MojoGrimoire.Parse.Subset` still runs before the checker.

## Why

The compiler is the reference (ADR-2026-11-15-1907), and the suite
compares its first error. Probes of the pin (#96) show the tiers hold
across the whole program: a type error in a later function comes before
an uninitialized use in an earlier one. A one-pass checker that throws
at the first error cannot give that order, and each workaround
(`lateElemTy`, `CheckError.late`, `State.typing`, `lateErrors`)
approximates it for one construct and loses the errors after it. The
human ruled this option, (A), on 2026-11-20.

## Rejected alternatives

- A local fix per construct (#89, #142, #170): option (B); each needs
  another deferral like `lateElemTy`.
- A traversal per phase: two copies of every rule to keep in step.
- Collecting every error with a sort key: the checker cannot go on
  soundly after an error, and no single key gives the compiler's order,
  which puts missing returns first and the last call first.
