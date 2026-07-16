# Changelog

## Unreleased

- Translate fixed gamma flag/range validation and lifecycle-gated file/screen
  setter state with explicit application-error and warning facts.
- Translate immutable gamma-value initialization with file/screen resolution,
  reciprocal fallback, identity-gamma reset, and correction classification.
- Translate fixed-point reciprocal and immutable file-gamma precedence
  resolution across explicit, chunk, default, and screen sources.
- Translate the frozen fixed-point multiply/divide substrate, gamma
  significance predicate, and direct `png_gamma_threshold` behavior.
- Translate the floating-point `png_set_rgb_to_gray` facade with exact
  `png_fixed` rounding, finite/signed-32-bit validation, and delegation into
  the existing fixed RGB-to-gray state path.
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
- Translate read-side `pngtrans.c::png_set_swap` and `png_do_swap`, exchange
  every adjacent byte in 16-bit rows, and execute the immutable stage after
  Swap Alpha; prior Scale16/Strip16 reduction makes Byte Swap a validated
  copy-owned no-op after output depth reaches 8.
- Translate `png_set_check_for_invalid_index` and
  `png_do_check_palette_indexes`, preserve default-enabled checking, scan
  logical 1/2/4/8-bit Indexed samples without reading padding, and expose the
  accumulated maximum index plus retained-PLTE range status after Unpack and
  before BGR without mutating row bytes.
- Add native Cangjie read user-transform registration and configured
  depth/channel information, project nonzero output shape overrides, expose
  row/pass context, and execute the copy-owned callback as the final initialized
  stage after Byte Swap with exact returned-row validation.
