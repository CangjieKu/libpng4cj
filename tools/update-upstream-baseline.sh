#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
UPSTREAM=$ROOT/vendor/libpng-1.6.58
OUTPUT=$ROOT/doc/upstream
SYMBOLS=$OUTPUT/libpng-1.6.58-symbols.txt
HEADERS=$OUTPUT/libpng-1.6.58-public-headers.sha256
SOURCES=$OUTPUT/libpng-1.6.58-source-files.txt
EXPECTED_SYMBOLS=258

fail() {
    printf 'libpng4cj baseline: %s\n' "$1" >&2
    exit 1
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        fail "sha256sum or shasum is required"
    fi
}

[ -f "$UPSTREAM/png.h" ] || fail "missing vendored png.h"
[ -f "$UPSTREAM/scripts/symbols.def" ] || fail "missing vendored symbols.def"
mkdir -p "$OUTPUT"

awk '/^[[:space:]]+png_[A-Za-z0-9_]+[[:space:]]+@[0-9]+/ { print $1 }' \
    "$UPSTREAM/scripts/symbols.def" > "$SYMBOLS"

symbol_count=$(wc -l < "$SYMBOLS" | tr -d ' ')
[ "$symbol_count" = "$EXPECTED_SYMBOLS" ] || \
    fail "expected $EXPECTED_SYMBOLS symbols, found $symbol_count"

{
    for header in png.h pngconf.h scripts/pnglibconf.h.prebuilt; do
        digest=$(sha256_file "$UPSTREAM/$header")
        printf '%s  %s\n' "$digest" "$header"
    done
} > "$HEADERS"

find "$UPSTREAM" -type f \( -name 'png*.c' -o -name 'png*.h' \) -print \
    | sed "s|$UPSTREAM/||" \
    | sort > "$SOURCES"

printf 'libpng4cj baseline: symbols=%s\n' "$symbol_count"
printf 'libpng4cj baseline: output=%s\n' "$OUTPUT"

sh "$ROOT/tools/update-pngrtran-inventory.sh"
