# Continuous Integration

[English](CI.md) | [简体中文](zh-CN/CI.md)

## Local Verification

Run the complete native Cangjie verification entry from the repository root:

```sh
./tools/ci.sh
```

The script runs:

1. environment checks through `tools/doctor.sh`
2. frozen upstream inventory checks
3. `cjpm build`
4. `cjpm test`
5. the standalone Cangjie consumer

The consumer includes a real-fixture decode, encode, and decode roundtrip.

## Self-Hosted Runner

The workflow under `.github/workflows/` targets a self-hosted runner with these
labels:

```text
self-hosted
cangjie
posix
```

The runner must provide a compatible Cangjie SDK, zlib development files, Git,
and a shell environment that permits the Cangjie unit-test runner to bind its
local coordination port.

Public hosted runners generally do not include the required Cangjie SDK, so
the workflow is intentionally self-hosted.

## C ABI Verification

On macOS arm64, run:

```sh
./tools/test_abi_preview.sh
```

This builds the preview dynamic library, checks exported-symbol manifests,
compiles 17 strict C11 consumers, runs them against the original library, and
replays the relocation-sensitive paths from a copied location.

The C ABI suite is separate from the portable native CI entry because the
current artifact and runtime paths are macOS arm64 specific.
