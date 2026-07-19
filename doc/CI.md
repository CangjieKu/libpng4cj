# Continuous Integration

`tools/ci.sh` is the canonical automated verification entry. It runs:

1. environment and zlib checks
2. frozen upstream inventory regeneration and drift detection
3. `cjpm build`
4. `cjpm test`
5. the standalone Cangjie consumer

Run it locally with:

```sh
./tools/ci.sh
```

The checked-in workflow at `.github/workflows/cangjie-ci.yml` uses a
self-hosted runner labeled `cangjie` and `posix`. Public hosted runners do not
currently provide the required Cangjie SDK, so the workflow will wait until a
matching runner is connected.

A runner needs:

- `cjc` and `cjpm` on `PATH`
- a POSIX shell
- zlib development and runtime libraries resolvable through `-lz`
- `git`, plus `sha256sum` or `shasum`
- permission for the Cangjie unit-test runner to bind its local coordination
  port

The workflow intentionally omits the macOS-only C ABI preview. That suite
remains available through `tools/test_abi_preview.sh` and can be added as a
separate runner lane when platform runners are provisioned.
