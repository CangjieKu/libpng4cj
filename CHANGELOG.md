# Changelog

## 0.2.0 Preview - 2026-07-18

- Publish the accumulated Cangjie-native read, write, progressive, simplified
  image, metadata, transform, and macOS arm64 C ABI subset as a preview review
  line without claiming complete libpng16 compatibility or LTS status.
- Add direct Cangjie classic stateless ABI utilities for version access,
  signature comparison, and big-endian 16/32-bit integer reads and writes.
- Extend the simplified `png_image` ABI subset across memory, named files, and
  caller-owned C stdio streams for read and write workflows.
- Complete bilingual README documentation, dependency/link guidance, public
  capability boundaries, and replayable native/C consumer commands.

- Add copy-owned custom component strides to direct 8-bit, linear UInt16, and
  colormap simplified image buffers, including zero-to-minimum normalization,
  positive padded and negative bottom-up storage, logical row access, padding
  preservation, checked read allocation, and non-interlaced or Adam7 write-back.
- Add native simplified colormap memory read/write with copy-owned one-byte
  indices, RGB/BGR/RGBA/ARGB/BGRA/ABGR entry layouts, direct Indexed PLTE/tRNS
  identity, upstream-shaped 256-gray, 216-color, and 244-alpha map families,
  explicit encoded-sample background composition, minimal indexed write depth,
  and non-interlaced or Adam7 output through the existing writer.
- Add copy-owned host-numeric UInt16 simplified images for nine linear Gray,
  RGB, BGR, and alpha-first/alpha-last layouts; support straight or associated
  alpha, black composition when alpha is removed, packed/8/16-bit and Adam7
  input, and bounded 16-bit linear or converted sRGB8 memory write-back using
  the frozen upstream exact sRGB transfer tables.
- Add a Cangjie-native simplified memory image facade with copy-owned
  begin/finish/free lifecycle, header and diagnostic facts, nine common 8-bit
  Gray/GA/AG/RGB/BGR/RGBA/ARGB/BGRA/ABGR layouts, explicit background
  composition, exact contiguous buffer ownership, and non-interlaced or Adam7
  memory write-back through existing metadata, control, and limit policy.
- Add Adam7 support to `PngRowWriteSession.startTo(sink)` through bounded
  pass-local spooling: transform each accepted complete row once, gather only
  its seven-pass material, then filter and incrementally deflate in canonical
  pass order while preserving memory/deferred/early byte parity, exact limits,
  IEND, failure, and flush behavior.
- Add lifecycle-frozen `PngWriteControlState` configuration for filter subsets,
  libpng-compatible one-pixel/default filter resolution, compression level,
  memory level, window bits, method, strategy, and deflate output-buffer size;
  route whole-image, deferred row, early row, and Adam7 output through the same
  configured `deflateInit2_` path while preserving legacy constructor failure
  timing and deterministic bytes.
- Add `PngIncrementalDeflater` and non-interlaced
  `PngRowWriteSession.startTo(sink)` so transformed and filtered rows feed a
  bounded live zlib stream and complete IDAT chunks reach custom sinks during
  row intake; keep memory, deferred-sink, and early-sink bytes identical and
  preserve exact IEND/flush, callback failure, metadata, and unknown-chunk
  behavior; Adam7 uses bounded pass-local spooling before canonical pass-order
  IDAT emission.
- Add `PngRowWriteSession`, a copy-owned row-at-a-time write lifecycle with
  exact row count/shape accounting, non-interlaced and Adam7 finalization,
  deterministic failure states, and memory/custom-sink output parity.
- Add copy-owned unknown-chunk write injection with explicit after-IHDR,
  after-PLTE, and after-IDAT regions, safe-to-copy/ancillary/all policies,
  recognized-chunk conflict and reserved-bit validation, metadata limits, and
  retained decode-write-decode parity.
- Add a native Cangjie custom write sink that receives copy-owned signature and
  complete framed-chunk emissions with sequence, chunk type, byte-offset, and
  final-IEND context; route memory output through the same emission core and
  flush exactly once after final size validation.
- Add native Cangjie write user-transform registration before the default
  transform stages, with copy-owned rows, full-image row/interlace context,
  identity and live replacement behavior, exact source-shape validation, and
  one callback execution per complete Adam7 image row.
- Add lifecycle-frozen default write transforms before filtering for packing,
  pack swap, filler stripping, 16-bit byte swap, significant-bit expansion,
  alpha swap/inversion, BGR, and monochrome inversion across non-interlaced and
  Adam7 output, with exact source/output geometry and transformed-byte limits.
- Add a bounded chunk-fed `PngProgressiveReader` with explicit lifecycle,
  configurable decode policy, replaceable info/row/end callbacks, copy-owned
  callback rows, and non-interlaced/Adam7 canonical-row context at finalize.
- Decode Adam7 images through exact seven-pass geometry, pass-local filter
  reversal, and packed/8/16-bit scatter into canonical full-image rows; add
  generic packed, RGBA8, and RGBA16 entry points while preserving the explicit
  non-interlaced API rejection contract.
- Translate cICP, cLLI, mDCV, eXIf, hIST, oFFs, pCAL, sCAL, and sPLT read
  metadata with ordering, duplicate, field, numeric-string, copy-ownership,
  transformed-result, post-IDAT eXIf, and standalone consumer coverage.
- Complete background-aware Gray-to-RGB initialization and dispatch, including
  equal-RGB gray synchronization and mutually exclusive pre-Compose versus
  post-Expand16 placement across row, whole-image, and consumer paths.
- Translate cHRM-derived RGB-to-gray coefficient initialization with explicit
  setter precedence, sRGB/historical fallback, immutable row/whole-image
  execution, and standalone consumer proof.
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
