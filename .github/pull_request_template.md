## 改动说明

请简要说明本次改动解决的问题及用户可见影响。涉及平台时请标明（macOS / Windows / Android / Linux 规划 / contracts / 共享库）。

## 验证

- [ ] 已运行相关检查（优先仓库根 `make check`，或仅受影响端的 `make windows-test` / `make android-test` / `cd apps/macos && make check`）
- [ ] 涉及 Swift 格式时，已在 `apps/macos` 运行 `make format`
- [ ] 涉及 macOS 打包或资源时，已运行 `make macos-app`（或 `cd apps/macos && make app`）
- [ ] 涉及跨端配置语义时，已更新 `contracts/` 并说明各端影响
- [ ] 已补充或更新相关测试
- [ ] 已同步更新相关文档、版本或第三方声明（平台矩阵 / roadmap 如有状态变化）

## 风险与兼容性

请说明配置迁移、进程生命周期、网络行为、旧版数据兼容或发布流程方面的风险；没有则填写“无”。
