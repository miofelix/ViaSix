# 虚拟网卡能力边界

## 当前状态

当前版本不显示“虚拟网卡”开关，也不会创建 `utun`、修改默认路由或修改 macOS DNS。`VirtualInterfaceManager` 只负责描述和探测后端能力；默认实现明确返回不可用，不执行任何系统网络操作。

应用包已经包含第一阶段的 LaunchDaemon helper 骨架、固定 XPC 探测协议和 `SMAppService` 注册边界。helper 当前只返回协议版本、实现版本和空能力集，并提供无状态的幂等恢复入口；它不会启动 Xray、读取用户配置或修改网络。因此“helper 已打包”不等于“虚拟网卡可用”。

系统代理与虚拟网卡是不同的网络接入层：系统代理只影响遵循 macOS 代理设置的应用，虚拟网卡才可能接收未配置代理的流量。不能用系统代理状态推断虚拟网卡已经启用。

核心层已经定义单一的 `NetworkAccessMode`（本地端点、系统代理、虚拟网卡）作为后续状态机边界；现有 `systemProxyEnabled` 字段仍保留用于旧配置兼容，尚未把虚拟网卡模式写入用户配置或 UI。

## 采用的后端方向

ViaSix 当前的配置生成和进程监管都围绕 Xray。阶段二保留 Xray 作为候选后端，不引入第二套核心或自研数据面。Xray 的 macOS TUN 自动路由和出口接口能力从 `26.6.27` 开始具备，`26.7.11` 修正了 macOS 网关/默认路由行为；因此实际启用的最低版本暂定为 `26.7.11`。

这只是内核能力门槛，不代表可以直接打开开关。Xray 官方 TUN 文档明确指出，把默认路由直接指向 TUN 会让 Xray 自己连接上游时再次进入 TUN，形成网络回环。配置默认路由时必须同时使用 `autoOutboundsInterface: "auto"` 或等效的、经过验证的上游绕行策略，并在应用前确认路由结果。

## 权限与组件边界

- 主应用继续以普通用户运行，不常驻 root，也不执行任意 `sudo` 或 shell 路由命令。
- 特权组件采用 `SMAppService.daemon(plistName:)` 管理的 LaunchDaemon，plist 位于 app bundle 的 `Contents/Library/LaunchDaemons/`，可执行文件位于 `Contents/Library/HelperTools/`。
- XPC 两端都使用 macOS 13+ 的代码签名要求 API，要求 app 与 helper 具有固定 bundle identifier 和相同 Developer ID Team；helper 还检查调用方 UID 与 audit session。ad-hoc 构建没有 Team ID，必须保持不可用。
- IPC 只能增加固定的 typed method，禁止任意路径、argv、shell、通用 JSON 或配置执行入口。安装状态、系统设置审批、协议兼容和能力探测彼此独立。
- 当前 `~/Library/Application Support/ViaSix/Runtime/xray` 属于用户可写目录，root helper 永远不能执行它。若后续需要 root 启动 Xray，只能把固定版本作为嵌套代码随 app 签名、公证和发布；否则 Xray 必须继续作为普通用户进程，并采用经过验证的 fd/接口交接方案。
- Network Extension 是长期更规范的路线，但需要新的 Packet Tunnel Provider target、entitlement、provisioning，以及把 Xray 编译为库并通过 Network Extension 提供的 fd 工作。当前可下载的 Xray 可执行文件不能直接当作 Network Extension 后端。

## 启动前置条件

后端只有在以下条件全部满足时才可向 UI 报告可用：

1. Xray 可执行文件真实输出的版本不低于 `26.7.11`，而不是只检查文件是否存在。
2. helper 已安装、签名校验通过、双向 IPC 握手成功，并拥有本次操作所需权限；`SMAppService.Status.requiresApproval` 必须引导用户到系统设置，而不能当作已启用。
3. IPv4、IPv6、默认路由、上游绕行和崩溃恢复能力均已探测；缺一项都保持不可用。
4. 系统代理会话已经恢复，避免两个接入层同时指向同一端点。
5. 当前服务器地址已解析为可验证的字面 IP，且不会被新路由再次送入 TUN。
6. 路由、DNS 和 helper 状态快照可以原子写入 root 拥有的受限目录；用户 Application Support 不能作为特权恢复日志。

TUN 就绪不能只用现有 mixed 端口探测，还要确认预期 `utun` 接口、地址和路由已经出现。睡眠唤醒、网络服务切换和上游地址变化后，必须重新检查默认出口和绕行路由。

## DNS 与恢复顺序

Xray 的 TUN `dns` 字段不会替 macOS 修改系统 DNS。除非另有受控 DNS 管理器并能保存/比较/恢复原始服务配置，否则不能宣称“无 DNS 泄漏”或“完整接管全部流量”。

启用顺序：检查能力 → helper 先恢复旧 journal → 保存本次旧状态 → 建立上游绕行 → 创建接口 → 应用 DNS 与路由 → 等待接口、路由和数据面就绪 → 发布已启用状态。

停止顺序：停止接收新连接 → 恢复 DNS 和路由（使用 CAS，保留外部修改）→ 停止数据面 → 关闭 TUN → 删除会话 journal。崩溃或强制退出时，helper 下次启动先完成同一恢复流程；恢复失败时必须 fail closed，不能假装网络已经恢复。

## 与 Clash Verge 的借鉴范围

可以借鉴 Clash Verge 的三点：能力探测后才显示控制项、用户态 sidecar 与特权 service 分离、启动/停止采用可恢复状态机。不会直接复制其平台特定的服务安装、配置覆写或 DNS 行为；ViaSix 的 helper、路由快照和 Xray 配置必须按 macOS 的签名与权限模型重新验证。

## 验证要求

真正开启入口前至少需要覆盖：

- capability 版本解析、helper 签名/IPC/权限和缺失能力映射；
- 非法状态转换、系统代理与虚拟网卡互斥、配置白名单；
- helper 安装/启动超时、Xray 崩溃、强杀、路由或 DNS 外部修改后的 CAS 恢复；
- IPv4/IPv6、TCP/UDP、Wi-Fi 切换和睡眠唤醒；
- 发布包的 helper Team ID、代码签名、篡改拒绝和固定路径校验。

在这些检查完成并有隔离 Mac 或虚拟机的真实网络回归前，普通用户界面保持隐藏虚拟网卡模式。
