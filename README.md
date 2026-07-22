# ViaSix for macOS

ViaSix 是一款以 IPv6 为核心的原生 macOS 网络工具：它测试并选择可用的 IPv6 代理入口，通过 TUN 接管本机公网流量，再把流量交给你自己的 Mihomo 兼容代理配置。

这里的“走 IPv6”指客户端到远程代理入口使用 IPv6。远程代理访问最终网站时，出口仍可能是 IPv4，这取决于服务器和目标站点。

> [!IMPORTANT]
> ViaSix 不提供代理账号、订阅、服务器或网络接入服务。你需要准备自己有权使用的 Mihomo YAML 配置。

## 两种运行策略

- **IPv6 模式（新安装默认）**：必须使用 TUN、有效 IPv6 节点和可注入地址的内联代理。私有、回环和链路本地地址直连，其余被接管的流量统一通过主代理。导入配置中的规则、代理组和 Provider 不进入严格运行配置。
- **兼容模式**：面向旧配置和特殊应用，保留 IPv4、Provider-only YAML、导入规则、规则/全局/直连模式、本地代理、系统代理及基础代理组选择。

## 主要功能

- 使用内置 IPv6 地址列表测试候选节点
- 支持自定义 IP 文件、单个地址和 CIDR
- 按延迟、丢包率、下载速度和地区比较结果
- 一键应用 IPv6 节点，运行中可自动重新连接
- 使用 TUN 接管不遵循系统代理的应用流量
- 导入并编辑通用 Mihomo YAML；支持 VLESS、VMess、Trojan 和 Shadowsocks 内联节点
- 检测当前出口 IP，并明确区分“IPv6 代理入口”和“最终网站出口”
- 保留完整独立日志界面，支持来源/级别筛选、跟随、排序和清空
- 在兼容模式下按需读取并切换 Mihomo Selector 代理组
- 菜单栏提供启动、停止、重连、IPv6 优选、日志和设置入口
- 设置、地址列表和代理配置保存在本机，不收集遥测

ViaSix 使用第三方项目 XIU2/CloudflareSpeedTest 完成节点测速，使用 MetaCubeX/mihomo 提供代理能力。CloudflareSpeedTest 并非 Cloudflare 官方产品。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon（arm64）或 Intel（x86_64）Mac
- 安装组件、测速和出口检测时需要网络连接

## 从源码构建

开发环境需要 Xcode 16.3 / Swift 6.1 或更高版本。

```bash
make check
make app
open dist/ViaSix.app
```

`make app` 生成适合本机开发和验证的 ad-hoc 签名应用。首次安装 TUN 服务时会请求管理员授权；日常启停不需要重复输入密码。正式分发应使用维护者签名并公证的发布包。

## 快速开始

1. 打开“设置 → 运行组件”，安装 CloudflareSpeedTest。
2. 在“设置 → 虚拟网卡服务”安装服务和特权 Mihomo，并确认两者已就绪。
3. 打开“连接配置”，导入含内联代理的 Mihomo YAML。
4. 打开“IPv6 优选”，测试并应用一个 IPv6 节点。
5. 返回首页，确认 TUN、IPv6 节点和连接配置均已就绪，然后启动连接。
6. 如需排查，打开“日志”查看代理、测速和应用事件。

严格模式不会修改 macOS 系统代理。它通过 TUN 接管流量，并使用 ViaSix 生成的最小运行配置：只保留主代理，替换其服务器地址为所选 IPv6，加入私有地址直连规则，最后使用 `MATCH,<主代理>`。

如果必须使用 IPv4、Provider-only 配置、自定义规则、系统代理或直连模式，可在“设置 → 本机代理”切换为兼容模式。兼容模式是迁移和高级兼容入口，不是 ViaSix 的默认产品路径。

## 配置示例

```yaml
proxies:
  - name: My VLESS
    type: vless
    server: origin.example.com
    port: 443
    uuid: 11111111-1111-1111-1111-111111111111
    network: ws
    tls: true
    servername: origin.example.com
    ws-opts:
      path: /proxy
      headers:
        Host: origin.example.com
```

IPv6 模式会把 `server` 替换为当前选择的 IPv6 地址，同时保留端口、凭据、传输、TLS、SNI/Host 和路径等连接身份字段。

## 数据与隐私

可变数据默认位于：

```text
~/Library/Application Support/ViaSix/
```

- ViaSix 不要求账号，也不收集遥测。
- 本地 mixed 代理和 Controller 只绑定回环地址；Controller 使用随机密钥鉴权。
- 配置可能包含 UUID、域名和密钥，请勿公开 `profile.yaml`、截图或备份。
- 出口 IP 检测会访问设置中配置的检测服务，并可使用 `ipwho.is` 补充地理和 ASN 信息。
- TUN helper 只能启动应用内固定签名的 Mihomo，不能执行用户自定义可执行文件。

完整说明见[隐私说明](PRIVACY.md)和[架构说明](Docs/ARCHITECTURE.md)。

## 常见问题

### 为什么选择了 IPv6 节点，出口仍显示 IPv4？

ViaSix 保证的是 Mac 到远程代理入口使用 IPv6。远程代理到目标网站的出口地址族由服务器和网站决定，因此最终出口可能仍是 IPv4。

### 为什么 IPv6 模式不能使用 Provider-only 配置？

严格模式必须明确找到一个可替换 `server` 的内联主代理，才能保证客户端连接远程入口时使用所选 IPv6。Provider 内容由远端动态管理，ViaSix 无法安全地完成这一保证。需要 Provider 时请切换兼容模式。

### 为什么必须安装 TUN？

ViaSix 的核心目标是让本机公网流量进入 IPv6 代理链路。只提供本地端口或系统代理无法覆盖所有应用，因此严格模式固定使用 TUN。

### 日志界面还保留吗？

保留。日志是独立主页面，支持筛选、跟随最新记录、排序和清空。移除的是 Clash 风格的连接、规则、Provider 管理和流量/内存仪表盘。

### 如何备份？

完全退出 ViaSix 后备份 `~/Library/Application Support/ViaSix/`。恢复时也应先退出应用，避免覆盖正在写入的数据。

## 文档

- [用户指南](Docs/USER_GUIDE.md)
- [开发说明](Docs/DEVELOPMENT.md)
- [架构说明](Docs/ARCHITECTURE.md)
- [虚拟网卡能力边界](Docs/VIRTUAL_NETWORK.md)
- [地址列表来源](Docs/ADDRESS_SOURCES.md)
- [发布指南](Docs/RELEASING.md)
- [安全政策](SECURITY.md)
- [隐私说明](PRIVACY.md)
- [第三方声明](THIRD_PARTY_NOTICES.md)

## 许可证

ViaSix 基于 [MIT License](LICENSE) 发布。第三方组件继续受各自许可证约束。
