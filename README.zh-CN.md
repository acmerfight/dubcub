# SwiftSeed

[English](README.md) | **简体中文**

可复用的 iPhone 和 iPad SwiftUI 工程模板，包含严格的状态与渲染边界、核心 BDD 和经过验证的 CI。

代码仓库：[acmerfight/swiftseed](https://github.com/acmerfight/swiftseed)。作为模板复用请先阅读 [TEMPLATE.md](TEMPLATE.md)，其中包含初始化命令、仓库保护设置和发布前责任。设计取舍、官方依据和验证边界见 [工程审查记录](ENGINEERING.md)。

SwiftSeed 是用于创建多个独立 iPhone / iPad App 的工程模板。当前仅包含通用欢迎页，不预设具体业务。每个新 App 从 GitHub 的 **Use this template** 创建独立仓库，再按照 [初始化步骤](TEMPLATE.md) 替换名称与应用标识。

## 开发环境

- 本地基线 Xcode 26.3（`.xcode-version`），以及 iOS 平台组件；运行模拟器还需安装与电脑兼容的 iOS 模拟器运行时。
- Swift 6，最低部署版本 iOS / iPadOS 17。
- XcodeGen 2.46.0、SwiftFormat 0.62.1、SwiftLint 0.65.1，统一锁定在 `tools.lock.json`，本地与 CI 使用同一官方发布包。

安装开发辅助工具：

```sh
python3 scripts/tools.py install
bash scripts/doctor.sh
```

脚本在未指定 `DEVELOPER_DIR` 时优先使用 `/Applications/Xcode.app`，不会修改全局开发工具设置，并校验版本。已安装较新 Xcode 时，可显式指定 `DEVELOPER_DIR` 和 `EXPECTED_XCODE_VERSION=27.2` 运行同一检查；该版本必须经过实际验证。

## 开发与验证

工程配置以 `project.yml` 为准，生成的 Xcode 工程一并提交，便于直接打开。

```sh
python3 scripts/tools.py run xcodegen generate
open SwiftSeed.xcodeproj
bash scripts/check.sh
bash scripts/verify-builds.sh
bash scripts/test-simulator.sh iphone
bash scripts/test-simulator.sh ipad
```

`check.sh` 执行严格代码 lint、架构检查器的正反样例、渲染边界和代码格式检查。GitHub Actions 在 PR 上运行静态检查和编译，UI 测试独立定时或手动运行；合并后不立即重复执行。

### PR 与 CI

所有改动从分支提交 PR，检查通过后 squash 合并。`main` 禁止直接推送、强制推送和删除；管理员没有绕过名单。合并要求分支与主分支同步、审查讨论全部解决，以及 GitHub Actions 的 `Lint`、`Build`、`Security`、`CI required` 全部通过。最后一项汇总所有任务，失败、取消或意外跳过均不能放行。

仓库当前只有一位协作者，暂不要求他人批准，避免作者无法审批自己的 PR；有独立审查者后再启用至少一位审批。规则定义保存在 `.github/main-ruleset.json`，GitHub 的实际规则需要通过仓库设置或 API 应用，修改文件本身不会自动生效。

PR 运行静态检查、工程一致性检查，并分别以 Xcode 26.3 和 27.2 编译 Debug App / UI 测试代码及 Release 真机 SDK，不启动模拟器；`Current SDK` 纳入 `CI required`，汇总检查要求静态、安全和两套编译检查均成功，失败、取消或跳过均不能合并。双设备 UI 测试已拆到 `Scheduled UI tests`，不再阻断每次 PR。

UI 测试每 6 小时对主分支最新提交运行一次：UTC 00:17、06:17、12:17、18:17，即北京时间 02:17、08:17、14:17、20:17。避开整点以减少排队，GitHub 定时任务可能延迟，并非准点保证。也可在 Actions 中手动运行或使用 `gh workflow run ui-tests.yml --ref main`。失败需处理，发布前手动验证对应版本；代价是合并后才可能发现 UI 回归，正常调度下最长约 6 小时后开始检测。

PR 新提交取消旧检查，定时或手动 UI 任务不相互中断，测试结果保留 7 天。操作仅有读取仓库权限，外部 Action 固定到提交。新增测试目标必须加入共享 scheme，UI 测试脚本仍拒绝零测试或跳过测试。当前没有业务状态测试；后续新增状态层核心 BDD 时纳入每次代码 PR 的快速检查。

CI 的基线检查使用 Xcode 26.3，与本地一致；`Current SDK` 和双设备定时 UI 使用固定的 Xcode 27.2。后者使用 GitHub `xcode-27` 预览 runner，环境可用性风险见工程审查记录，失败不会自动跳过。辅助工具版本来自锁定文件。定时 UI 任务在工具安装后启动模拟器，启动等待与 `build-for-testing` 重叠；启动和编译均成功后，使用同一产物执行 `test-without-building`。日志分别记录编译、剩余启动等待、测试耗时，便于用实际数据判断优化效果。没有使用缓存测试结果、自动重试或减少设备覆盖来提速。

当前只有两个核心界面 BDD：已安装 App → 打开 → 看到欢迎信息；最大辅助字号、横屏 → 打开并向下阅读 → 文字不裁切且说明可达。后者包含系统无障碍审计，覆盖实际发现的阅读问题。后续按 [AGENTS.md](AGENTS.md) 在最低可靠层补充核心业务行为，不为凑数量创建测试。

#### 历史 CI 耗时实测（2026-11-11，UI 仍阻断 PR 时）

以下为从工作流创建到所有任务结束的耗时，包含排队；均使用标准免费 runner，每个设备实际执行一个欢迎页 BDD。

| 配置 | 完整验证耗时 | 运行记录 |
| --- | --- | --- |
| 优化前，PR | 8 分 04 秒 | [42935370368](https://github.com/acmerfight/swiftseed/actions/runs/42935370368) |
| 优化前，合并后重复执行 | 5 分 29 秒 | [42936507808](https://github.com/acmerfight/swiftseed/actions/runs/42936507808) |
| 优化后，PR | 7 分 59 秒 | [42941308463](https://github.com/acmerfight/swiftseed/actions/runs/42941308463) |

样本不能证明完整模拟器验证已稳定加速，且优化后固定了与本地一致的 Xcode 26.3。以上为拆分定时 UI 工作流之前的数据，不代表当前 PR 耗时。该次拆分通过调整测试频率缩短 PR 等待，保留了当时的 UI 用例、断言和双设备覆盖。

### 静态检查

- `.swiftlint.yml` 保留默认规则，补充强制解包、隐式解包、未处理的抛错任务、空代码块等检查；所有警告都视为错误。扫描整个仓库，仅排除构建产物，新建源码和测试目录自动纳入。
- SwiftFormat 统一格式；SwiftLint 中与之冲突的花括号位置、尾逗号规则关闭。运行 `python3 scripts/tools.py run swiftformat .` 修正格式，再运行 `bash scripts/check.sh`。
- Xcode 构建执行相同的 lint 与渲染边界检查，Swift 编译器警告也会阻断构建。工具缺失、版本不符或检查失败时明确报错，不自动跳过，也不在构建时下载工具。
- 不使用历史违规基线或全文件禁用掩盖问题。确有合理例外时，只对必要行豁免单条规则，并在旁边解释原因；规则变更必须审查。状态必要性、业务边界及纯函数语义仍需人工审查，lint 不能代替设计判断。

应用组合目标默认在主 actor 上隔离；渲染模块保持非隔离默认值，不将纯展示数据绑到界面线程。Swift 6 严格检查与 Approachable Concurrency 一起启用，异步不等于后台执行。

安装脚本校验官方发布包的 SHA-256，工具放在被忽略的 `.build/tools/`。升级时更新 `tools.lock.json`，重新安装并验证检查与编译。

### 安全检查

每次 PR 的 `Security` 检查在 Linux 上并行执行，并纳入必需检查及最终汇总门禁：Gitleaks 扫描完整 Git 历史中的密钥并脱敏输出；zizmor 审计工作流的权限、注入及供应链风险，发现问题直接失败；Dependency Review 阻止新增存在已知漏洞的依赖（包括低危及以上），不将扫描结果仅当作提示。

仓库要求 Action 固定完整 SHA，默认只读权限且不允许工作流批准 PR。GitHub Secret Scanning 和 Push Protection 保持开启；Dependabot 每周为 Actions 更新创建 PR，漏洞提醒与安全更新保持开启。更新 PR 同样经过合并门禁；启用仓库的 auto-merge 能力并不意味着所有未来 PR 自动合并，需要逐个明确启用。

当前没有第三方业务依赖，依赖检查主要覆盖 GitHub 能识别的清单和 Actions；手动下载的工具通过固定版本和 SHA-256 校验管理，升级需审查。上述检查不代替应用业务安全审查。安全工具版本或校验值变更也必须通过 PR。

启动模拟器：

```sh
bash scripts/run-simulator.sh iphone
bash scripts/run-simulator.sh ipad
```

脚本会生成工程、编译，创建或复用对应模拟器，然后安装并启动 App。

## 代码边界

所有编码与审查遵守 [AGENTS.md](AGENTS.md)。

- `SwiftSeed/SwiftSeedApp.swift`：应用组合入口，提供展示输入。
- `SwiftSeed/Rendering/`：独立渲染模块，只包含视图及不可变展示数据。应用依赖该模块，该模块不依赖应用实现。
- `HomeViewState` 是只读展示值，不是业务状态容器或持久化模型。当前没有需要创建业务状态层的交互。
- `scripts/architecture/`：基于语法树的边界检查，使用所选 Xcode 自带的 SwiftParser / SwiftSyntax。缺少解析器时检查失败，不会跳过。

检查覆盖渲染模块的导入、状态包装器、可变存储属性、引用状态定义及常见副作用入口；注释和普通字符串不作为代码误报。它不证明任意函数纯净，也不能判断状态是否必要。新增业务时仍需审查状态所有权和接口契约，并为实际业务规则增加相应约束与测试。

## 验证范围

本地开发基线为 Xcode 26.3；项目已通过架构规则样例、违规代码构建拦截、格式检查及模拟器编译，并在 iPhone 16 和 iPad A16 模拟器上完成安装、启动与画面检查。尚未验证真机签名与安装，当前没有业务功能可供验证。

真机运行需在 Xcode 中选择自己的签名团队，并确认设备与所选 Xcode 兼容。个人签名配置、构建产物和本地凭证不应提交。
