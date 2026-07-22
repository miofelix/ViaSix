# macOS 应用

实现位置：[`apps/macos`](../../apps/macos)。

ViaSix **全平台**产品中的 macOS 端：当前最成熟的原生实现，也是桌面信息架构与契约行为的参考端之一。

- 技术栈：Swift 6.1、SwiftUI、SwiftPM
- 特权路径：`ViaSixTunHelper`（XPC + LaunchDaemon）
- 开发与打包：见 `apps/macos/Docs/DEVELOPMENT.md` 与 `RELEASING.md`
- 用户指南：`apps/macos/Docs/USER_GUIDE.md`

从仓库根目录：

```bash
make -C apps/macos check
make -C apps/macos app
```

或使用根 `Makefile` 的 `macos-*` 目标。

跨端布局与能力矩阵见 [repo-layout.md](../architecture/repo-layout.md)。
