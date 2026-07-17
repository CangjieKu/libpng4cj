# Compatibility And Dependency Matrix

## Current Capability Boundary

| Capability | Status | Current truth |
| --- | --- | --- |
| ICC color application | Pending | iCCP bytes and validated profile metadata are retained; pixel colors are not converted |
| Gamma correction | Implemented for current read pipeline | gAMA/sRGB/cHRM metadata, packed/8/16-bit correction, gamma-aware RGB-to-gray, background composition, and alpha-mode paths execute through frozen direct/linear tables; ICC pixel color conversion remains outside libpng parity |
| Background composition | Implemented for current read pipeline | bKGD, fixed/floating application state, palette and non-palette composition, depth normalization, Screen/File/Unique gamma snapshots, alpha modes, and post-Compose Strip Alpha execute in initialized row and whole-image paths |
| Standard ancillary metadata | Implemented for current read pipeline | cICP, cLLI, mDCV, eXIf, hIST, oFFs, pCAL, sCAL, and multiple sPLT entries are validated and retained through raw/RGBA result surfaces; recognized eXIf remains available after IDAT |
| Adam7 decoding | Implemented for whole-image read | Exact seven-pass geometry, pass-local filter reversal, packed/8/16-bit reconstruction, metadata retention, and RGBA8/RGBA16 transforms are available through the generic decode APIs; progressive pass callbacks remain pending |
| Progressive reading | Partial buffered feed facade | `PngProgressiveReader` accepts arbitrary bounded input splits and delivers ordered native info/row/end callbacks at finalization for non-interlaced and Adam7 input; streaming zlib windows, pass-row timing, row combine, and pause/resume remain pending |
| Write API | Pending | PNG encoding and write-side transforms are not implemented |
| C ABI compatibility | Pending | No `libpng16` headers, exported symbols, or callback/longjmp bridge is shipped |
| User callbacks | Partial | Native Cangjie read user-transform callbacks execute with row/pass context and copy ownership; custom IO, warning/error, allocator, and chunk callback families remain open |

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
- Adam7 whole-image decoding is covered across packed grayscale/indexed,
  8-bit RGB/RGBA, and 16-bit Gray Alpha/RGBA PNGSuite pairs. Progressive
  delivery, row-combine callbacks, and pause/resume remain open. ICC pixel
  color conversion is not a libpng behavior and no broader color-management
  engine is claimed.
