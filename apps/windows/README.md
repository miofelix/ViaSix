# ViaSix for Windows

**状态：骨架占位（阶段 1 实现前不可运行）。**

## 目标能力

| 阶段 | 能力 |
| --- | --- |
| MVP | 配置导入、contracts 对齐投影、用户态 mihomo、测速、基础 UI |
| 后续 | 系统代理、Windows Service + Wintun（虚拟网卡） |

## 建议技术选型（实现阶段锁定）

- **选项 A**：Tauri 2（Web UI + Rust 宿主），与常见代理客户端类似
- **选项 B**：WinUI 3 / C# 原生壳

代理内核：构建期拉取预编译 mihomo（见 `scripts/fetch-mihomo.ps1` 占位）。

配置与投影行为必须符合仓库根 [`contracts/`](../../contracts)。

## 目录

```text
apps/windows/
├── README.md
├── src/                 # 应用源码（待实现）
├── scripts/             # 拉取内核、打包
└── packaging/           # 安装器 / MSIX 资源
```

## 本地开发（占位）

```powershell
# 后续提供：
# .\scripts\fetch-mihomo.ps1
# 构建与运行命令将在选定技术栈后写入
```

从 monorepo 根目录：`make windows-skeleton` 仅校验本骨架文件存在。
