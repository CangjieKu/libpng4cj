# 持续集成

[简体中文](CI.md) | [English](../CI.md)

## 本地验证

在仓库根目录执行完整的仓颉原生验证入口：

```sh
./tools/ci.sh
```

脚本依次执行：

1. `tools/doctor.sh` 环境检查
2. 固定上游清单一致性检查
3. `cjpm build`
4. `cjpm test`
5. 独立仓颉 consumer

consumer 包含真实 PNG fixture 的解码、编码、再次解码 roundtrip。

## 自托管 Runner

`.github/workflows/` 下的工作流使用以下自托管标签：

```text
self-hosted
cangjie
posix
```

Runner 需要提供兼容的仓颉 SDK、zlib 开发文件、Git，并允许仓颉单元测试
运行器绑定本地协调端口。

公共托管 Runner 通常不包含所需仓颉 SDK，因此当前工作流明确使用自托管
执行环境。

## C ABI 验证

在 macOS arm64 上执行：

```sh
./tools/test_abi_preview.sh
```

该脚本会构建 Preview 动态库、检查导出符号清单、编译并运行 17 个严格
C11 consumer，同时从复制后的目录复测依赖重定位相关路径。

C ABI 验证没有并入可移植的原生 CI 入口，因为当前动态库和运行时路径仍是
macOS arm64 专用的。
