# libpng4cj ABI Preview

LP-S008A adds a macOS arm64 preview C surface alongside the existing native
Cangjie package. It does not replace the package coordinate or change the
normal `cjpm build` static-library output.

Build and verify:

```sh
./tools/test_abi_preview.sh
```

The generated directory contains:

- `libpng4cj_preview.dylib`: direct Cangjie `@C` implementation
- `include/libpng4cj_preview.h`: preview API contract
- `abi-consumer`: standalone C consumption proof

The v1 preview supports signature checks and caller-owned RGBA8 decode,
including Adam7 input and explicit 16-to-8 scaling. All public ABI functions
are implemented directly in Cangjie. The decoder reports the required buffer
size before the caller supplies storage, and Cangjie exceptions are converted
to deterministic status and message outputs.

A C process must initialize the Cangjie runtime before calling a Cangjie
dynamic library. The standalone consumer demonstrates the toolchain-required
`InitCJRuntime`, `LoadCJLibraryWithInit`, call, and `FiniCJRuntime` lifecycle;
that host bootstrap is not a libpng4cj C implementation layer.

The exact exported public symbols are frozen in
`abi/symbols/libpng4cj-preview-v1.txt`. This preview is not the final libpng16
drop-in ABI, a portable release, or an LTS artifact.
