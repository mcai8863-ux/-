# 日进 0.1.15

修复 macOS 26 中应用图标外围出现白色框与空隙的问题。保留原有星球和旗帜图案，使用完全不透明的绿色底图重新生成全部 ICNS 尺寸。

构建使用 `assets/app-icon-planet-opaque.png`；原始透明图保留供设计参考。

验证结果：

- `swift test`：9 项通过，无失败。
- `./scripts/lint.sh`：通过。
- `./scripts/build-app.sh`：Release 构建通过。
- 使用 macOS `NSWorkspace.icon(forFile:)` 读取旧版和新版的系统图标，旧版存在白框，新版绿色背景已延伸至系统圆角边缘。
- 本次未修改应用功能、数据模型或存储路径。

系统图标对比保存在 `releases/0.1.15/icon-before.png` 和 `icon-after.png`。这是系统图标 API 的实际输出，不是 Dock 截图；电脑 UI 连接超时，因此未进行现场 Dock 截图验证。
