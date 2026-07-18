#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)

fail() {
    printf 'libpng4cj doctor: FAIL: %s\n' "$1" >&2
    exit 1
}

note() {
    printf 'libpng4cj doctor: %s\n' "$1"
}

command -v cjc >/dev/null 2>&1 || fail "cjc is not available on PATH"
command -v cjpm >/dev/null 2>&1 || fail "cjpm is not available on PATH"

note "host=$(uname -s)-$(uname -m)"
note "cjc=$(cjc --version | sed -n '1p')"
note "cjpm=$(cjpm --version | sed -n '1p')"

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists zlib; then
    note "zlib=$(pkg-config --modversion zlib) via pkg-config"
else
    command -v cc >/dev/null 2>&1 || \
        fail "zlib was not found through pkg-config and cc is unavailable"

    probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/libpng4cj-zlib.XXXXXX")
    trap 'rm -rf "$probe_dir"' EXIT HUP INT TERM
    printf '%s\n' \
        'extern const char *zlibVersion(void);' \
        'int main(void) { return zlibVersion()[0] == 0; }' \
        > "$probe_dir/zlib_probe.c"
    if ! cc "$probe_dir/zlib_probe.c" -lz -o "$probe_dir/zlib_probe"; then
        fail "the native linker cannot resolve zlib with -lz"
    fi
    "$probe_dir/zlib_probe" || fail "the linked zlib probe did not run"
    note "zlib=link-and-run probe passed"
fi

[ -f "$ROOT/vendor/libpng-1.6.58/LICENSE" ] || \
    fail "vendored libpng license is missing"
[ -f "$ROOT/README.OpenSource" ] || fail "README.OpenSource is missing"
[ -f "$ROOT/abi/include/png.h" ] || fail "png_image ABI header is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-png-image-memory-v1.txt" ] || \
    fail "png_image ABI symbol manifest is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-png-image-file-stdio-v1.txt" ] || \
    fail "png_image file/stdio ABI symbol manifest is missing"
[ -f "$ROOT/test/abi_consumer/png_image_file_stdio.c" ] || \
    fail "png_image file/stdio C consumer is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-stateless-v1.txt" ] || \
    fail "classic stateless ABI symbol manifest is missing"
[ -f "$ROOT/test/abi_consumer/png_classic_stateless.c" ] || \
    fail "classic stateless ABI C consumer is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-read-handle-v1.txt" ] || \
    fail "classic read-handle ABI symbol manifest is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-error-v1.txt" ] || \
    fail "classic error ABI symbol manifest is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-memory-v1.txt" ] || \
    fail "classic memory ABI symbol manifest is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-read-io-v1.txt" ] || \
    fail "classic read IO ABI symbol manifest is missing"
[ -f "$ROOT/abi/symbols/libpng4cj-classic-core-info-v1.txt" ] || \
    fail "classic core info ABI symbol manifest is missing"
[ -f "$ROOT/test/abi_consumer/png_classic_read_handle.c" ] || \
    fail "classic read-handle ABI C consumer is missing"
[ -f "$ROOT/test/abi_consumer/png_classic_core_info.c" ] || \
    fail "classic core info ABI C consumer is missing"

note "upstream=libpng-1.6.58 reference present"
note "png_image=memory/file/stdio ABI header and symbol manifests present"
note "classic-abi=stateless, read-handle, error, memory, read-IO, and core-info manifests/consumers present"
note "PASS"
