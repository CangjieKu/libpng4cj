# Upstream Baseline

## Frozen Source

- project: `pnggroup/libpng`
- repository: `https://github.com/pnggroup/libpng.git`
- tag: `v1.6.58`
- commit: `3061454d980de7d53608f594194cfac722721d2a`
- git-archive SHA-256: `07900c2e616ce58dda6b30ec444bbe662b51c0bdd0bc7e02ba053ec83f009df5`
- local reference root: `vendor/libpng-1.6.58/`

The source was obtained by checking out the exact tag commit and exporting it
with `git archive`. The archive contains no nested Git metadata.

## License

libpng4cj is a derivative translation program. The upstream libpng license and
author notices are retained in `LICENSE` and in the vendored source. Translated
modules must preserve provenance to their corresponding upstream files.

## Baseline Generation

Run:

```sh
sh ./tools/update-upstream-baseline.sh
```

This regenerates the public symbol list, public-header digests, and source-file
inventory from the frozen vendor tree. A future upstream update must change the
version, commit, archive hash, generated inventories, and porting map together.

The authoritative upstream `scripts/symbols.def` contains 258 potential public
symbols. A locally installed default macOS build exposes 256; `png_err` and
`png_set_strip_error_numbers` are configuration-gated. libpng4cj tracks both
the complete upstream surface and later per-profile exported-symbol manifests.
