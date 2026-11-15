#!/usr/bin/env bash
# Render the spec document in docs/spec/ (ADR-2026-11-15-2030).
# Usage: scripts/build-spec.sh [--update] [OUTPUT_DIR]
# The rendered HTML goes to OUTPUT_DIR, by default docs/spec/_out; open
# html-multi/index.html. Every page names the commit it was built from
# (docs/decisions/spec.md#every-page-names-its-commit).
# --update first runs `lake update` in docs/spec/, under the same guards, for
# a toolchain bump. Never run a bare `lake update` there.
# The model in lean/ is built by scripts/build-lean.sh, which applies the
# stricter checks of lean/; docs/spec/ requires it by path, so Lake builds
# what of it is stale here too.
set -euo pipefail

update=false
if [[ "${1:-}" == --update ]]; then
    update=true
    shift
fi
if [[ $# -gt 1 || "${1:-}" == -* ]]; then
    echo "Usage: $0 [--update] [OUTPUT_DIR]" >&2
    exit 2
fi

# Git runs hooks with GIT_DIR, GIT_INDEX_FILE and similar variables set to
# this repository. Lake runs git inside its package clones, and with those
# variables set its git commands would act on this repository instead.
for var in $(git rev-parse --local-env-vars); do
    unset "$var"
done

repo_root=$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)
out=$(realpath -m "${1:-$repo_root/docs/spec/_out}")

# The commit for the foot of every page. Changes not yet committed, untracked
# files included, mark the build -dirty. No optional locks: a hook runs while
# git holds the index.
commit=$(git -C "$repo_root" rev-parse HEAD)
export MOJOSPEC_COMMIT=${commit:0:12}
if [[ -n "$(git --no-optional-locks -C "$repo_root" status --porcelain)" ]]; then
    MOJOSPEC_COMMIT+=-dirty
fi
if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
    export MOJOSPEC_COMMIT_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$commit"
fi

# Lake treats a package as cloned when its `.git` exists. If that `.git` is
# broken, git skips it and climbs to this repository. The ceiling stops git
# at the package directories, so Lake's git calls fail instead.
export GIT_CEILING_DIRECTORIES="$repo_root/lean/.lake/packages:$repo_root/docs/spec/.lake/packages"

# Lakefiles and elaboration run arbitrary code; keep CI tokens away from them.
unset GH_TOKEN GITHUB_TOKEN

# Verso's includeLiterate runs `elan run`, so elan must be on PATH.
if ! command -v elan >/dev/null && [[ -x "$HOME/.elan/bin/elan" ]]; then
    PATH="$HOME/.elan/bin:$PATH"
fi
if ! command -v elan >/dev/null; then
    echo "elan is not installed; see https://github.com/leanprover/elan" >&2
    exit 1
fi

cd "$repo_root/docs/spec"
if [[ "$update" == true ]]; then
    lake update
fi
# A plain build, not --wfail: Verso's warnings are not ours. Our own code in
# lean/ fails on every warning through build-lean.sh (ADR-2026-11-15-1906).
lake build
lake exe mojospec --output "$out"
echo "Rendered the spec to $out/html-multi/index.html"
