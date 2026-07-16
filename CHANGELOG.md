# Changelog

## Unreleased

- Use the direct `src/` package root so consumers import `libpng4cj.*`.
- Add a standalone external-consumer project under `test/consumer`.
- Organize public design, API, porting, and upstream baseline material under
  `doc/`.
- Snapshot and compose initialized Invert Alpha, significant-bit Unshift,
  Filler/Add Alpha, and Swap Alpha stages after Expand16, including 8/16-bit
  network-order behavior, semantic-alpha swapping, copy ownership, and
  whole-image transformed-byte limits.
