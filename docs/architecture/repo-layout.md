# Monorepo 布局

ViaSix 是 **全平台** 客户端 monorepo，采用 **契约中心 + 多端壳**（模式 A）：共享配置与行为约定，各端独立实现 UI 与特权网络接入。

```text
viasix/
├── contracts/           # 跨端 schema 与黄金 fixture（单一事实来源）
├── packages/            # 共享约定与实现（mihomo-config、viasix-mihomo-config 等）
├── apps/
│   ├── macos/           # SwiftPM + SwiftUI + XPC TUN helper
│   ├── windows/         # Tauri 2 + Rust + Mihomo TUN/Wintun
│   ├── android/         # Kotlin + Compose + VpnService
│   └── # linux/         # 规划：Tauri 桌面 GUI（复用 Windows 栈）
├── server/              # Cloudflare Pages 等与客户端无关的服务
├── docs/                # 产品与架构文档
│   ├── architecture/    # 布局、路线、完成边界
│   └── platforms/       # 各平台说明（含 Linux 规划）
├── toolchains/          # 跨端工具脚本（内核拉取等，渐进迁入）
└── .github/workflows/   # 按路径过滤的 CI
```

## 依赖方向

```text
apps/*  →  contracts（行为对齐）
apps/*  ↛  其他 apps/*（禁止端到端直接依赖）
packages/* → contracts；不得依赖 apps/*
```

桌面端（Windows / 未来 Linux）可共享同一 Rust 投影 crate（`packages/viasix-mihomo-config`）与相近的 Tauri 壳，但仍以各自 `apps/*` 目录为发布边界。

## 平台能力矩阵（产品）

| 能力 | macOS | Windows | Android | Linux |
| --- | --- | --- | --- | --- |
| 用户态 mihomo | ✓ | ✓ | ✓ | 规划 |
| 系统代理 | ✓ | ✓ | 不适用 | 规划 |
| 虚拟网卡 / VPN | XPC helper + utun | 进程内 Mihomo TUN + Wintun | VpnService + TCP/UDP IPv4/IPv6 | 规划（TUN） |
| IPv6 优选 / 投影 | ✓ | ✓（共享 Rust crate） | ✓（Kotlin） | 规划（同桌面契约） |
| 测速 | ✓ CFST | ✓ CFST | ✓ CFST（arm64） | 规划 |
| 流量展示 | ✓ | ✓ | ✓ 累计 | 规划 |

实现进度与「完成」定义见 [COMPLETION.md](COMPLETION.md)；阶段划分见 [跨平台路线](roadmap.md)。
