# Compatibility And Dependency Matrix

## Current Capability Boundary

| Capability | Status | Current truth |
| --- | --- | --- |
| ICC color application | Pending | iCCP bytes and validated profile metadata are retained; pixel colors are not converted |
| Gamma correction | Partial | gAMA/sRGB/cHRM metadata is retained; initialized packed/8/16-bit row correction and gamma-aware RGB-to-gray execute through frozen direct/linear tables; background/alpha-mode and ICC color application remain open |
| Background composition | Partial | bKGD and fixed/floating application state are retained; initialization covers opaque cancellation, palette/sub-byte expansion, exact Expand16/16-to-8 depth normalization, Screen/File/Unique gamma derivation, original/linear/screen snapshots, and Compose-driven linear tables; pixel composition and palette mutation remain open |
| Adam7 decoding | Pending | Adam7 IHDR values are recognized; interlaced row execution is not implemented |
| Progressive reading | Pending | No progressive state machine or callback surface is implemented |
| Write API | Pending | PNG encoding and write-side transforms are not implemented |
| C ABI compatibility | Pending | No `libpng16` headers, exported symbols, or callback/longjmp bridge is shipped |
| User callbacks | Partial | Native Cangjie read user-transform callbacks execute with row/pass context and copy ownership; custom IO, warning/error, allocator, and chunk callback families remain open |

The read-transform ledger currently records `33/45` translated, `8/45`
partial, and `4/45` pending top-level `pngrtran.c` functions. The complete
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
- Adam7 remains a missing capability. Gamma support is partial and limited to
  the implemented initialized row paths; broader color-management composition
  remains explicitly pending.
