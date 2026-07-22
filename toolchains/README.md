# Toolchains

跨端构建辅助脚本（内核与测速组件拉取、校验等）。

当前各端仍使用各自脚本（如 macOS `apps/macos/Scripts/fetch-mihomo.sh`，Windows/Android 的 `fetch-mihomo.mjs`）。后续将把共用的下载/校验逻辑收敛到本目录，避免多端复制粘贴（含未来 Linux 桌面）。
