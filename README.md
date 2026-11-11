# DubCub

A playful iOS app that helps kids practice English by dubbing fun cartoons and videos in their own voices.

代码仓库：[acmerfight/dubcub](https://github.com/acmerfight/dubcub)。

当前是支持 iPhone / iPad 的原生起始工程，只有静态欢迎页，尚未实现录音、配音、存储或导出。

## 开发环境

- 完整 Xcode 与 iOS 平台组件；运行模拟器还需安装与电脑兼容的 iOS 模拟器运行时。
- Swift 6，最低部署版本 iOS / iPadOS 17。
- XcodeGen 2.46.0 或以上；SwiftFormat 本地验证版本为 0.62.1。
- SwiftLint 版本固定在 `.swiftlint-version`，本地与 CI 使用同一官方二进制。

安装开发辅助工具：

```sh
brew install xcodegen swiftformat
bash scripts/install-swiftlint.sh
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
bash scripts/test-simulator.sh iphone
bash scripts/test-simulator.sh ipad
```

`check.sh` 执行严格代码 lint、架构检查器的正反样例、渲染边界和代码格式检查。GitHub Actions 在 PR 上运行检查，也支持手动执行完整验证；合并后不重复运行同一套检查。

### PR 与 CI

所有改动从分支提交 PR，检查通过后 squash 合并。`main` 禁止直接推送、强制推送和删除；管理员没有绕过名单。合并要求分支与主分支同步、审查讨论全部解决，以及 GitHub Actions 的 `Lint`、`Tests (iphone)`、`Tests (ipad)` 全部通过。

仓库当前只有一位协作者，暂不要求他人批准，避免作者无法审批自己的 PR；有独立审查者后再启用至少一位审批。规则定义保存在 `.github/main-ruleset.json`，GitHub 的实际规则需要通过仓库设置或 API 应用，修改文件本身不会自动生效。

CI 分开执行静态检查与两个设备的核心用户测试；重复提交取消旧任务，保留测试结果 7 天。操作仅有读取仓库权限，外部 Action 固定到提交。CI 在 PR 合并候选版本上运行。新增测试目标必须加入共享 scheme，测试脚本运行整个 scheme，零测试或跳过测试不能算成功。

只有 `README.md`、`AGENTS.md`、`.github/pull_request_template.md` 的纯文档变更可以免运行模拟器；三个必需检查仍实际运行，测试检查明确记录“不适用”，不冒充执行过测试。任何其他文件、空差异或手动运行都执行完整测试；变更识别失败会使测试检查失败。重命名同时检查旧、新路径，避免代码改名为文档时被误判。调整白名单必须审查，不能通过放宽规则处理失败。

CI 使用官方镜像预装的 Xcode 26.3，与本地基线一致；不在每次运行时自动更新 Homebrew。工具安装后启动模拟器，启动等待与 `build-for-testing` 重叠；启动和编译均成功后，使用同一产物执行 `test-without-building`。日志分别记录编译、剩余启动等待、测试耗时，便于用实际数据判断优化效果。没有使用缓存测试结果、自动重试或减少设备覆盖来提速。

当前只有一个核心界面 BDD：已安装 App → 打开 → 看到欢迎信息。后续按 [AGENTS.md](AGENTS.md) 在最低可靠层补充核心业务行为，不为凑数量创建测试。

### 静态检查

- `.swiftlint.yml` 保留默认规则，补充强制解包、隐式解包、未处理的抛错任务、空代码块等检查；所有警告都视为错误。扫描整个仓库，仅排除构建产物，新建源码和测试目录自动纳入。
- SwiftFormat 统一格式；SwiftLint 中与之冲突的花括号位置、尾逗号规则关闭。运行 `swiftformat .` 修正格式，再运行 `bash scripts/check.sh`。
- Xcode 构建执行相同的 lint 与渲染边界检查，Swift 编译器警告也会阻断构建。工具缺失、版本不符或检查失败时明确报错，不自动跳过，也不在构建时下载工具。
- 不使用历史违规基线或全文件禁用掩盖问题。确有合理例外时，只对必要行豁免单条规则，并在旁边解释原因；规则变更必须审查。状态必要性、业务边界及纯函数语义仍需人工审查，lint 不能代替设计判断。

安装脚本校验官方发布包的 SHA-256，工具放在被忽略的 `.build/tools/`。升级时同时更新 `.swiftlint-version` 和安装脚本中的校验值，重新安装并验证检查与编译。

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
