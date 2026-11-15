#!/usr/bin/env bash
# Installs elan in a CI setup step
# (docs/decisions/process-ci.md#installer-downloads).
# Usage: scripts/ci-install.sh elan
# The step's env pins the installer: ELAN_VERSION and ELAN_SHA256. The
# installer is downloaded to RUNNER_TEMP only when the step before restored
# no copy from the cache, and its SHA-256 is checked in either case, before
# it is used, so a bad cached file fails the step. The tool's directory is appended to GITHUB_PATH.
set -euo pipefail

# Downloads URL to FILE unless FILE exists, then checks FILE against SHA256.
# A download retries 5 times, 10 s apart, on any error.
fetch() {
    local file=$1 sha256=$2 url=$3
    if [[ -f $file ]]; then
        echo "$file: restored from the cache, not downloaded"
    else
        echo "$file: not in the cache, downloading $url"
        curl -sSfL --retry 5 --retry-delay 10 --retry-all-errors -o "$file" "$url"
    fi
    echo "$sha256  $file" | sha256sum -c -
}

case "${1-}" in
    elan)
        fetch "$RUNNER_TEMP/elan.tar.gz" "$ELAN_SHA256" \
            "https://github.com/leanprover/elan/releases/download/$ELAN_VERSION/elan-x86_64-unknown-linux-gnu.tar.gz"
        tar -xzf "$RUNNER_TEMP/elan.tar.gz" -C "$RUNNER_TEMP"
        "$RUNNER_TEMP/elan-init" -y --no-modify-path --default-toolchain none
        echo "$HOME/.elan/bin" >>"$GITHUB_PATH"
        ;;
    *)
        echo "Usage: $0 elan" >&2
        exit 2
        ;;
esac
