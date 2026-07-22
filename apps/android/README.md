# ViaSix for Android

**状态：骨架占位（阶段 2 实现前不可运行）。**

## 目标能力

| 阶段 | 能力 |
| --- | --- |
| MVP | 配置导入、contracts 对齐投影、mihomo + VpnService、测速/出口检测 |
| 不适用 | 系统代理（隐藏 `systemProxyEnabled`） |

## 建议技术选型

- Kotlin + Jetpack Compose
- 虚拟网卡：`android.net.VpnService`
- 内核：预编译 mihomo（`jniLibs` 或可执行文件）

配置与投影行为必须符合仓库根 [`contracts/`](../../contracts)。

## 目录

```text
apps/android/
├── README.md
├── settings.gradle.kts      # 占位
├── build.gradle.kts         # 占位
├── app/
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── java/dev/viasix/app/
└── gradle/
```

## 本地开发（占位）

完整 Gradle 工程将在 Android MVP 阶段生成。当前仅保留包名、清单与文档占位，避免未完成工程误导 CI。

从 monorepo 根目录：`make android-skeleton` 仅校验本骨架文件存在。
