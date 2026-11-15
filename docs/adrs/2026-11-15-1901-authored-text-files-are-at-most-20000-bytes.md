# Authored text files are at most 20,000 bytes

Status: accepted
Tier: direction; area: process

## Decision

- Every text file in the repository is at most 20,000 bytes: about 5k tokens
  of prose, 5–7k tokens of code.
- The `file-size-budget` pre-commit hook (`scripts/check_file_size.py`)
  enforces it on the staged text files, and CI runs it over every file.
- The cap is strict. There is no ratchet that lets an oversized file stay.
- Only generated or vendored files are exempt, through the hook's `exclude`
  pattern in `.pre-commit-config.yaml`. Authored code is never exempt.
- Modules are split by responsibility from the start: a cohesive group of
  definitions, theorems, tests or doc sections moves to a sibling file.

## Why

Agents develop this project. An agent works best on a file it can read whole:
it sees every definition at once and spends little context doing so. Large
files get read in fragments, and edits then miss code the agent never saw.
jsse and funk enforce the same cap.

## Rejected alternatives

- **Count real tokens.** Claude's tokenizer is not available offline. Bytes
  are deterministic, instant and language-neutral.
- **jsse's ratcheting checker.** A ratchet only matters for a repository that
  already has oversized files; this one starts with none.
