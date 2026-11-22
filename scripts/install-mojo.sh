#!/usr/bin/env bash
# Install the reference Mojo compiler, the nightly wheel pinned below
# (ADR-2026-11-15-1907), into a directory outside this repository. Print on
# stdout the path of a `mojo` wrapper that runs it isolated from any other
# Mojo; everything else goes to stderr. Run the reference compiler only
# through that wrapper.
# Usage: scripts/install-mojo.sh <install-dir>
# The pin is recorded in docs/conformance/decision-log.md; a move of the pin
# edits both, records the suite again and runs `scripts/conformance.py
# levels` (docs/decisions/conformance.md#moving-the-pin). Needs curl,
# sha256sum and uv.
set -euo pipefail

readonly version="1.3.0.dev2026111905"
readonly version_line="Mojo 1.3.0.dev2026111905 (a549e6a6)"
readonly modular_index="https://whl.modular.com/nightly/simple"
readonly pypi_index="https://pypi.org/simple"
readonly platform="manylinux_2_34_x86_64"
# Project, wheel file and sha256 of each wheel that is checked before it is
# installed: the driver, the compiler and the standard library. The human
# ruled the first two hashes on 2026-11-19 (#160).
readonly wheels=(
    "mojo mojo-$version-py3-none-$platform.whl 8fe3eaa620c0183299add641392a798a8020b8c0bf5a848c4735a5294bebd129"
    "mojo-compiler mojo_compiler-$version-py3-none-$platform.whl 55270afc0e9a4fc50c09d685fef1ab48c379460265d942dc4df6e9c6adcc5cab"
    "mojo-compiler-mojo-libs mojo_compiler_mojo_libs-$version-py3-none-any.whl 80df184f19b024e0e43229f94abf38cfa7dcb71203b79cc6977a23bd285aa5b2"
)
readonly marker=".mojo-grimoire-reference"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <install-dir>" >&2
    exit 2
fi
if [[ "$(uname -s)/$(uname -m)" != "Linux/x86_64" ]]; then
    echo "The pinned wheel is for $platform; this host is $(uname -s)/$(uname -m)." >&2
    exit 1
fi
glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
if [[ -z "$glibc" ]] || ! printf '2.34\n%s\n' "$glibc" | sort -C -V; then
    echo "The pinned wheel is for $platform; this host has glibc ${glibc:-unknown}." >&2
    exit 1
fi
for tool in curl sha256sum uv; do
    if ! command -v "$tool" >/dev/null; then
        echo "$tool is required." >&2
        exit 1
    fi
done

root=$(realpath -m "$1")
here=$(dirname "${BASH_SOURCE[0]}")
repo_root=$(git -C "$here" rev-parse --show-toplevel)
# In a worktree, the main checkout holds the worktree; refuse both.
main_root=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")
for tree in "$repo_root" "$main_root"; do
    if [[ "$root" == "$tree" || "$root" == "$tree"/* ]]; then
        echo "The install directory must be outside this repository: $root" >&2
        exit 1
    fi
done

# The virtual environment is made afresh on every run, so that it holds
# exactly the pinned wheels; refuse to clear a directory this script did not
# make.
if [[ -e "$root" && ! -e "$root/$marker" && -n "$(ls -A "$root")" ]]; then
    echo "$root is not empty and was not made by $0; give a new directory." >&2
    exit 1
fi
mkdir -p "$root/wheels" "$root/home"
echo "Written by mojo-grimoire's scripts/install-mojo.sh." >"$root/$marker"

# Download each checked wheel from the URL that Modular's index gives for it,
# and compare its sha256 with the pinned one, not with the index's.
local_wheels=()
for entry in "${wheels[@]}"; do
    read -r project file sha <<<"$entry"
    path="$root/wheels/$file"
    if [[ ! -f "$path" ]] || ! sha256sum --quiet -c <<<"$sha  $path" 2>/dev/null; then
        url=$(curl -fsSL "$modular_index/$project/" |
            grep -o "href=\"[^\"#]*/${file}[#\"]" | head -n 1 | sed 's/^href="//; s/[#"]$//')
        if [[ -z "$url" ]]; then
            echo "Modular's index has no $file." >&2
            exit 1
        fi
        if ! curl -fsSL -o "$path.part" "$url"; then
            rm -f "$path.part"
            echo "Could not download $url." >&2
            exit 1
        fi
        mv "$path.part" "$path"
    fi
    if ! sha256sum --quiet -c <<<"$sha  $path" >&2; then
        echo "$file does not have the pinned sha256 $sha." >&2
        exit 1
    fi
    local_wheels+=("$path")
done

# The wheels' other dependencies are pinned by exact version in their
# metadata. Modular's index comes first, so that a project it holds is never
# taken from PyPI.
venv="$root/venv"
uv venv --quiet --clear "$venv" >&2
uv pip install --quiet --python "$venv/bin/python" \
    --index "$modular_index" --default-index "$pypi_index" \
    "${local_wheels[@]}" >&2

installed=$(uv pip list --python "$venv/bin/python" --format freeze 2>/dev/null)
while read -r dist; do
    if [[ "$dist" != *"==$version" ]]; then
        echo "The environment holds $dist, not version $version." >&2
        exit 1
    fi
done < <(grep -E '^mojo(-[a-z-]+)?==' <<<"$installed")
for entry in "${wheels[@]}"; do
    read -r project _ <<<"$entry"
    if ! grep -qx "$project==$version" <<<"$installed"; then
        echo "The environment lacks $project==$version." >&2
        exit 1
    fi
done

# The wheel's `mojo` takes its package root and import path from inherited
# MODULAR_* variables when they are set, and the driver reads the first
# modular.cfg it finds. It is a Python script, which an inherited PYTHON*
# variable, such as PYTHONPATH, can point at another install's `mojo`
# package. The wrapper removes every inherited MODULAR_* and PYTHON*
# variable and gives the driver a home whose modular.cfg is empty.
echo "# Written by mojo-grimoire's scripts/install-mojo.sh; intentionally empty." \
    >"$root/home/modular.cfg"
wrapper="$root/mojo"
{
    echo '#!/usr/bin/env bash'
    echo "# Written by mojo-grimoire's scripts/install-mojo.sh for Mojo $version."
    echo 'set -euo pipefail'
    # shellcheck disable=SC2016 # the wrapper expands it, not this script
    echo 'for var in $(compgen -e); do [[ $var != MODULAR_* && $var != PYTHON* ]] || unset "$var"; done'
    printf 'export MODULAR_HOME=%q\n' "$root/home"
    printf 'exec %q "$@"\n' "$venv/bin/mojo"
} >"$wrapper"
chmod +x "$wrapper"

if [[ "$("$wrapper" --version)" != "$version_line" ]]; then
    echo "$wrapper reports $("$wrapper" --version), not $version_line." >&2
    exit 1
fi

# Check the isolation against a hostile environment: a home whose modular.cfg
# names another install, and inherited MODULAR_* and PYTHON* variables that
# point elsewhere; the `mojo` package planted there would fail. The test program must build, run, and load every non-system
# library from the installed wheels.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home/.config/modular" "$scratch/elsewhere/lib" "$scratch/elsewhere/python/mojo"
printf 'raise SystemExit("the planted mojo package was imported")\n' \
    >"$scratch/elsewhere/python/mojo/__init__.py"
printf '[mojo-max]\npackage_root = %s\nimport_path = %s\n' \
    "$scratch/elsewhere" "$scratch/elsewhere/lib/mojo" \
    >"$scratch/home/.config/modular/modular.cfg"
printf 'def main():\n    var xs = [1, 2, 3]\n    print("isolated", len(xs))\n' >"$scratch/check.mojo"
(
    cd "$scratch"
    env HOME="$scratch/home" \
        PYTHONPATH="$scratch/elsewhere/python" \
        MODULAR_MOJO_MAX_DRIVER_PATH="$scratch/elsewhere/mojo" \
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
        "$venv"/* | /usr/lib/* | /usr/lib64/* | /lib/* | /lib64/*) ;;
        *)
            echo "The test program loads $lib from $path, outside the installed wheels." >&2
            exit 1
            ;;
    esac
done < <(ldd "$scratch/check" | grep '=>')

echo "Run the reference compiler only through $wrapper" >&2
echo "$wrapper"
