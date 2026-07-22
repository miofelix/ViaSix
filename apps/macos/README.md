# ViaSix for macOS

ViaSix **全平台**产品中的原生 macOS 客户端（SwiftUI + SwiftPM）。本目录是可独立构建的应用根；跨端契约见仓库 [`contracts/`](../../contracts/)，总览见根 [README](../../README.md)。

## 要求

- macOS 15.2+（开发）；运行最低 macOS 14
- Xcode 16.3 / Swift 6.1+

## 常用命令

在**本目录**执行：

```bash
make build
make test
make check
make app
open dist/ViaSix.app
```

从仓库根目录：

```bash
make macos-check
make macos-app
```

## 文档

- [开发说明](Docs/DEVELOPMENT.md)
- [架构说明](Docs/ARCHITECTURE.md)
- [发布指南](Docs/RELEASING.md)
- [用户指南](Docs/USER_GUIDE.md)
- [虚拟网卡](Docs/VIRTUAL_NETWORK.md)

跨端布局见仓库根 [docs/architecture/repo-layout.md](../../docs/architecture/repo-layout.md)。
