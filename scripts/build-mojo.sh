#!/usr/bin/env bash
# Build the reference Mojo compiler from a checkout of modular/modular at the
# pinned commit (ADR-2026-11-15-1907), and print the path of the `mojo`
# binary on stdout. Everything else goes to stderr.
# Usage: scripts/build-mojo.sh <modular-checkout>
# The checkout lives outside this repository. The pin is recorded in
# docs/conformance/decision-log.md; a move of the pin edits both.
set -euo pipefail

readonly pinned_tag="mojo/v1.2.0"
readonly pinned_sha="527d069ee11a41ac5320af1f9402db0a66b2b868"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <modular-checkout>" >&2
    exit 2
fi

checkout=$(cd "$1" && pwd)
repo_root=$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)

if [[ "$checkout" == "$repo_root" || "$checkout" == "$repo_root"/* ]]; then
    echo "The modular checkout must be outside this repository: $checkout" >&2
    exit 1
fi

if ! head=$(git -C "$checkout" rev-parse HEAD 2>/dev/null); then
    echo "$checkout is not a git checkout of modular/modular." >&2
    exit 1
fi
if [[ "$head" != "$pinned_sha" ]]; then
    echo "$checkout is at $head, not the pinned $pinned_tag ($pinned_sha)." >&2
    echo "Check it out with: git -C '$checkout' checkout $pinned_sha" >&2
    exit 1
fi
if [[ -n "$(git -C "$checkout" status --porcelain --untracked-files=no)" ]]; then
    echo "$checkout has local changes to tracked files; the build would not be the pinned compiler." >&2
    exit 1
fi

# --config=build-mojo builds the compiler from source instead of fetching the
# prebuilt toolchain. The repository defaults to a debug build; -c opt is
# what a release ships, and is far smaller and faster.
bazel_flags=(--config=build-mojo --compilation_mode=opt)
target=//Mojo:mojo

cd "$checkout"

# bazelw caches the host's GPU resources in build/local-resources.bazelrc. Its
# detection writes an error line there instead when the host has rocm-smi but
# not amd-smi, and Bazel then fails. Building the compiler needs no GPU, so
# declare none when the cached file is missing or holds that error.
resources=build/local-resources.bazelrc
if [[ ! -f "$resources" ]] || grep -q '^error:' "$resources"; then
    mkdir -p build
    echo "build --local_resources=gpu-memory=0" >"$resources"
fi

./bazelw build "${bazel_flags[@]}" "$target" >&2

# Ask Bazel where the binary is, under the same configuration, rather than
# guessing a bazel-bin path. //Mojo:mojo is an alias, so the file is named
# after the target it points to.
mapfile -t outputs < <(./bazelw cquery "${bazel_flags[@]}" --output=files "$target" 2>/dev/null)
if [[ ${#outputs[@]} -ne 1 || ! -x "$checkout/${outputs[0]}" ]]; then
    echo "Bazel built $target but did not report exactly one executable output: ${outputs[*]:-none}" >&2
    exit 1
fi
binary="$checkout/${outputs[0]}"

# Outside `bazelw run`, the binary finds the standard library only through
# MODULAR_MOJO_MAX_IMPORT_PATH. It also reads any modular.cfg it finds, such
# as one left by an installed Mojo in ~/.config/modular, and `mojo build`
# then sets the program's rpath to that install's runtime. An empty
# MODULAR_HOME hides such a file, and MODULAR_MOJO_MAX_SHARED_LIBS points the
# rpath at the runtime built here.
runfiles="$binary.runfiles/_main"
stdlib="$runfiles/Mojo/stdlib/std"
for file in "$stdlib/std.mojoc" "$runfiles/Mojo/libKGENCompilerRTShared.so"; do
    if [[ ! -e "$file" ]]; then
        echo "A built file is missing: $file" >&2
        exit 1
    fi
done
runtime=$(readlink -f "$runfiles/Mojo")
cat >&2 <<EOF
Run the compiler with this environment, where <empty-dir> is an empty directory:
  MODULAR_HOME=<empty-dir>
  MODULAR_MOJO_MAX_IMPORT_PATH=$stdlib
  MODULAR_MOJO_MAX_SHARED_LIBS=-Xlinker,-rpath,-Xlinker,$runtime
EOF

echo "$binary"
