# libpng4cj Documentation

[English](README-EN.md) | [简体中文](README.md)

This directory contains public documentation for users, contributors, and
compatibility reviewers. Existing English document paths remain stable. The
Simplified Chinese set lives under [`zh-CN/`](zh-CN/).

## User Documentation

- [API guide](feature_api.md)
- [Compatibility and dependency matrix](COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
- [C ABI surfaces](ABI_PREVIEW.md)
- [Continuous integration](CI.md)

## Porting And Upstream Alignment

- [Porting status](PORTING_MAP.md)
- [Read-transform alignment](PNG_RTRAN_TRANSLATION_LEDGER.md)
- [Write-transform alignment](PNG_WTRAN_TRANSLATION_LEDGER.md)
- [`libpng 1.6.58` upstream inventories](upstream/)

Function translation counts describe source-level alignment. They do not imply
complete `libpng16` ABI coverage. The ABI boundary is defined by
[C ABI Surfaces](ABI_PREVIEW.md) and the manifests under
[`abi/symbols/`](../abi/symbols/).
