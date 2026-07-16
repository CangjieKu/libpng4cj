# Changelog

## Unreleased

- Convert `README.OpenSource` to the repository-required JSON dependency list,
  covering the frozen libpng source and external system zlib dependency.
- Add a local Cangjie/zlib doctor and a public compatibility, capability,
  platform, large-input, and concurrency evidence matrix.
- Use the direct `src/` package root so consumers import `libpng4cj.*`.
- Add a standalone external-consumer project under `test/consumer`.
- Organize public design, API, porting, and upstream baseline material under
  `doc/`.
- Snapshot and compose initialized Invert Mono, Invert Alpha, significant-bit
  Unshift, BGR, Filler/Add Alpha, and Swap Alpha stages after Expand16,
  including packed and 8/16-bit network-order behavior, semantic-alpha
  swapping, copy ownership, and whole-image transformed-byte limits.
- Translate `pngtrans.c::png_do_bgr` as direct `pngDoBgr` row behavior for
  natural RGB/RGBA 8-bit and network-order 16-bit rows.
- Translate `pngtrans.c::png_do_invert` as direct `pngDoInvertMono` behavior for
  packed/8/16-bit Gray and 8/16-bit Gray Alpha rows.
- Translate read-side `pngtrans.c::png_set_packing`, snapshot it in one-shot
  initialization, and execute direct `pngDoUnpack` after Unshift and before BGR
  with exact row growth and transformed-byte limiting.
- Translate read-side `pngtrans.c::png_set_packswap` and `png_do_packswap`,
  reverse 1/2/4-bit sample groups across every stored byte, and execute the
  immutable stage after BGR and before Filler; prior Unpack makes PackSwap an
  exact validated no-op after output depth reaches 8.
