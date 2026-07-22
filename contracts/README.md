# ViaSix Contracts

跨平台**单一事实来源**：配置 schema、行为不变量与黄金测试 fixture。

ViaSix 面向 **macOS / Windows / Android / Linux（规划）**。各端在实现配置投影、就绪检查与本地配置读写时，必须以本目录约定为准。行为变更应先更新 contract，再改各端实现与测试。

## 目录

| 路径 | 说明 |
| --- | --- |
| `schemas/` | JSON Schema（`local-proxy`、`x-viasix` 等） |
| `fixtures/mihomo-config/cases/` | 配置投影语义用例（`input.yaml` + `case.json`） |

## 版本

契约破坏性变更时递增 `VERSION` 中的主版本，并在各端拒绝不兼容的配置版本。

当前版本见 [VERSION](VERSION)。

## 使用约定

1. **不要**在 contract 中引用任何平台 API（Swift/Kotlin/Win32/Linux 等）。
2. 投影用例使用**语义期望**，不强制 YAML 字节级一致。
3. 各端 CI 应加载 `fixtures/mihomo-config/cases/*` 并断言 `case.json`。
4. 平台特有能力（系统代理、TUN 权限模型等）不进入 schema 核心字段时，应在各端文档与产品矩阵中说明，避免假装「全端已实现」。
