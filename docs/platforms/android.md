# Android 应用

实现位置：[`apps/android`](../../apps/android)。

**状态**：骨架占位（阶段 2 实现）。

## 规划

| 项 | 选择 |
| --- | --- |
| UI | Kotlin + Jetpack Compose |
| 虚拟网卡 | `VpnService`（对应桌面 TUN 语义） |
| 代理内核 | 预编译 mihomo（jniLibs 或 exec） |
| 系统代理 | 不支持（忽略 `systemProxyEnabled`） |

配置与投影行为必须符合 [`contracts/`](../../contracts)。
