# Compatibility And Dependency Matrix

## Current Capability Boundary

| Capability | Status | Current truth |
| --- | --- | --- |
| ICC color application | Pending | iCCP bytes and validated profile metadata are retained; pixel colors are not converted |
| Gamma correction | Implemented for current read pipeline | gAMA/sRGB/cHRM metadata, packed/8/16-bit correction, gamma-aware RGB-to-gray, background composition, and alpha-mode paths execute through frozen direct/linear tables; ICC pixel color conversion remains outside libpng parity |
| Background composition | Implemented for current read pipeline | bKGD, fixed/floating application state, palette and non-palette composition, depth normalization, Screen/File/Unique gamma snapshots, alpha modes, and post-Compose Strip Alpha execute in initialized row and whole-image paths |
| Standard ancillary metadata | Implemented for current read pipeline | cICP, cLLI, mDCV, eXIf, hIST, oFFs, pCAL, sCAL, and multiple sPLT entries are validated and retained through raw/RGBA result surfaces; recognized eXIf remains available after IDAT |
| Adam7 decoding | Implemented for whole-image and progressive read | Exact seven-pass geometry, pass-local filter reversal, packed/8/16-bit reconstruction, metadata retention, RGBA8/RGBA16 transforms, progressive pass context, and owned canonical row combination are available |
| Progressive reading | Implemented native incremental read path | `PngProgressiveReader` incrementally parses signature/chunk/CRC state, streams IDAT through bounded zlib windows, emits early info and rows, reports exact Adam7 pass rows, and supports callback-driven pause/resume with unconsumed-byte accounting |
| Write API | Native whole-image, row-at-a-time, simplified native memory, and `png_image_write_to_memory` subset | `PngWriteSession`, `PngRowWriteSession`, `encodePngPacked`, `encodePngPackedAdam7`, and `PngWriteMetadata` emit canonical core, typed standard metadata, and policy-controlled copy-owned unknown chunks with bounded transforms, filtering, compression, metadata, and output; `PngWriteControlState` freezes filter subsets plus zlib level/memory/window/method/strategy/buffer policy and feeds one configured deflater across whole-image, deferred, early, and Adam7 paths; simplified writers add nine common 8-bit layouts, nine host-numeric linear UInt16 layouts, and six indexed colormap entry layouts; the C memory ABI adds upstream-shaped size-query/fill behavior and sRGB/non-sRGB metadata selection for common direct, linear, and RGB-family colormap formats. C `FILE*`/stdio and complete write ABI parity remain open |
| Simplified image API | Native facades plus upstream-compatible `png_image` memory ABI subset implemented | `PngImage` provides copy-owned begin/finish/free state, diagnostics, direct 8-bit, linear UInt16, colormap, signed-stride, file, and caller-managed stream surfaces. The exported memory ABI adds the LP64 `png_image` layout, simplified constants and geometry macros, tRNS-aware begin facts, cICP/mDCV/sRGB/cHRM colorspace flags, one-decode opaque ownership handoff, direct/linear/colormap finish, the untagged-16-bit sRGB assumption for linear reads, associated-alpha reads, solid or caller-buffer background composition, Adam7 input, and deterministic cleanup. Exact gamma-aware direct/color-map pixel parity and C stdio entry points remain open |
| C ABI compatibility | Five-symbol preview plus four exact `png_image` memory symbols | Direct Cangjie `@C` exports include the original checked preview functions and exact `png_image_begin_read_from_memory`, `png_image_finish_read`, `png_image_free`, and `png_image_write_to_memory`; strict C11 layout, symbol, lifecycle, format, malformed/limit, write-size, and relocated loading proof passes on macOS arm64. Remaining default-config symbols, callbacks/longjmp, stdio, canonical libpng16 packaging, and cross-platform receipts remain open |
| User callbacks | Partial | Native Cangjie read and write user transforms execute with explicit context and copy ownership, and native write/flush sink callbacks support live replacement and failed-state guards; custom read IO, warning/error, allocator, unknown-chunk, raw C callback, and longjmp families remain open |

The read-transform ledger currently records `45/45` translated, `0/45`
partial, and `0/45` pending top-level `pngrtran.c` functions. The complete
source-backed status is maintained in
[`PNG_RTRAN_TRANSLATION_LEDGER.md`](PNG_RTRAN_TRANSLATION_LEDGER.md).

## Native Dependency Matrix

libpng4cj intentionally keeps zlib external, matching upstream libpng. The
static library uses the zlib API through FFI, and the final executable must link
`-lz` because cjpm static-library link options are not transitive.

| Host | zlib source | Receipt | Status |
| --- | --- | --- | --- |
| macOS arm64 | System SDK/Homebrew-visible linker surface | zlib `1.2.12`, clean build/test/consumer | Verified on current host |
| Linux x86_64/aarch64 | Distribution `zlib` development/runtime package | Not collected | Pending |
| Windows x86_64/aarch64 | Explicit zlib import/static library and cjpm link configuration | Not collected | Pending |
| HarmonyOS/OpenHarmony | Target-provided or packaged zlib artifact | Not collected | Pending |

Run the local preflight before building:

```sh
./tools/doctor.sh
cjpm build
cjpm test
```

`doctor.sh` verifies the Cangjie commands, reports the host/toolchain, checks
zlib through `pkg-config` or a native `-lz` link-and-run probe, and confirms the
vendored upstream license surface.

## Cangjie Toolchain Matrix

| Version | Evidence | Support wording |
| --- | --- | --- |
| 1.1.0 | Current macOS arm64 build, test, and consumer receipts | Declared and locally verified |
| 1.0.5 | Repository-administrator audit reports successful compile/run | Observed externally; local reproduction and regression receipt pending |

The package keeps `cjc-version = "1.1.0"` until a reproducible 1.0.5 toolchain
receipt is checked in or otherwise file-backed. The administrator observation
is useful compatibility evidence, but it is not silently promoted into the
declared minimum.

## Coverage Boundary

- Inputs above 100 MB do not yet have a committed fixture. Compressed,
  inflated, chunk, dimension, and transformed-output limits are configurable
  and have focused boundary tests, but large-file throughput is not certified.
- Decoder sessions and transform state are instance-owned with no package-level
  mutable decode state. Concurrent stress and race testing are still pending.
- Adam7 whole-image and progressive decoding are covered across packed,
  8-bit, and 16-bit rows. Progressive proof includes one-byte and irregular
  feeds, split chunk framing and zlib windows, all seven passes, owned row
  combination, early callbacks, CRC/limit failures, and pause/resume without
  duplicate delivery. ICC pixel color conversion is not a libpng behavior and
  no broader color-management engine is claimed.
