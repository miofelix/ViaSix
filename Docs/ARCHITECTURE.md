# ViaSix 架构说明

本文描述 ViaSix 的 IPv6-first 运行模型、模块边界、配置投影和特权 TUN 信任边界。

## 总体结构

```text
ViaSixApp（SwiftUI / @MainActor）
  首页 · IPv6 优选 · 连接配置 · 日志 · 设置
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
ViaSixCore               ViaSixMihomoConfig
状态持久化 / CFST /       YAML 解析 / 配置迁移 /
Controller / 系统代理     严格与兼容运行投影
          │                    │
          └─────────┬──────────┘
                    ▼
ViaSixPrivilegedProtocol → ViaSixTunHelper → 固定签名 Mihomo
```

- `ViaSixApp`：窗口、菜单栏和工作流编排。
- `AppModel`：主线程上的唯一应用状态协调者，管理任务取消、启停和就绪判断。
- `ViaSixCore`：资源、偏好、测速、用户态 Mihomo、Controller 和系统代理。
- `ViaSixMihomoConfig`：Mihomo YAML 安全解析、内联配置、运行时投影和特权 envelope。
- `ViaSixPrivilegedProtocol`：应用与 helper 共用的版本化 typed XPC 协议。
- `ViaSixTunHelper`：LaunchDaemon，验证调用者后只启动应用内固定签名 Mihomo。

## 产品策略

`LocalProxyConfiguration.ipv6TransportPolicy` 有两个值：

- `required`：IPv6 严格模式，新安装默认；
- `compatibility`：旧配置迁移和高级兼容模式。

缺少该字段的已有 JSON 解码为 `compatibility`，避免升级时自动改变网络行为。应用资源中的新默认显式写入 `required`。

### IPv6 严格模式不变量

启动前必须满足：

```text
selectedIP 是 IPv6
    ∧ profile 有可替换的内联主代理
    ∧ TUN helper、固定运行时和功能集均就绪
```

严格模式忽略持久化的直连、全局、本地代理和系统代理选择。有效网络接入始终为 TUN，有效 Mihomo 模式始终为 `rule`。

### 兼容模式

兼容模式保留既有 Mihomo 语义：IPv4、Provider-only、导入规则、规则/全局/直连、用户态 mixed 端口、系统代理、可选 TUN和 Selector 组选择。

## 配置与运行投影

持久化来源：

```text
preferences.json  当前节点和测速偏好
profile.yaml       用户导入的 Mihomo 服务器配置
local-proxy.json   传输策略、本机监听和 TUN 参数
```

严格投影：

```text
profile.yaml
  → 找到第一个可替换 server 的内联代理
  → 验证 selectedIP 为 IPv6
  → 只保留该代理并替换 server
  → 删除 proxy-providers / proxy-groups /
           rule-providers / sub-rules / imported rules
  → 写入私有、回环、链路本地 DIRECT 规则
  → 追加 MATCH,<primary proxy>
  → 生成 privileged TUN envelope
```

严格投影不会因为导入 YAML 中存在 `mode: global`、Provider 或最终规则而改变。这样客户端到远程入口的地址族和出站目标由 ViaSix 明确控制。

兼容投影保留用户配置中的代理、Provider、代理组和规则，并根据本机设置生成 rule/global/direct 运行配置。直连模式完全移除远程来源并生成 `MATCH,DIRECT`。

## 启动与可恢复错误

启动流程：

1. 准备 Application Support、默认资源和 Controller 密钥；
2. 恢复可能遗留的系统代理快照；
3. 加载偏好、测速结果、连接配置和本机配置；
4. 同步可重新生成的用户态配置；
5. 检查 TUN helper、固定 Mihomo 和现有会话；
6. 发布 `AppState` 并进入可交互状态。

严格模式下，下列情况是可恢复的配置就绪问题，不是致命应用启动错误：

- 未选择 IPv6；
- 选择了 IPv4；
- Profile 只有 Provider 或无可替换内联代理；
- TUN 服务未安装、未批准或固定运行时未就绪。

同步失败时仍保留真实的 `required` 策略和用户已选 IPv6，UI 才能给出正确修复步骤。

## TUN 与信任边界

严格模式只通过特权 TUN 启动。应用不会把用户可写 YAML 直接交给 root-owned Mihomo：

1. App 使用 `ViaSixMihomoConfig` 完成严格/兼容投影和字段白名单；
2. 投影结果与规范化选项编码为版本化 binary plist envelope；
3. helper 检查大小、深度、复杂度、schema 和规范形式；
4. helper 从 envelope 重新构造服务器配置并再次执行特权白名单投影；
5. 只有重建结果与 canonical envelope 一致时才生成运行 YAML并启动固定 Mihomo。

helper 不能执行 `Runtime/` 中的用户自定义 Mihomo。会话按登录用户 UID 归属；非所有者只能观察脱敏状态，不能停止、恢复、修复服务或替换运行时。

## Controller 边界

Controller 固定监听 `127.0.0.1`，使用 `Data/Mihomo/controller.secret` 中的随机 Bearer 密钥。导入 YAML 中的 `external-controller` 和 `secret` 不受信任，运行配置会重新生成这些字段。

当前 Controller 客户端只保留两个能力：

- 启动或刷新时读取 Mihomo 版本和可手动选择的代理组；
- 在兼容模式中提交 Selector 组选择。

ViaSix 不再订阅 `/connections` WebSocket，也不轮询规则、Provider、流量或内存。因此没有连接历史、规则检查、Provider 管理或实时流量仪表盘。代理停止、重启或退出时会取消当前快照/选择任务并清空运行态引用。

## 日志模型

日志不是 Controller 仪表盘的一部分，而是 AppModel 的独立诊断通道。应用、测速、代理和 TUN 事件统一进入 `AppState.logs`，日志页面提供来源/级别筛选、跟随、排序和清空。

保留日志页面可以在移除高频 Clash 数据面后继续诊断：

- 配置同步与策略阻塞；
- 节点应用和重连；
- TUN 安装、批准、启动、恢复和停止；
- Mihomo 输出和意外退出；
- CFST 进度与解析错误；
- 出口 IP 检测。

## 数据目录

```text
~/Library/Application Support/ViaSix/
  Data/
    preferences.json
    ip.txt
    ipv6.txt
    profile.yaml
    local-proxy.json
    result.csv
    system-proxy.json
    Mihomo/
      config.yaml
      controller.secret
      providers/
      rules/
  Runtime/
    cfst
    mihomo
  Logs/
```

目录权限为 `0700`，受管配置和偏好文件为 `0600`。`Mihomo/config.yaml` 是派生文件，不是用户配置的唯一来源。

`local-proxy.json` 的关键字段包括：

| 字段 | 新安装默认 | 说明 |
| --- | --- | --- |
| `ipv6TransportPolicy` | `required` | 严格 IPv6 或兼容策略 |
| `listenAddress` | `127.0.0.1` | 只允许回环地址 |
| `port` | `11451` | mixed 端口 |
| `controllerPort` | `9090` | 回环 Controller 端口 |
| `routingMode` | `rule` | 仅兼容模式可切换 |
| `networkAccessMode` | `localProxy` | 严格模式运行时强制 TUN |
| `systemProxyEnabled` | `false` | 严格模式忽略并保持关闭 |
| `tunStack` | `mixed` | Mixed/System/gVisor |
| `tunMTU` | `1500` | 1280–9000 |

## 测速流程

```text
SpeedTestParameters
  → 校验 IPv6/兼容数据源
  → CfstRunner 启动独立进程组
  → 流式解析输出
  → 读取本次 result.csv
  → AppModel 更新结果和候选选择
```

严格模式隐藏内置 IPv4 来源并在 UI 与 AppModel 两层拒绝应用 IPv4。自定义源仍可包含任意输入，但只有 IPv6 结果能成为严格模式的当前节点。

## 进程与并发

- UI 和 `AppModel` 位于 `@MainActor`；
- CFST、Mihomo、偏好、系统代理和 TUN 协调器使用 actor 隔离；
- 每个长任务都由 `AppModel` 持有并在停止、重启或退出时取消；
- ViaSix 只终止自己创建并仍持有身份的进程或进程组；
- 系统代理恢复和 TUN 停止在退出完成前收敛，失败时拒绝假装安全退出。

## 分发模型

正式分发面向 Developer ID 签名和公证。开发 `make app` 使用 ad-hoc 签名及本机管理员安装路径。应用包验证会检查默认严格配置、嵌套签名、固定 Mihomo 摘要/CDHash、协议版本和本地路径泄漏。
