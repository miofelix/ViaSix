# 跨平台范围完成说明

本文界定「全部完成」在本 monorepo 中的含义，以及仍依赖外部密钥、可选增强，或尚未开工的平台项。

**产品定位**：ViaSix 是全平台客户端（macOS / Windows / Android / Linux）。当前**发布与验证范围**覆盖已实现的三端；Linux 为路线图中的下一桌面端，**未开发**，不计入「范围内已完成」。

## 范围内已完成

| 能力 | macOS | Windows | Android | Linux |
| --- | --- | --- | --- | --- |
| Monorepo + contracts fixtures | ✓ | ✓ | ✓ | 契约适用；无独立 app |
| IPv6 投影 | ✓ | ✓（共享 Rust crate） | ✓（Kotlin） | 规划 |
| 用户态 Mihomo | ✓ | ✓ | ✓ | 规划 |
| 系统代理 | ✓ | ✓ | N/A | 规划 |
| 虚拟网卡 / VPN | ✓ XPC+utun | ✓ Mihomo TUN+Wintun | ✓ VpnService+转发 | 规划 |
| 测速 | ✓ CFST | ✓ CFST | —（可后续） | 规划 |
| 流量展示 | ✓ | ✓ | ✓ 累计 | 规划 |
| 会话偏好 | ✓ | ✓ | ✓ | 规划 |
| 安装包/CI | ✓ app | ✓ NSIS workflow | ✓ assembleDebug | 未开工 |

## 范围外 / 需仓库外配置 / 规划

| 项 | 原因 |
| --- | --- |
| Authenticode / Apple 公证 / Play 签名 | 需要证书与密钥，无法在开源仓内「完成」 |
| 独立 Windows Service 特权隔离 | 可选安全增强；当前为进程内 Mihomo+Wintun |
| Swift/Kotlin 共用 Rust FFI | 可选；三端 fixtures 已对齐 |
| Android hev 生产级 tun2socks | 可选；当前用户态 TCP/DNS 转发为可用 MVP |
| **Linux 桌面 GUI** | **规划中 / 未开发**；技术倾向 **Tauri 复用 Windows 栈**，见 [roadmap 阶段 4](roadmap.md) 与 [platforms/linux.md](../platforms/linux.md) |

## 验证

```bash
make contracts-check
make shared-test
make projection-test   # 较慢：含 macOS swift test
make windows-test
make android-test
```

Linux 落地后应补充对应 skeleton / 测试目标，并纳入 `make check` 策略（避免在无 Linux runner 时阻塞其他端）。
