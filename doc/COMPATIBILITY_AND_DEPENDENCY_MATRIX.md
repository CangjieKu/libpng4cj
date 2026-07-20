# Compatibility And Dependency Matrix

[English](COMPATIBILITY_AND_DEPENDENCY_MATRIX.md) | [简体中文](zh-CN/COMPATIBILITY.md)

## Capability Matrix

| Area | Status | Notes |
| --- | --- | --- |
| PNG decode | Supported | Non-interlaced and Adam7, packed rows, RGBA8/RGBA16, simplified image buffers |
| PNG encode | Supported | Non-interlaced and Adam7, packed rows, row-at-a-time and sink output |
| Progressive read | Supported | Fragmented feed, pause/resume, info/row/end callbacks |
| Read transforms | `45/45` source functions translated | Includes gamma, background, alpha, packing, expansion, quantize, and channel transforms |
| Write transforms | `5/5` source functions translated | Includes packing, swapping, shifting, alpha, BGR, and monochrome transforms |
| Standard metadata | Supported | Core color, display, text, time, calibration, palette, ICC retention, and unknown chunks |
| Simplified API | Supported | Memory, file, and stream input/output; direct, linear, and colormap buffers |
| C ABI | Preview, `134/258` symbols | Complete verification currently limited to macOS arm64 |

Function translation counts describe the `pngrtran.c` and `pngwtran.c` source
bodies. They do not represent complete classic API or ABI coverage.

## Native Dependencies

| Dependency | Requirement | Reason |
| --- | --- | --- |
| Cangjie SDK | `1.0.5` or newer | Package minimum |
| zlib | System development library | PNG IDAT and compressed metadata |
| C compiler | Optional | Required only for C ABI consumers |

The final Cangjie executable must link `-lz`. This is required even when
libpng4cj is consumed as a static cjpm dependency.

## Verified Environments

| Platform | Toolchain | Verified surface |
| --- | --- | --- |
| macOS arm64 | Cangjie `1.1.3` | doctor, build, `504/504` tests, Cangjie consumer, original and relocated C ABI consumers |
| Debian 13 amd64 | Owner-provided native receipt | build, `504/504` tests, Cangjie consumer |

These receipts demonstrate the listed environments. They are not a general
certification for every operating system, architecture, libc, zlib, or Cangjie
toolchain combination.

## Known Boundaries

- The C ABI is not yet a drop-in replacement for complete `libpng16`.
- Non-macOS C ABI artifacts and receipts are not yet provided.
- ICC profiles are parsed, validated, and retained, but ICC pixel color
  conversion is not implemented.
- Images above 100 MB and concurrent stress workloads are not certified.
- zlib remains an external dependency by design.
