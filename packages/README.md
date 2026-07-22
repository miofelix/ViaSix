# Shared packages

跨端可复用资产。ViaSix 为全平台产品；共享库服务已实现端，并预期复用于 Linux 桌面（Tauri / Rust）。

| 路径 | 状态 | 说明 |
| --- | --- | --- |
| [mihomo-config](mihomo-config/) | 约定 + 校验脚本 | 投影语义文档；`validate-cases.mjs` |
| [viasix-mihomo-config](viasix-mihomo-config/) | Rust 实现 | Windows（及未来 Linux 桌面）使用；契约 fixtures 单测 |

**原则**：共享库落地前，行为以 `contracts/` fixtures 为准；各端可有原生实现，但必须通过同一套 case。不得依赖 `apps/*`。
