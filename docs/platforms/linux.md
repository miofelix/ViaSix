# Linux 应用（规划中）

**状态：未开发。** ViaSix 产品定位包含 Linux 桌面；本文件描述目标与约束，避免与「仅 macOS」表述混淆。

## 目标

| 项 | 规划 |
| --- | --- |
| 形态 | 桌面 GUI 客户端（与 macOS / Windows 同一产品语义） |
| 技术栈 | **Tauri 2 + Rust**，复用 / 对齐 [Windows 应用](windows.md) |
| 投影 | 共享 `packages/viasix-mihomo-config` + `contracts/` fixtures |
| 代理内核 | 预编译 mihomo（按架构拉取，与桌面端同一套校验思路） |
| 系统代理 | 需抽象桌面环境差异（GNOME / KDE / 其他） |
| 虚拟网卡 | Mihomo TUN；权限与安装策略（capability / polkit 等）待定 |
| 目录 | 预期 `apps/linux`，或与 Windows 共用桌面壳后再拆分发布边界 |

## 与 Windows 的关系

Linux 桌面优先 **复用 Windows 的 Tauri 栈**，而不是再起一套原生 GUI：

- UI 分区与设计系统应对齐现有桌面五分区（首页 / IPv6 优选 / 连接配置 / 日志 / 设置）；
- 平台相关逻辑（系统代理、TUN 权限、打包）放在条件编译或独立模块，避免污染 Windows 路径；
- **禁止** `apps/*` 之间直接 import；共享只走 `contracts/` 与 `packages/`。

## 非目标（当前）

- 不作为 headless / 纯 CLI 产品线优先交付（若未来需要，另开讨论）；
- 不保证所有发行版与桌面环境开箱即用；首批目标架构与打包格式在 [roadmap 阶段 4](../architecture/roadmap.md) 敲定；
- 在 `apps/linux` 落地前，仓库根 `make check` 不以 Linux 构建为门禁。

## 文档与路线

- 阶段清单：[跨平台路线 · 阶段 4](../architecture/roadmap.md)
- 完成边界：[COMPLETION.md](../architecture/COMPLETION.md)
- 布局：[repo-layout.md](../architecture/repo-layout.md)

实现开始后，本文应改为与 [windows.md](windows.md) 同级的「技术选型 + 验证 + 打包」说明，并更新根 [README](../../README.md) 平台状态表。
