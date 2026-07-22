# macOS 应用

实现位置：[`apps/macos`](../../apps/macos)。

- 技术栈：Swift 6.1、SwiftUI、SwiftPM
- 特权路径：`ViaSixTunHelper`（XPC + LaunchDaemon）
- 开发与打包：见 `apps/macos/Docs/DEVELOPMENT.md` 与 `RELEASING.md`（迁移后路径）

从仓库根目录：

```bash
make -C apps/macos check
make -C apps/macos app
```

或使用根 `Makefile` 的 `macos-*` 目标。
