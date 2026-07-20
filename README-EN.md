<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-libpng4cj-ff6b35?style=for-the-badge&labelColor=1a1a2e" alt="libpng4cj" />
  <img src="https://img.shields.io/badge/version-0.8.1-blue?style=for-the-badge&labelColor=1a1a2e" alt="Version" />
  <img src="https://img.shields.io/badge/license-Libpng--2.0-green?style=for-the-badge&labelColor=1a1a2e" alt="License" />
</p>

<div align="center">
<span style="font-weight:300;font-size:38px">libpng4cj</span><br/>
<span style="font-weight:100;font-size:26px">Native PNG codecs and libpng compatibility for Cangjie</span>
<p align="center">
  <strong>A Cangjie PNG library for reading, writing, pixel transforms, metadata, and progressive processing</strong><br>
  <sub>Adam7 · Progressive · Gamma · Metadata · Streaming · C ABI Preview</sub>
</p>
</div>

<p align="center">
  <a href="https://gitcode.com/cinyu/libpng4cj">Source repository</a> ·
  <a href="doc/README-EN.md">Documentation</a> ·
  <a href="doc/feature_api.md">API guide</a> ·
  <a href="doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md">Compatibility matrix</a> ·
  <a href="README.md">简体中文</a>
</p>

> Documentation version: `0.8.1`

libpng4cj is a PNG codec for Cangjie. It uses libpng `1.6.58` as its behavioral
reference while implementing PNG parsing, filters, pixel transforms, metadata,
progressive reading, and encoding in Cangjie. zlib remains the compression
dependency.

Version `0.8.1` provides native read and write APIs for Cangjie applications.
The native consumer path has been verified on macOS arm64 and Debian 13 amd64.
The repository also ships a strict C11-tested libpng16 C ABI subset for macOS
arm64. That ABI remains a preview and is not a complete libpng16 replacement.

## Supported Features

| Area | Current support |
| --- | --- |
| Decoding | All PNG color types, 1/2/4/8/16-bit depths, all five filters, non-interlaced and Adam7 |
| Pixel output | Packed rows, RGBA8, RGBA16, common Gray/RGB/BGR/Alpha layouts, linear UInt16, and indexed color |
| Color processing | Gamma correction, background composition, RGB/Gray conversion, alpha modes, and common read transforms |
| Metadata | PLTE/tRNS, gAMA/cHRM/sRGB/sBIT/bKGD/pHYs, iCCP, text, time, and several standard ancillary chunks |
| Progressive reading | Incremental input, info/row/end callbacks, Adam7 pass information, pause, and resume |
| Encoding | Whole-image, row-at-a-time, incremental IDAT, Adam7, filter and compression control, metadata, and unknown chunks |
| Simplified API | Memory, files, caller-managed streams, direct8, linear16, colormap, and positive or negative strides |
| C ABI | `134/258` default public symbols, with the complete current receipt limited to macOS arm64 |
| ICC | iCCP profiles are retained and validated; ICC pixel color conversion is not performed |

See the [Compatibility and Dependency Matrix](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
for detailed status and [Feature API](doc/feature_api.md) for the API index.

## Requirements

- `cjc` and `cjpm`; the package declares `1.0.5` as its minimum version
- zlib development and runtime libraries
- a system C compiler for the C ABI preview

The current complete local verification uses Cangjie `1.1.3`, macOS arm64, and
zlib `1.2.12`. A project-owner real-host receipt also confirms the native build,
test, and standalone consumer on Debian 13 amd64.

Check the environment first:

```sh
./tools/doctor.sh
```

cjpm does not propagate static-library link options to the final executable, so
consumer executables must link `-lz` explicitly.

## Add The Dependency

Add libpng4cj to the final executable project's `cjpm.toml`:

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

Production projects should pin a verified tag or commit. The public package
root is `libpng4cj`:

```cangjie
import libpng4cj.*
```

## Read A PNG

Read a file into RGBA8 rows:

```cangjie
import std.fs.*
import libpng4cj.*

main(): Int64 {
    let encoded = File.readFrom("input.png")
    let image = decodePngRgba8(encoded, Scale)

    println("${image.ihdr.width}x${image.ihdr.height}")
    println("rows: ${image.rowCount()}")
    return 0
}
```

`Scale` performs exact 16-to-8-bit sample scaling. For inputs no deeper than
8 bits, `decodePngRgba8(encoded)` is also available.

Use the simplified API for application-level file IO:

```cangjie
import libpng4cj.*

main(): Int64 {
    let reader = beginPngImageReadFromFile("input.png")
    let image = reader.finishRead(ImageRgba8)

    writePngImageToFile(image, "output.png", Adam7)
    return 0
}
```

The same API family includes:

- `beginPngImageReadFromMemory` / `writePngImageToMemory`
- `beginPngImageReadFromStream` / `writePngImageToStream`
- `finishReadLinear` / `writePngLinearImageToMemory`
- `finishReadColormap` / `writePngColormapImageToMemory`
- `PngProgressiveReader`
- `PngWriteSession` / `PngRowWriteSession`

## Build And Verify

Regular development commands:

```sh
cjpm build
cjpm test

cd test/consumer
cjpm run
```

The canonical automation entry runs the doctor, frozen inventory checks,
build, unit tests, and standalone consumer:

```sh
./tools/ci.sh
```

The repository includes `.github/workflows/cangjie-ci.yml`. Public hosted
runners do not currently provide the required Cangjie SDK, so the workflow
targets a self-hosted runner labeled `cangjie` and `posix`. See
[Continuous Integration](doc/CI.md) for runner requirements.

The current suite passes `504/504` tests. The standalone consumer includes a
complete decode -> encode -> decode pixel roundtrip using a checked-in Adam7
fixture.

## Upstream Mapping

The project freezes the following upstream reference:

- libpng `1.6.58`
- tag `v1.6.58`
- commit `3061454d980de7d53608f594194cfac722721d2a`
- default public symbol inventory: `258`
- `pngrtran.c`: `45/45` top-level functions mapped to Cangjie implementations
- `pngwtran.c`: `5/5` top-level functions mapped to Cangjie implementations

Per-function status is recorded in the
[read transform ledger](doc/PNG_RTRAN_TRANSLATION_LEDGER.md) and
[write transform ledger](doc/PNG_WTRAN_TRANSLATION_LEDGER.md). These counts
describe source-function coverage, not complete C ABI coverage.

## C ABI Preview

Run the complete C ABI verification on macOS arm64:

```sh
./tools/test_abi_preview.sh
```

The script builds the Cangjie `@C` dylib, verifies frozen symbol manifests,
compiles strict C11 consumers with warnings as errors, and reruns them from the
original and relocated library locations. Current coverage includes the
`png_image` memory/file/stdio subset, classic read and metadata getters,
allocator/error/IO lifecycle, and write owners with raw chunks, CRC, and flush.

A C process must call `InitCJRuntime`, `LoadCJLibraryWithInit`, and
`FiniCJRuntime` as required by the Cangjie toolchain. See
[C ABI Surfaces](doc/ABI_PREVIEW.md) for the complete contract.

## Current Limits

- The C ABI does not yet cover every default libpng16 symbol or behavior.
- `setjmp` / `longjmp`, several callbacks, and raw user-pointer families remain open.
- Classic write-info/row/image and remaining setter/state APIs are incomplete.
- ICC-profile-driven pixel color conversion is not implemented.
- Linux, Windows, HarmonyOS, and OpenHarmony C ABI artifacts are not yet verified.
- There is no throughput certification above 100 MB, concurrent stress proof,
  or stable ABI commitment yet.
- Version `0.8.1` is not an LTS release.

## Project Layout

```text
libpng4cj/
├── src/                         # Cangjie implementation and cjpm unit tests
├── abi/                         # C ABI headers and frozen symbol manifests
├── doc/                         # Bilingual API, compatibility, CI, and upstream mapping
├── test/consumer/               # standalone Cangjie consumer
├── test/abi_consumer/           # strict C11 consumers
├── tools/                       # doctor, CI, inventory, and ABI verification
└── vendor/libpng-1.6.58/        # frozen upstream reference and behavior oracle
```

## License

libpng4cj is licensed under [Libpng-2.0](LICENSE). The complete upstream source
is retained for licensing, implementation comparison, and oracle tests. Runtime
PNG behavior is provided by the Cangjie implementation under `src/`.

- [README.OpenSource](README.OpenSource)
- [upstream libpng license](vendor/libpng-1.6.58/LICENSE)
- [pnggroup/libpng](https://github.com/pnggroup/libpng)
