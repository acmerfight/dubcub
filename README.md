# DubCub

A playful iOS app that helps kids practice English by dubbing fun cartoons and videos in their own voices.

代码仓库：[acmerfight/dubcub](https://github.com/acmerfight/dubcub)。

当前是支持 iPhone / iPad 的原生起始工程，只有静态欢迎页，尚未实现录音、配音、存储或导出。

## 开发环境

- 完整 Xcode 与 iOS 平台组件；运行模拟器还需安装与电脑兼容的 iOS 模拟器运行时。
- Swift 6，最低部署版本 iOS / iPadOS 17。
- XcodeGen 2.46.0 或以上；SwiftFormat 本地验证版本为 0.62.1。

安装开发辅助工具：

```sh
brew install xcodegen swiftformat
bash scripts/doctor.sh
```

脚本在未指定 `DEVELOPER_DIR` 时优先使用 `/Applications/Xcode.app`，不会修改全局开发工具设置。

## 开发与验证

工程配置以 `project.yml` 为准，生成的 Xcode 工程一并提交，便于直接打开。

```sh
xcodegen generate
open DubCub.xcodeproj
bash scripts/check.sh
bash scripts/build-simulator.sh
```

`check.sh` 验证架构检查器的正反样例、渲染边界和代码格式。渲染边界检查也接入 Xcode 构建，违规会使构建失败。GitHub Actions 对推送和拉取请求运行检查、模拟器编译及工程生成一致性检查。

启动模拟器：

```sh
bash scripts/run-simulator.sh iphone
bash scripts/run-simulator.sh ipad
```

脚本会生成工程、编译，创建或复用对应模拟器，然后安装并启动 App。

## 代码边界

所有编码与审查遵守 [AGENTS.md](AGENTS.md)。

- `DubCub/DubCubApp.swift`：应用组合入口，提供展示输入。
- `DubCub/Rendering/`：独立渲染模块，只包含视图及不可变展示数据。应用依赖该模块，该模块不依赖应用实现。
- `HomeViewState` 是只读展示值，不是业务状态容器或持久化模型。当前没有需要创建业务状态层的交互。
- `scripts/architecture/`：基于语法树的边界检查，使用所选 Xcode 自带的 SwiftParser / SwiftSyntax。缺少解析器时检查失败，不会跳过。

检查覆盖渲染模块的导入、状态包装器、可变存储属性、引用状态定义及常见副作用入口；注释和普通字符串不作为代码误报。它不证明任意函数纯净，也不能判断状态是否必要。新增业务时仍需审查状态所有权和接口契约，并为实际业务规则增加相应约束与测试。

## 验证范围

本地开发基线为 Xcode 26.3；项目已通过架构规则样例、违规代码构建拦截、格式检查及模拟器编译，并在 iPhone 16 和 iPad A16 模拟器上完成安装、启动与画面检查。尚未验证真机签名与安装，当前也没有录音业务可供验证。

真机运行需在 Xcode 中选择自己的签名团队，并确认设备与所选 Xcode 兼容。个人签名配置、构建产物和本地凭证不应提交。
