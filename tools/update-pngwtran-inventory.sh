#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
SOURCE=$ROOT/vendor/libpng-1.6.58/pngwtran.c
OUTPUT=$ROOT/doc/upstream/libpng-1.6.58-pngwtran-functions.tsv
EXPECTED_FUNCTIONS=5

fail() {
    printf 'libpng4cj pngwtran inventory: %s\n' "$1" >&2
    exit 1
}

[ -f "$SOURCE" ] || fail "missing vendored pngwtran.c"
mkdir -p "$(dirname "$OUTPUT")"

awk '
    /^png_[A-Za-z0-9_]+\(/ {
        name = $0
        sub(/\(.*/, "", name)
        printf "%d\t%s\n", NR, name
    }
' "$SOURCE" > "$OUTPUT"

function_count=$(wc -l < "$OUTPUT" | tr -d ' ')
[ "$function_count" = "$EXPECTED_FUNCTIONS" ] || \
    fail "expected $EXPECTED_FUNCTIONS functions, found $function_count"

printf 'libpng4cj pngwtran inventory: functions=%s\n' "$function_count"
printf 'libpng4cj pngwtran inventory: output=%s\n' "$OUTPUT"
