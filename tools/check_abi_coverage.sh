#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
UPSTREAM="$ROOT/doc/upstream/libpng-1.6.58-symbols.txt"
SUPPORTED="$ROOT/doc/upstream/libpng4cj-1.6.58-supported-symbols.txt"
REMAINING="$ROOT/doc/upstream/libpng4cj-1.6.58-remaining-symbols.txt"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/libpng4cj-coverage.XXXXXX")

trap 'rm -rf "$WORK"' EXIT HUP INT TERM

awk 'NF && $1 !~ /^#/ { print $1 }' "$ROOT"/abi/symbols/*.txt |
    sort -u > "$WORK/manifest-symbols.txt"
sort -u "$UPSTREAM" > "$WORK/upstream-symbols.txt"
comm -12 "$WORK/upstream-symbols.txt" "$WORK/manifest-symbols.txt" \
    > "$WORK/supported-symbols.txt"
comm -23 "$WORK/upstream-symbols.txt" "$WORK/manifest-symbols.txt" \
    > "$WORK/remaining-symbols.txt"

diff -u "$SUPPORTED" "$WORK/supported-symbols.txt"
diff -u "$REMAINING" "$WORK/remaining-symbols.txt"

supported_count=$(wc -l < "$WORK/supported-symbols.txt" | tr -d ' ')
remaining_count=$(wc -l < "$WORK/remaining-symbols.txt" | tr -d ' ')
upstream_count=$(wc -l < "$WORK/upstream-symbols.txt" | tr -d ' ')

[ "$supported_count" = "180" ]
[ "$remaining_count" = "78" ]
[ "$upstream_count" = "258" ]

printf 'libpng4cj ABI coverage: supported=%s/%s remaining=%s\n' \
    "$supported_count" "$upstream_count" "$remaining_count"
