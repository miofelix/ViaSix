# 为 ViaSix 部署 Cloudflare Pages VLESS 服务

本目录提供一套可直接生成、部署和验证的 Cloudflare Pages 服务端资源，面向需要把自建节点导入 ViaSix 或其他 Mihomo/VLESS 客户端的用户。

部署协议固定为：

```text
VLESS + WebSocket + TLS + TCP/443
```

当前 Worker 使用 Cloudflare TCP Sockets 直接连接目标站点，不使用、也不支持 ProxyIP。

> [!IMPORTANT]
> 请确保使用方式符合所在地区法律、Cloudflare 服务条款及目标网络的使用规则。ViaSix 不提供 Cloudflare 账号、网络线路或第三方代理服务。

## 功能与限制

支持：

- Cloudflare Pages Advanced Mode `_worker.js`；
- VLESS TCP over WebSocket；
- TLS 443 和自定义域名；
- UUID 鉴权；
- ViaSix/Mihomo YAML 和 VLESS 分享链接；
- Cloudflare IPv4/IPv6 优选地址；
- Wrangler 命令行和 Dashboard ZIP 上传。

不支持：

- ProxyIP；
- VLESS UDP、QUIC 或通用 UDP 转发；
- MUX；
- 80、8080、8880 等非 TLS 入口；
- 连接 Cloudflare 平台禁止的目标地址。

Cloudflare TCP Sockets 不允许连接 Cloudflare 自身 IP 段或形成 TCP loop。因此，不使用 ProxyIP 时，部分同样托管在 Cloudflare 上的目标网站可能无法访问。这是平台限制，不是客户端配置错误。

## 文件说明

- `worker-template.js`：ViaSix 维护的精简 VLESS/TCP Worker 模板。
- `scripts/prepare-deploy.sh`：写入 UUID，生成上传目录和 ZIP。
- `scripts/deploy-pages.sh`：通过 Wrangler 创建并部署 Pages 项目。
- `scripts/generate-client-config.sh`：生成 Mihomo YAML 和分享链接。
- `scripts/verify-deployment.sh`：检查域名、证书和配置端点。
- `mihomo-vless.example.yaml`：手动配置示例。

## 1. 环境要求

- 一个可使用 Workers & Pages 的 Cloudflare 账号；
- macOS 自带的 `zsh`、`curl`、`zip` 和 `uuidgen`；
- Wrangler 部署需要 Node.js 和 `npx`；
- 网页上传不需要 Node.js。

进入部署目录：

```bash
cd Server/CloudflarePages
```

## 2. 创建私有 UUID

```bash
umask 077
uuidgen | tr '[:upper:]' '[:lower:]' > .uuid
```

`.uuid` 是访问凭据，已经被 `.gitignore` 排除。不要将它提交到 Git、公开聊天、截图或日志。

## 3. 生成 Pages 上传资源

```bash
./scripts/prepare-deploy.sh --uuid-file .uuid
```

生成结果：

```text
dist/
├── pages-upload/
│   └── _worker.js
└── viasix-cloudflare-pages.zip
```

脚本只会把 UUID 写入本地 Worker 模板，不会下载或注入第三方代码，也不会添加 ProxyIP。

## 4. 使用 Wrangler 部署

首次部署先登录：

```bash
npx wrangler@4 login
```

创建或更新生产项目：

```bash
./scripts/deploy-pages.sh --project-name "viasix-edge"
```

项目不存在时，脚本会先创建 Pages 项目；默认生产分支为 `main`。

部署预览版本：

```bash
./scripts/deploy-pages.sh \
  --project-name "viasix-edge" \
  --branch "pages-test"
```

部署脚本只允许上传目录中存在一个 `_worker.js`，避免把客户端配置和 UUID 分享文件作为静态资源发布。

## 5. 使用 Dashboard 上传

不使用 Wrangler 时：

1. 登录 Cloudflare Dashboard。
2. 打开 **Workers & Pages**。
3. 选择 **Create application → Get started → Drag and drop your files**。
4. 输入项目名。
5. 上传 `dist/viasix-cloudflare-pages.zip`。
6. 选择 **Deploy site**。

不要上传整个 `dist/`，其中的客户端配置同样包含 UUID。

## 6. 绑定自定义域名

在 Cloudflare Pages 项目中打开 **Custom domains**，添加自己的域名并等待 DNS 与证书状态正常。

例如：

```text
viasix.example.com
```

使用自定义域名后，TLS SNI、WebSocket Host 和客户端配置必须全部使用该域名。

## 7. 验证 Pages 部署

```bash
./scripts/verify-deployment.sh \
  --host "viasix.example.com" \
  --uuid-file .uuid
```

脚本会检查：

- HTTPS 和证书；
- `https://<域名>/<UUID>` 配置页；
- `https://<域名>/<UUID>/pcl` Mihomo 配置；
- UUID、TLS、SNI 和 WebSocket 路径一致性。

该脚本不模拟完整 VLESS 数据传输。部署后仍需使用 ViaSix、Mihomo 或 Xray 访问一个非 Cloudflare 托管的 HTTPS 站点进行数据面测试。

## 8. 生成 ViaSix 客户端配置

```bash
./scripts/generate-client-config.sh \
  --host "viasix.example.com" \
  --uuid-file .uuid
```

生成结果：

```text
dist/client/
├── viasix-mihomo.yaml
└── viasix-vless-link.txt
```

推荐在 ViaSix 中导入 `dist/client/viasix-mihomo.yaml`。分享链接文件只包含一行 `vless://` 链接，也可以在“配置 → 分享链接”中粘贴导入。

## 9. ViaSix 必要设置

在 ViaSix“设置 → 本机代理”中：

- 路由模式选择“规则”或“全局”；
- 关闭 UDP；
- 首次排错时使用 `info` 日志级别；
- 确认出口 IP 检测和普通 HTTPS 访问成功后，再启用系统代理或 TUN。

必须关闭 UDP。ViaSix 的全局 UDP 选项会覆盖节点 YAML 中的 `udp: false`，而本 Worker 仅实现 TCP。

## 10. 使用 Cloudflare 优选 IP

可以只替换客户端节点的 `server`，但以下字段必须继续使用 Pages 域名：

```text
port: 443
tls: true
servername: viasix.example.com
WebSocket Host: viasix.example.com
WebSocket path: /?ed=2560
```

生成 IPv4 优选配置：

```bash
./scripts/generate-client-config.sh \
  --host "viasix.example.com" \
  --uuid-file .uuid \
  --server "104.16.0.1"
```

生成 IPv6 优选配置：

```bash
./scripts/generate-client-config.sh \
  --host "viasix.example.com" \
  --uuid-file .uuid \
  --server "2606:4700::1"
```

IPv6 地址不需要手动添加方括号。

## 11. 更新已有部署

修改 Worker 或更换 UUID 后，重新执行：

```bash
./scripts/prepare-deploy.sh --uuid-file .uuid
./scripts/deploy-pages.sh --project-name "viasix-edge"
./scripts/generate-client-config.sh \
  --host "viasix.example.com" \
  --uuid-file .uuid
```

然后在客户端重新导入生成的 YAML。

## 12. 常见问题

### 域名和 WebSocket 正常，但 HTTPS 目标无法访问

先确认 ViaSix 已关闭 UDP，并使用未托管在 Cloudflare 上的 HTTPS 站点测试。如果只有 Cloudflare 托管目标失败，通常是 Cloudflare TCP loop 限制；本实现不会使用 ProxyIP 绕过该限制。

### 出口 IP 检测报 TLS 错误

检查：

```text
port: 443
tls: true
servername: Pages 域名或自定义域名
WebSocket Host: 与 servername 相同
WebSocket path: /?ed=2560
skip-cert-verify: false
```

然后确认部署的是本目录重新生成的 `_worker.js`，而不是旧版参考项目 Worker。

### 验证脚本通过，但代理仍不可用

验证脚本只检查控制面和 WebSocket 入口。请检查 Pages Functions 日志，并使用 ViaSix/Mihomo/Xray实际访问 HTTPS 站点。

### 打开域名只显示运行提示

节点配置地址需要包含 UUID：

```text
https://viasix.example.com/<UUID>
```

### 可以使用公共 ProxyIP 吗

不可以。本 Worker 不包含 ProxyIP 逻辑。公共 ProxyIP 可能失效、记录流量或被滥用；如必须解决 Cloudflare 目标限制，应改用自己维护的服务器方案。

## 安全说明

以下文件包含 UUID：

```text
.uuid
dist/pages-upload/_worker.js
dist/viasix-cloudflare-pages.zip
dist/client/viasix-mihomo.yaml
dist/client/viasix-vless-link.txt
```

如果 UUID 泄露，请生成新 UUID、重新生成 Worker、重新部署，并在客户端重新导入配置。
