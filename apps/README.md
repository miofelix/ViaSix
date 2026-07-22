# Applications

ViaSix 客户端按平台分目录实现。产品定位为 **全平台**（含 Linux 规划）；共享行为只通过 [`../contracts`](../contracts) 与 [`../packages`](../packages) 对齐。

| 路径 | 平台 | 状态 |
| --- | --- | --- |
| [macos](macos/) | macOS 14+ | 可用（原生 SwiftUI） |
| [windows](windows/) | Windows | 可用 MVP（Tauri；UI 对齐五分区） |
| [android](android/) | Android | 可用 MVP（投影 + VpnService） |
| — | Linux 桌面 | **规划中 / 未开发**（Tauri，复用 Windows 栈）→ [docs/platforms/linux.md](../docs/platforms/linux.md) |

各应用**不得**相互 import。跨端行为变更先改 `contracts/`，再改各端实现与测试。
