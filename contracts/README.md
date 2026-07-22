# ViaSix Contracts

跨平台**单一事实来源**：配置 schema、行为不变量与黄金测试 fixture。

各端（macOS / Windows / Android）在实现配置投影、就绪检查与本地配置读写时，必须以本目录约定为准。行为变更应先更新 contract，再改各端实现与测试。

## 目录

| 路径 | 说明 |
| --- | --- |
| `schemas/` | JSON Schema（`local-proxy`、preferences、`x-viasix` 等） |
| `fixtures/mihomo-config/` | 配置投影输入/输出黄金用例 |

## 版本

契约破坏性变更时递增 `VERSION` 中的主版本，并在各端拒绝不兼容的配置版本。

当前版本见 [VERSION](VERSION)。

## 使用约定

1. **不要**在 contract 中引用任何平台 API（Swift/Kotlin/Win32 等）。
2. Fixture 命名：`<scenario>.in.yaml` + `<scenario>.out.yaml`（或 `.json`）。
3. 各端 CI 应能独立校验本目录（见根目录工作流 `contracts` job，后续接入）。
