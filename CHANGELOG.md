# Changelog

## Unreleased

- Complete Indexed tRNS inversion during palette initialization when Background
  Expand and Expand are active without tRNS-to-alpha expansion, using a
  copy-owned effective alpha prefix while preserving ordinary Expand row-alpha
  handling and source metadata.
- Complete alpha initializer optimization parity for Indexed input: classify
  opaque, binary, and partial alpha before freezing effective Encode/Optimize
  state, preserve setter intent independently, and premultiply partial palette
  entries with the frozen linear-Gamma arithmetic for Expand and non-Expand
  consumers.
- Translate `png_do_encode_alpha` for 8/16-bit GA/RGBA rows, including
  alpha-only from-linear lookup, network order, effective initialization
  cancellation, and stage placement after Compose/post-Compose Strip Alpha and
  before 16-to-8 reduction.
- Translate fixed and floating read alpha-mode setters for PNG, Associated,
  Optimized, and Broken modes, including first-write default Gamma, screen
  Gamma, black-background Compose state, Encode/Optimize flags, conflict and
  lifecycle isolation, and immutable initialization snapshots.
- Preprocess Indexed PLTE/tRNS during read initialization for background
  composition and palette Gamma correction, including transparent, partial,
  opaque, and implicit-tail entries, File/Screen/Unique backgrounds,
  Expand/non-Expand consumers, and row Compose/Gamma cancellation.
- Translate complete non-palette packed/8/16-bit Gray/GA/RGB/RGBA
  `png_do_compose` execution with exact tRNS replacement, no-division alpha
  rounding, direct/linear Gamma, network order, initialized stage suppression,
  and post-Compose Strip Alpha.
- Complete Compose-side background depth and gamma initialization snapshots,
  including exact Expand16/16-to-8 normalization, Screen/File/Unique gamma
  derivation, original/linear/screen colors, and Compose-driven linear tables.
- Snapshot effective background configuration during read initialization,
  including no-alpha Compose cancellation, palette-index RGB expansion,
  sub-byte grayscale expansion, and post-Compose Strip Alpha ordering.
- Translate fixed and floating background setter state with frozen gamma-code,
  Compose/Strip Alpha, expansion, alpha-encoding cancellation, lifecycle, and
  prior-state preservation behavior.
- Complete frozen gamma-aware 8/16-bit RGB/RGBA-to-Gray/GA row execution
  through initialized to-linear/from-linear tables, including direct correction
  for equal RGB, original-sample nongray detection, alpha, and network order.
- Complete frozen 16-bit Gray/GA/RGB/RGBA `png_do_gamma` execution with
  initialized direct/reduction dispatch, network-order and alpha preservation.
- Attach immutable initialized 16-bit direct and optional linear Gamma tables,
  including sBIT/reduction shift selection and the frozen 16-to-8 specialization.
- Translate frozen floating-arithmetic 16-bit gamma correction and immutable
  segmented direct tables for shifts `0..8`, with exact scaling and copy-owned
  lookup access.
- Translate packed 2/4-bit and byte-depth `png_do_gamma` row execution with
  initialized gating, alpha preservation, and stable prior stage ordinals.
- Attach immutable initialized 8-bit direct and optional RGB-to-gray linear
  gamma table snapshots after exact reciprocal2 correction derivation.
- Translate frozen floating-arithmetic 8-bit gamma correction and immutable
  256-entry identity/significant table generation.
- Connect configured gamma state and retained gAMA metadata to immutable read
  initialization, exposing resolved file/screen values and correction status
  without adding a row-correction stage.
- Translate floating gamma conversion and delegation into fixed setter state,
  including already-fixed values, reserved flags, and finite/range checks.
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
