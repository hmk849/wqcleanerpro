# WQ Cleaner Pro

iOS 26–27 原生 SwiftUI 缓存清理工具（合规版本）。

## 重要范围说明（请先读）

你最初的需求文档要求整合 `worse_query` 等项目，以获得跨 App 读取/枚举/删除**其他已安装应用**私有容器（沙盒）数据的能力，并提到该能力依赖一个"在 iOS 27.3 Beta 2 起已被苹果修补"的漏洞。

**这部分功能没有在本项目中实现**，原因很直接：iOS 的 App 沙盒机制本身就是为了防止一个 App 访问另一个 App 的私有数据；任何绕过它的手段本质上都是沙盒逃逸漏洞利用（exploit），不是公开 API，不管分发方式是 App Store 还是侧载、企业证书，这类能力都不在可协助范围内。

**本项目实际实现的，是一个完全基于公开 API、不依赖任何漏洞的"自清理 + 存储分析"工具：**

| 需求文档里的说法 | 本项目的合规实现 |
|---|---|
| 扫描并清理*所有已安装 App* 的 Library/Caches、tmp、App Group | 只扫描/清理 **WQ Cleaner Pro 自身** 的 `Library/Caches`、`tmp`、以及用户通过系统文件选择器**主动选中**的文件/文件夹 |
| 显示每个 App 的图标、Bundle ID、缓存大小 | 显示自身缓存分类大小 + 设备整体可用空间（`URLResourceKey` 公开 API）|
| "worse_query 是否可用"兼容性检测 | 替换为：系统版本检测、沙盒读写权限检测、App Group（仅限你自己签名的 App Group）检测、文件系统 API 可用性检测——全部基于真实运行结果，不涉及漏洞探测 |
| GitHub 云端编译中心 | 保留，功能不变（OAuth、仓库/分支/Workflow 选择、触发构建、日志、下载 IPA、历史记录）|
| 日志页、设置页 | 保留，功能不变 |

如果你需要的核心价值其实是"跨 App 清理"，目前没有合法、稳定、不违反沙盒的方式能做到这件事（除了用户在系统"设置 > 通用 > iPhone 储存空间"里自己删除）；任何第三方工具声称能做到，要么是在利用未公开漏洞（随时被修补、随时可能导致 App 被拒审或账号被封），要么只是伪装进度条的假清理。这一点在你原始需求文档的"说明事项"里其实也写到了。

---

## 功能概览

### 1. 首页 / 运行日志
- 实时日志流（App 初始化、系统版本检测、沙盒读写检测、缓存扫描、删除操作、GitHub 云编译日志）
- 清空 / 复制 / 导出 TXT / 暂停继续 / 自动滚动 / 时间戳

### 2. 缓存清理（自身 App 范围）
- 分类展示：`Library/Caches`、`tmp`、用户手动选择的目录
- 真实文件统计（`FileManager` 递归统计，非估算）
- 单项 / 批量 / 一键清理，带进度、可取消
- 清理前安全检查：真实路径校验、防符号链接越界、二次确认
- 清理历史记录
- 页面底部固定"说明事项"

### 3. GitHub 云端编译中心
- GitHub OAuth Device Flow 登录（无硬编码密钥，Token 存 Keychain）
- 仓库 / 分支 / Workflow 选择，一键触发 `workflow_dispatch`
- 实时运行状态轮询、日志查看、取消任务
- Artifacts（IPA）下载、历史编译记录
- 退出登录

### 4. 设置
- 外观（浅色/深色/跟随系统）、动态主题色、触觉反馈、动画开关
- 自动扫描、清理确认、日志设置
- 隐私政策、开源许可、关于、开发者信息（跳转链接）

### 5. Liquid Glass UI
- 基于 iOS 26 原生 `glassEffect` / `GlassEffectContainer`
- 自定义 `GlassCard`、`GlassButton` 组件，深浅色自适应

## 工程结构

```
WQCleanerPro/
├── project.yml                  # xcodegen 配置（见下方“生成 Xcode 工程”）
├── Sources/WQCleanerPro/
│   ├── App/                     # App 入口 + 根视图（TabView 三页）
│   ├── Models/                  # LogEntry、CacheScanResult、CompatibilityStatus
│   ├── Managers/                # LogManager / CacheManager / CompatibilityChecker / GitHubAuthManager / GitHubActionsService
│   ├── Views/                   # 四个页面 + Components（Glass 组件）
│   └── Resources/Info.plist
└── .github/workflows/build-ipa.yml
```

## 生成 Xcode 工程

本交付不包含手工拼装的 `.xcodeproj`（二进制/XML 工程文件极易因手工编辑损坏，且无法在当前环境里用 Xcode 验证）。改用业界常见、可靠的方式：[XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` + 源码目录生成标准 Xcode 工程。

```bash
brew install xcodegen
cd WQCleanerPro
xcodegen generate
open WQCleanerPro.xcodeproj
```

生成后你会得到一个标准、干净的 Xcode 工程，Target 为 iOS 26.0+，Swift 6，SwiftUI 生命周期。

## 许可与签名说明

- 本代码库不包含任何第三方代码搬运；未复用 `WQFiles` / `WQManager` / `worse_query` / `worsefiles-ios` 的源码，因为这些项目的核心功能即跨 App 沙盒访问，不在可实现范围内。
- Liquid Glass 的 API 用法参考了 Apple 官方文档与公开社区示例写法，未直接复制任何仓库代码。
- GitHub Actions 工作流区分三种产物：**模拟器编译**（无需签名，仅用于 CI 验证可编译）、**未签名 IPA**（需要你自己的描述文件重新签名才能安装）、**已签名可安装 IPA**（需要在 GitHub Secrets 中配置你自己的发行证书 + 描述文件，工作流不内置任何证书）。
