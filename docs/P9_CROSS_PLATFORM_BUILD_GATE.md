# K 线 V2 P9-02 跨平台构建门禁

> 任务：P9-02
>
> 状态：已通过
>
> 日期：2026-09-03

## 1. 验证环境

- Host：macOS 26.5.1，x86_64；
- Flutter：3.44.0 stable；Dart 3.12.0；
- Android：AGP 8.11.1，Profile/Release APK；
- iOS：无签名 Profile/Release App；
- Web：Profile/Release JavaScript 构建，并通过 Flutter 的 WebAssembly dry run。

## 2. 自动化入口

在 macOS 上执行：

```bash
FLUTTER_BIN=/path/to/flutter tool/run_p9_build_gate.sh
```

脚本串行构建六个目标，任一命令失败都会立即退出。iOS 构建使用 `--no-codesign`，用于验证 Dart AOT、插件集成和 Xcode 编译链；签名、归档及商店上传属于 P9-05 发布凭据流程。

## 3. 构建结果

| 平台 | 模式 | 命令 | 结果 |
| --- | --- | --- | --- |
| Android | Profile | `flutter build apk --profile` | 通过，APK 73.5 MB |
| Android | Release | `flutter build apk --release` | 通过，APK 51.6 MB |
| iOS | Profile | `flutter build ios --profile --no-codesign` | 通过，Runner.app 25.3 MB |
| iOS | Release | `flutter build ios --release --no-codesign` | 通过，Runner.app 16.9 MB |
| Web | Profile | `flutter build web --profile` | 通过，输出目录约 46.6 MiB |
| Web | Release | `flutter build web --release` | 通过，输出目录约 40.8 MiB |

Web 两种模式的 WebAssembly dry run 均通过；Release 的 `main.dart.js` 为 2,768,188 bytes，Profile 为 8,818,204 bytes。每次构建会覆盖同一平台的输出目录，因此表中保留的是各次命令完成时的记录，不用于包体积回归门槛。

## 4. 兼容处理

- Android 的空壳 Activity 从 Kotlin 等价迁移为 Java，应用模块不再应用即将被 Flutter 淘汰的旧 Kotlin Gradle Plugin 接入方式；Java source/target 更新为 17。两种 APK 重建后不再报告 Kotlin 或 Java 8 迁移警告。
- iOS 工程接受 Flutter 3.44 自动生成的 Swift Package Manager 插件集成和 Xcode Scheme prepare pre-action；Profile 与 Release 均验证通过。
- Web 动态数字解析统一使用 `num.toDouble()`，消除 WebAssembly 对 `double`/`int` 分支的兼容提示。
- Example 显式声明 `cupertino_icons`，确保 Web 图标字体可解析并允许 tree shaking；Flutter 同步清理了已废弃的 Web plugin registrant ignore 条目。

## 5. 发布边界

- Example 的 Android Release 当前按 Flutter 示例默认使用 debug signing，仅作为可安装构建门禁；正式发布必须在 P9-05 注入独立 keystore。
- iOS 本轮不执行签名、Archive 或 TestFlight 上传；这些动作需要发布证书和账户授权。
- Web 本轮验证编译兼容性与产物生成，不包含 CDN、缓存策略或浏览器部署验收。

结论：Android、iOS、Web 的 Profile 与 Release 六项构建全部通过，P9-02 可以关闭。下一项进入 P9-04：API diff、迁移指南、架构决策记录和完整 Example 审查。
