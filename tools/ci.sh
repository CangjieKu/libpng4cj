#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)

step() {
    printf '\n==> %s\n' "$1"
}

step "environment doctor"
"$ROOT/tools/doctor.sh"

step "frozen upstream inventories"
"$ROOT/tools/update-upstream-baseline.sh"
"$ROOT/tools/update-pngwtran-inventory.sh"

if command -v git >/dev/null 2>&1; then
    git -C "$ROOT" diff --exit-code -- doc/upstream
fi

step "package build"
(cd "$ROOT" && cjpm build)

step "package tests"
(cd "$ROOT" && cjpm test)

step "standalone Cangjie consumer"
(cd "$ROOT/test/consumer" && cjpm run)

printf '\nlibpng4cj CI: PASS\n'
