# libpng4cj

English | [简体中文](README.md)

libpng4cj is a PNG read/write library for Cangjie and a full-port program based
on libpng `1.6.58`. PNG parsing, filters, pixel transforms, metadata,
progressive reading, and encoding are implemented in Cangjie. zlib remains an
external compression dependency, matching the upstream libpng boundary.

The current version is `0.2.0 preview`. The native Cangjie API covers common
read and write workflows. A tested libpng16 ABI subset is also available on
macOS arm64. This version is not a complete libpng16 replacement, an LTS
release, or a cross-platform binary distribution.

## Capabilities

| Capability | 0.2.0 preview status |
| --- | --- |
| PNG decoding | All PNG color types, 1/2/4/8/16-bit depths, all five filters, and Adam7 |
| Pixel output | Packed rows, RGBA8, RGBA16, common Gray/RGB/BGR/Alpha layouts, linear UInt16, and indexed color |
| Color processing | Gamma correction, background composition, RGB/Gray conversion, alpha modes, and common read transforms are connected to the current pipeline |
| Metadata | PLTE/tRNS, gAMA/cHRM/sRGB/sBIT/bKGD/pHYs, iCCP, text, time, and multiple standard ancillary chunks |
| Progressive reading | Incremental input, early info/row callbacks, Adam7 pass context, pause, and resume |
| PNG encoding | Whole-image, row-at-a-time, incremental IDAT, Adam7, filter/compression controls, metadata, and unknown chunks |
| Simplified API | Memory, files, and caller-managed streams with direct8, linear16, colormap, and positive/negative strides |
| C ABI | Preview facade, `png_image` memory/file/stdio subset, classic utilities/read handles, custom/stdio `png_read_info`, core IHDR, fixed/floating scalar and extended metadata getters, easy-access getters, and raw row/image/read-end subset on macOS arm64 |
| ICC | iCCP profiles are retained and validated; ICC pixel color conversion is not performed |

See the [Compatibility and Dependency Matrix](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
for the detailed boundary.

## Requirements

- `cjpm` / `cjc`: declared minimum version `1.0.5`
- current complete local receipt: Cangjie `1.1.0` on `aarch64-apple-darwin`
- zlib development and runtime libraries
- a system C compiler for the macOS ABI preview

Static-library link options are not propagated to the final executable, so a
consumer executable must link `-lz` explicitly.

Run the environment check first:

```sh
./tools/doctor.sh
```

## Add The Dependency

Add the following to the final executable project's `cjpm.toml`:

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

The public package root is `libpng4cj`; there is no repeated
`libpng4cj.libpng4cj.*` prefix:

```cangjie
import libpng4cj.*
```

Production consumers should pin a verified tag or commit in their dependency
configuration.

## Quick Read

Read a PNG and convert it to RGBA8:

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

`Scale` performs exact 16-to-8-bit scaling. For inputs no deeper than 8 bits,
`decodePngRgba8(encoded)` is also available.

## Simplified Read And Write

The simplified API is intended for application-level memory, file, and stream
workflows:

```cangjie
import libpng4cj.*

main(): Int64 {
    let reader = beginPngImageReadFromFile("input.png")
    let image = reader.finishRead(ImageRgba8)

    writePngImageToFile(image, "output.png", Adam7)
    return 0
}
```

Related entry points include:

- `beginPngImageReadFromMemory` / `writePngImageToMemory`
- `beginPngImageReadFromStream` / `writePngImageToStream`
- `finishReadLinear` / `writePngLinearImageToMemory`
- `finishReadColormap` / `writePngColormapImageToMemory`
- `PngProgressiveReader`
- `PngWriteSession` / `PngRowWriteSession`

See [Feature API](doc/feature_api.md) for the complete API index.

## Build And Test

```sh
./tools/doctor.sh
cjpm build
cjpm test
```

Run the standalone Cangjie consumer:

```sh
cd test/consumer
cjpm run
```

Refresh and verify the frozen upstream baseline:

```sh
./tools/update-upstream-baseline.sh
```

The current baseline is:

- libpng `1.6.58`
- tag `v1.6.58`
- commit `3061454d980de7d53608f594194cfac722721d2a`
- default public-symbol inventory: `258`
- current frozen ABI manifests cover `108/258` upstream default symbols
- top-level `pngrtran.c` function inventory: `45`

## C ABI Preview

On macOS arm64, run the complete ABI preview acceptance suite:

```sh
./tools/test_abi_preview.sh
```

It performs the following checks:

- builds a dylib with direct Cangjie `@C` exports
- verifies frozen exported-symbol manifests
- compiles strict C11 consumers with `-Wall -Wextra -Werror`
- exercises the preview facade, `png_image` memory/file/stdio subset,
  stateless classic utilities, read/info handle lifecycle, warning callbacks,
  fatal error subprocess boundaries, custom allocator ownership, and
  custom/stdio `png_read_info`, core IHDR getters, fixed/floating gAMA and
  cHRM and cHRM XYZ, sRGB/sBIT/bKGD/pHYs/PLTE/tRNS,
  oFFs/cICP/cLLI/mDCV, pCAL/sCAL/tIME/text/eXIf/iCCP/hIST/sPLT/unknown/rows
  getters, version strings, get-valid/signature/physical conversion getters,
  and raw row/image/read-end
- relocates the dylib and reruns every consumer on the same host

A C process must initialize and finalize the Cangjie runtime as required by the
toolchain. The sample consumer demonstrates the complete `InitCJRuntime`,
`LoadCJLibraryWithInit`, and `FiniCJRuntime` lifecycle.

See [C ABI Surfaces](doc/ABI_PREVIEW.md) for details.

## Compatibility Boundary

`0.2.0 preview` does not claim:

- complete default-config libpng16 symbol or behavior compatibility
- transformed rows, Adam7 pass/display combination, high-level rows population,
  remaining runtime/context getters, complete read-end metadata, write state,
  and the remaining `png_struct` / `png_info` state API
- `setjmp` / `longjmp`, chunk/row-status callback families, and the remaining
  raw user-pointer families
- ICC-profile-driven pixel color conversion
- verified Linux, Windows, HarmonyOS, or OpenHarmony ABI artifacts
- throughput certification for images above 100 MB or concurrent stress proof
- LTS status, a stable ABI, or a production release commitment

These limits do not remove the verified native Cangjie main paths, but C ABI
and cross-platform consumers should review the
[Compatibility and Dependency Matrix](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
before distribution.

## Project Layout

```text
libpng4cj/
├── src/                         # Cangjie implementation and cjpm unit tests
├── abi/                         # C ABI headers and frozen symbol manifests
├── doc/                         # API, compatibility, and upstream mapping docs
├── test/consumer/               # standalone Cangjie consumer
├── test/abi_consumer/           # strict C11 consumers
├── tools/                       # doctor, baseline, and ABI verification tools
└── vendor/libpng-1.6.58/        # frozen upstream reference and behavior oracle
```

## Upstream And License

libpng4cj uses libpng `1.6.58` as its frozen translation baseline. The complete
upstream source is retained for licensing, implementation comparison, and
oracle tests. Product implementation lives under `src/`; the vendored C source
does not provide PNG behavior at runtime.

- project license: [Libpng-2.0](LICENSE)
- upstream license: [vendor/libpng-1.6.58/LICENSE](vendor/libpng-1.6.58/LICENSE)
- open-source dependency manifest: [README.OpenSource](README.OpenSource)
- upstream repository: [pnggroup/libpng](https://github.com/pnggroup/libpng)
