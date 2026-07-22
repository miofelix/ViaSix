# Windows 应用

实现位置：[`apps/windows`](../../apps/windows)。

**状态**：骨架占位（阶段 1 实现）。

## 规划

| 项 | 选择 |
| --- | --- |
| UI / 宿主 | Tauri 2 或 WinUI 3（实现阶段再锁定） |
| 代理内核 | 预编译 mihomo sidecar（构建期拉取） |
| 系统代理 | WinINET / 相关 API |
| 虚拟网卡 | Windows Service + Wintun（二期） |

配置与投影行为必须符合 [`contracts/`](../../contracts)。
