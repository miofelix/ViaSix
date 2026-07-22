# Windows 虚拟网卡（规划）

macOS 使用 XPC helper + utun。Windows 对应能力规划为：

```text
ViaSix UI
  → 请求 virtualInterface
  → Windows Service（提权、常驻）
  → Wintun 适配器
  → 固定签名 / 校验过的 mihomo（TUN 模式）
```

## 当前状态

| 项 | 状态 |
| --- | --- |
| API 表面 `virtual_network_*` | ✓ 已暴露 |
| 启用 | 失败关闭（返回明确错误） |
| Wintun 驱动集成 | 未做 |
| 特权 Windows Service | 未做 |

UI 中「虚拟网卡 / Wintun」开关为禁用态，仅展示能力说明。

## 实现前必须决策

1. **提权模型**：安装期 Service vs 每次 UAC  
2. **内核路径**：用户态 mihomo + Wintun vs 仅系统代理  
3. **签名**：Service/二进制是否要求 Authenticode  

在以上决策前，**不会**在本仓库启用真实 Wintun 改路由。

## 与 macOS 对照

| | macOS | Windows（规划） |
| --- | --- | --- |
| 特权边界 | LaunchDaemon + XPC | Windows Service + named pipe/ACL |
| 虚拟网卡 | utun | Wintun |
| 信任 | 代码签名 + CDHash | Authenticode + 服务 SID |
