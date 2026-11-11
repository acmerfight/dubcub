# 工程基线审查 · 2026-11-11

适用范围：个人维护、公开仓库、iPhone / iPad 原生起始工程，尚未发布。结论是建立可验证、可持续更新的工程基线，不宣称一种架构或一组工具是所有项目的唯一最佳实践。编码硬性约束仍以 AGENTS.md 为准；本文记录选择及依据。

## 调研结论与落实

| 主题 | 判断与措施 | 官方依据 |
| --- | --- | --- |
| 语言与界面 | 保留 Swift 6 严格并发检查和原生声明式界面。编译器版本与语言模式不同；使用较新编译器不意味着把语言模式写成 6.4。 | [Swift 6.4](https://www.swift.org/blog/swift-6.4-released/)、[Xcode 支持表](https://developer.apple.com/xcode/system-requirements) |
| 并发默认值 | 启用 Approachable Concurrency；应用组合目标默认 MainActor，渲染模块保持 nonisolated 默认值，让不可变展示数据不被无意绑到主线程；视图遵循框架自身隔离。后续耗时工作显式安排执行位置，不靠 async 猜测。 | [构建设置](https://developer.apple.com/documentation/xcode/build-settings-reference)、[Swift 并发](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) |
| 状态与模块 | 保留独立、只读渲染模块及静态边界约束。后续按用户闭环纵向切分，真实业务出现后才建立状态模块；不预建全局 Store、依赖注入框架或多层空目录。严格无状态渲染是本项目约束，并非 Apple 对所有工程的要求。 | [SwiftUI scenes](https://developer.apple.com/documentation/swiftui/scenes)；具体架构取舍见 AGENTS.md |
| iPad 与可访问性 | 布局跟随窗口空间，支持所有方向，保留 scene 生命周期，不使用强制全屏规避适配。欢迎页在高度不足时可滚动；补一条最大辅助字号、横屏仍可阅读的 BDD，并提供窄窗口预览。 | [iPad 设计](https://developer.apple.com/videos/play/wwdc2025/208/)、[无障碍审计](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) |
| 测试分层 | 新增纯业务行为优先使用 Swift Testing，在不启动模拟器的最低可靠层验证；UI 路径使用 XCTest。当前没有业务状态，不创建占位测试。保留少量核心 UI BDD，每 6 小时运行；有相关界面修复时交付前实际执行。 | [Apple 测试策略](https://developer.apple.com/documentation/xcode/testing)、[测试框架选择](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project) |
| 工具链 | `.xcode-version` 固定本地 26.3；入口脚本校验实际版本。每次 PR 同时验证 26.3 与 27.2 的 Debug 测试代码和 Release 真机 SDK 编译；新工具链失败同样阻止汇总门禁通过。定时 UI 使用 27.2 的双设备运行时。 | [Xcode 支持表](https://developer.apple.com/xcode/system-requirements)、[GitHub 镜像](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) |
| 供应链与合并 | 保留 PR、无绕过名单、完整 SHA、只读权限、密钥扫描及依赖漏洞检查。仓库初始化进一步强制 Action SHA 固定，禁止工作流批准 PR。辅助工具锁版本、验摘要；升级经过 PR，不自动追随 latest。 | [GitHub 安全建议](https://docs.github.com/en/actions/reference/security/secure-use) |

## 为什么没有直接把本地升级到最新

审查时 Apple 列出的正式版为 Xcode 27.2，要求 macOS Tahoe 26.6 或更新系统。本机 `MacBookPro15,1` 官方系统支持止于 Sequoia，因此保留可工作的 26.3，并由云端验证新 SDK。新项目使用受支持的较新 Mac 时，可以将经过验证的新版提升为本地基线，而无需长期维护双工具链。[Apple 机型说明](https://support.apple.com/en-gb/108052)

GitHub 的 `xcode-27` 标准 runner 当时仍标为 public preview。它提供正式 Xcode，但镜像本身无正式 SLA；此处明确接受该运行环境风险，不允许失败后自动降级、跳过或放松检查。模板使用者可改用经验证的正式镜像。公开仓库标准 runner 免费，私有仓库额度另计。[镜像公告](https://github.com/actions/runner-images/issues/14404)、[runner 说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## 必须随真实功能完成，而不是预建空壳

- 第一个业务闭环出现时，把核心状态 BDD 加入每次 PR 的快速门禁；保存结果要实际重新读取。依赖设备能力的行为及实际效果必须在真机验证。
- 出现异步任务时实现取消、过期结果丢弃和失败结果；出现多窗口交互时验证窗口隔离。当前静态页面不添加假任务和状态测试。
- 引入依赖时提交锁文件并审查来源；出现性能问题后先测量，再决定缓存、后台处理或更细的模块划分。
- 需要多语言时使用字符串目录及本地化格式，翻译在展示输入形成处完成；不要在纯渲染层读取隐式业务资源。当前保留原中文示例，不虚报多语言支持。[字符串目录](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- 根据实际 API、SDK 和数据用途填写隐私清单、权限说明及商店隐私信息。当前无业务 SDK 和数据采集，不用空文件制造“隐私已完成”的印象。[隐私清单](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

## 验证边界与后续维护

配置最低部署版本 17 只证明编译器允许使用的 API 范围，不证明已经在 iOS / iPadOS 17 运行验收。发布支持范围必须覆盖最低支持系统与当前系统的关键路径；本文不把 26 / 27 模拟器结果冒充所有系统验证。

自动化无障碍审计不能替代真实 VoiceOver、键盘与可调整 iPad 窗口体验检查；无签名 Release 编译不能替代签名归档、真机运行或商店上传。签名、图标、版本、分发、许可证以及真实产品隐私信息仍由复用项目完成。

每次升级工具链或依赖都审查版本、来源、生成工程差异及核心 BDD。SDK 新要求、runner 淘汰或实际用户问题出现时更新此决策记录；不要把固定版本永久不升级误认为可复现。
