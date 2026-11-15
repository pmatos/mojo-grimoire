#!/usr/bin/env bash
# Build the reference Mojo compiler from a checkout of modular/modular at the
# pinned commit (ADR-2026-11-15-1907). Print on stdout the path of a `mojo`
# wrapper that runs it isolated from any installed Mojo; everything else goes
# to stderr. Run the reference compiler only through that wrapper.
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
# MODULAR_MOJO_MAX_IMPORT_PATH. It also reads the first modular.cfg it finds,
# such as one left by an installed Mojo in ~/.config/modular, and any
# MODULAR_* variable, and `mojo build` then links programs against that
# install's runtime. The wrapper below removes every inherited MODULAR_*
# variable and sets its own home, package root, import path and rpath, so
# the compiler and the programs it builds use only what was built here.
runfiles="$binary.runfiles/_main"
stdlib="$runfiles/Mojo/stdlib/std"
for file in "$stdlib/std.mojoc" "$runfiles/Mojo/libKGENCompilerRTShared.so"; do
    if [[ ! -e "$file" ]]; then
        echo "A built file is missing: $file" >&2
        exit 1
    fi
done
runtime=$(readlink -f "$runfiles/Mojo")
output_root=${runtime%%/bazel-out/*}

isolated="$checkout/build/mojo-grimoire"
wrapper="$isolated/mojo"
mkdir -p "$isolated/home"
# The driver falls back to /etc/modular/modular.cfg when MODULAR_HOME has
# none; this file stops that search here.
echo "# Written by mojo-grimoire's scripts/build-mojo.sh; intentionally empty." \
    >"$isolated/home/modular.cfg"
{
    echo '#!/usr/bin/env bash'
    echo "# Written by mojo-grimoire's scripts/build-mojo.sh for $pinned_tag ($pinned_sha)."
    echo 'set -euo pipefail'
    # shellcheck disable=SC2016 # the wrapper expands it, not this script
    echo 'for var in $(compgen -e); do [[ $var != MODULAR_* ]] || unset "$var"; done'
    printf 'export MODULAR_HOME=%q\n' "$isolated/home"
    printf 'export MODULAR_MOJO_MAX_PACKAGE_ROOT=%q\n' "$isolated"
    printf 'export MODULAR_MOJO_MAX_IMPORT_PATH=%q\n' "$stdlib"
    printf 'export MODULAR_MOJO_MAX_SHARED_LIBS=%q\n' "-Xlinker,-rpath,-Xlinker,$runtime"
    printf 'exec %q "$@"\n' "$binary"
} >"$wrapper"
chmod +x "$wrapper"

# Check the isolation against a hostile environment: a home whose modular.cfg
# names another install, and inherited MODULAR_* variables that point
# elsewhere. The test program must build, run, and load every non-system
# library from this build's output tree.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.config/modular" "$scratch/elsewhere/lib"
printf '[mojo-max]\npackage_root = %s\nimport_path = %s\n' \
    "$scratch/elsewhere" "$scratch/elsewhere/lib/mojo" \
    >"$scratch/home/.config/modular/modular.cfg"
printf 'def main():\n    var xs = [1, 2, 3]\n    print("isolated", len(xs))\n' >"$scratch/check.mojo"
(
    cd "$scratch"
    env HOME="$scratch/home" \
        MODULAR_MOJO_MAX_IMPORT_PATH="$scratch/elsewhere/lib/mojo" \
        MODULAR_MOJO_MAX_SHARED_LIBS="-Xlinker,-rpath,-Xlinker,$scratch/elsewhere/lib" \
        "$wrapper" build check.mojo -o check >&2
)
if [[ "$("$scratch/check")" != "isolated 3" ]]; then
    echo "The test program built by $wrapper printed the wrong output." >&2
    exit 1
fi
while read -r lib _ path _; do
    case "$path" in
        "$output_root"/* | /usr/lib/* | /usr/lib64/* | /lib/* | /lib64/*) ;;
        *)
            echo "The test program loads $lib from $path, outside this build." >&2
            exit 1
            ;;
    esac
done < <(ldd "$scratch/check" | grep '=>')

echo "Run the reference compiler only through $wrapper" >&2
echo "$wrapper"
