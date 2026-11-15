# Phase 0 baseline

Gate G0 of the roadmap asks for evidence that both the Mojo compiler at the
pinned commit and the Isabelle formalisation `utting/mojo-semantics`
reproduce the results recorded in that repository. This page records the run
of 2026-11-15. It names the formalisation's test programs by file name only.
Their text and expected outputs stay in that repository
(ADR-2026-11-15-1908), and nothing in this repository reads them.

## What was run

| Item | Value |
| ---- | ----- |
| Date | 2026-11-15 |
| Host | Linux 7.2 (Arch-based), x86_64, AMD Ryzen AI 9 HX 370, 24 threads |
| Mojo | tag `mojo/v1.2.0` of `modular/modular`, commit `527d069ee11a41ac5320af1f9402db0a66b2b868` |
| Mojo build | `scripts/build-mojo.sh`: `//Mojo:mojo` with `--config=build-mojo --compilation_mode=opt`; it reports `Mojo 1.2.0.dev0 (deadbeef)` |
| Isabelle | Isabelle2026, `Isabelle2026_linux.tar.gz` from isabelle.in.tum.de, SHA-256 `858c995b32216b3876bf395c3be843147d1f1eee404bc6c958d7534ee335e48d` |
| Formalisation | `utting/mojo-semantics` at commit `40dfd28d4b3990656c46a298b7a983d3af52fce3`, cloned outside this repository |

The formalisation recorded its results with a release binary that reports
`Mojo 1.2.0 (2016d0cd)`. That build ID is not a commit of the public
repository. A build from source has no version stamp, which is why ours
reports `dev0 (deadbeef)`.

## Isabelle model

The formalisation's README builds with `isabelle build -D .`. That command
also selects the session `Mojo_Paper`, which needs LaTeX to typeset a paper
and checks no test. We built the two sessions that hold the model and its
tests instead:

```sh
isabelle build -d . Mojo_Semantics Mojo_Tests
```

Both sessions finished without error.

| Count | Value |
| ----- | ----- |
| Suite programs | 65 |
| Accepted by the translator and built into tests | 65 |
| Agree with the recorded result | 63 |
| Known divergences, proved as divergences | 2 |

Before the build, we regenerated the suite's test theory from the recorded
results and found it identical to the committed one, with 65 tests and 2
divergence lemmas. So the green build covers all 65 programs. Of the recorded
results, 47 are normal runs with output, 15 are compile errors and 3 are
run-time errors.

### Divergences of the model

- `d05_nested_fields.mojo`: inside a `__deinit__`, the compiler destroys each
  field of `self` as soon as the method body no longer needs it. The model
  destroys all the fields together when the body ends, so the order of the
  printed destructor messages differs.
- `d13_deinit_fields_asap.mojo`: the same gap. Fields that the body never
  uses are destroyed before the body runs, and the others after their last
  use, while the model destroys them all after the body.

## Compiler

Each of the 65 programs was compiled with `mojo build` and the binary was
run, with the same classification as the recorded results. A failed build is
a compile error, a non-zero exit is a run-time error, and otherwise the result
is the output. Output was compared line for line. A compile error was compared
by status. In addition, the first error that the compiler reports matched the
recorded one, by position and message, for all 15 compile errors.

| Count | Value |
| ----- | ----- |
| Programs | 65 |
| Compiled | 50 |
| Rejected at compile time, as recorded | 15 |
| Agree with the recorded result | 65 |
| Diverge | 0 |

Two programs, `l04_index_oob.mojo` and `l06_negative_index.mojo`, print a
bounds-check message that contains the absolute path of the source file. The
path differs between the recording machine and ours. We compared these two
outputs with the directory removed from that path. Nothing else in their
output differs.

### How the compiler was run

`scripts/build-mojo.sh` prints the path of the built binary and the
environment it needs outside `bazelw run`. Two details matter for anyone who
repeats this run:

- The binary reads any `modular.cfg` it finds, including one left in
  `~/.config/modular` by an installed Mojo. `mojo build` then gives each
  program an rpath into that install, so the program runs against the
  installed runtime, not the one built from the pinned commit. Our first run
  did exactly that. The script's printed environment avoids it with an empty
  `MODULAR_HOME` and an explicit rpath. In the run recorded here, every
  compiled program loaded only runtime libraries built from the pinned
  commit.
- `bazelw` caches the host's GPU resources in the checkout's
  `build/local-resources.bazelrc`. On a host with `rocm-smi` but not
  `amd-smi`, its detection writes an error into that file, and every Bazel
  command fails. The compiler build needs no GPU, so the script declares none
  in that case.

## Result

Gate G0 holds at the pin: the Isabelle model reproduces the recorded results
except for its two documented divergences, and the compiler built from the
pinned commit reproduces all 65 recorded results.
