#!/usr/bin/env bash
# Build the Lean package in lean/ (ADR-2026-11-15-1905). Building it runs the
# Lean tests and the axiom check (ADR-2026-11-15-1906).
# Usage: scripts/build-lean.sh
# Every Lake run in lean/, in hooks, CI or by hand, goes through this script
# or applies its guards.
set -euo pipefail

if [[ $# -gt 0 ]]; then
    echo "Usage: $0" >&2
    exit 2
fi

# Git runs hooks with GIT_DIR, GIT_INDEX_FILE and similar variables set to
# this repository. Lake runs git inside its package clones, and with those
# variables set its git commands would act on this repository instead.
for var in $(git rev-parse --local-env-vars); do
    unset "$var"
done

repo_root=$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)

# Lake treats a package as cloned when its `.git` exists. If that `.git` is
# broken, git skips it and climbs to this repository. The ceiling stops git
# at the package directory, so Lake's git calls fail instead.
export GIT_CEILING_DIRECTORIES="$repo_root/lean/.lake/packages"

# Lakefiles and elaboration run arbitrary code; keep CI tokens away from them.
unset GH_TOKEN GITHUB_TOKEN

if ! command -v elan >/dev/null && [[ -x "$HOME/.elan/bin/elan" ]]; then
    PATH="$HOME/.elan/bin:$PATH"
fi
if ! command -v elan >/dev/null; then
    echo "elan is not installed; see https://github.com/leanprover/elan" >&2
    exit 1
fi

cd "$repo_root/lean"
# lean/ has no dependencies, so every warning is in our own code and fails
# the build, a `sorry` inside an `example` included (ADR-2026-11-15-1906).
lake build --wfail

# In CI, the counts of the Lean checks go to the job summary
# (ADR-2026-11-15-1903).
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    python3 -I "$repo_root/scripts/suite_summary.py" lean "$repo_root/lean"
fi
