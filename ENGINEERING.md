# Engineering baseline review · 2026-11-11

Scope: a single-maintainer, public, unreleased native iPhone / iPad starter project. The objective is a verifiable engineering baseline that can be maintained over time, not a claim that one architecture or toolset is universally best. AGENTS.md remains authoritative for mandatory coding requirements; this document records decisions and evidence.

## Findings and implementation

| Topic | Decision and implementation | Official references |
| --- | --- | --- |
| Language and UI | Retain Swift 6 strict concurrency checking and native declarative UI. Compiler versions and language modes differ; a newer compiler does not imply setting the language mode to 6.4. | [Swift 6.4](https://www.swift.org/blog/swift-6.4-released/), [Xcode support matrix](https://developer.apple.com/xcode/system-requirements) |
| Concurrency defaults | Enable Approachable Concurrency. The app composition target defaults to MainActor, while rendering keeps a nonisolated default so immutable presentation data is not unintentionally tied to the main thread. Views follow the framework's isolation. Explicitly choose where future expensive work executes rather than inferring it from async. | [Build settings](https://developer.apple.com/documentation/xcode/build-settings-reference), [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) |
| State and modules | Retain a separate read-only rendering module with static boundary checks. Deliver future work as vertical user slices, introducing state modules only for real business needs. Do not prebuild global stores, dependency injection frameworks, or empty architectural layers. Strict stateless rendering is a project constraint, not an Apple requirement for every app. | [SwiftUI scenes](https://developer.apple.com/documentation/swiftui/scenes); see AGENTS.md for architecture choices |
| iPad and accessibility | Adapt layout to window space, support all orientations, retain scene lifecycle, and do not force full screen to avoid adaptation. The welcome screen scrolls when height is insufficient. A BDD verifies reading in landscape at the largest accessibility text size, with a narrow-window preview as well. | [iPad design](https://developer.apple.com/videos/play/wwdc2025/208/), [Accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) |
| Test layers | Prefer Swift Testing for new pure business behavior at the lowest reliable layer without a simulator; use XCTest for UI paths. There is no business state yet, so no placeholder tests. Keep a few core UI BDD scenarios, run them every 6 hours, and execute them before delivering relevant UI fixes. | [Apple testing strategy](https://developer.apple.com/documentation/xcode/testing), [Choosing test frameworks](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project) |
| Toolchains | Pin the local baseline to 26.3 in `.xcode-version` and validate the actual version in entry scripts. Every PR verifies Debug test compilation and Release device SDK builds with both 26.3 and 27.2; newer-toolchain failures also block the aggregate gate. Scheduled UI tests use 27.2 runtimes on both device types. | [Xcode support matrix](https://developer.apple.com/xcode/system-requirements), [GitHub image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) |
| Supply chain and merging | Retain PRs, no bypass list, full SHA pins, read-only permissions, secret scanning, and dependency vulnerability checks. Repository setup additionally enforces action SHA pins and prevents workflows from approving PRs. Pin helper tools and verify hashes; upgrade through PRs rather than automatically following latest. | [GitHub security guidance](https://docs.github.com/en/actions/reference/security/secure-use) |

## Why the local baseline was not upgraded immediately

At the time of review, Apple's listed stable version was Xcode 27.2, requiring macOS Tahoe 26.6 or later. The local `MacBookPro15,1` officially supports up to Sequoia, so the working 26.3 baseline is retained while the cloud verifies the newer SDK. New projects on supported newer Macs may promote a validated newer version to the local baseline without maintaining two toolchains indefinitely. [Apple model information](https://support.apple.com/en-gb/108052)

GitHub's standard `xcode-27` runner was still marked public preview. It provides stable Xcode, but the image itself has no formal SLA. This environment risk is explicitly accepted here; failures must not trigger automatic downgrades, skips, or relaxed checks. Template users may select a validated stable image instead. Standard runners are free for public repositories; private repository quotas are separate. [Image announcement](https://github.com/actions/runner-images/issues/14404), [Runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## Complete with real features, not empty scaffolding

- Add core state BDD to every PR's fast gate when the first business slice exists. Verify persistence by actually reading results back. Device-dependent behavior and its actual effects require physical-device verification.
- Implement cancellation, stale-result rejection, and failures when asynchronous tasks appear. Verify window isolation when multiwindow interaction exists. Do not add fake tasks or state tests to the current static page.
- Commit lock files and review provenance when adding dependencies. Measure performance problems before deciding on caching, background processing, or finer module boundaries.
- When product localization is required, use string catalogs and localized formatting. Translate where presentation inputs are assembled; do not read implicit business resources from pure rendering. The current sample is English-only and does not claim multilingual support. [String catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- Complete privacy manifests, permission descriptions, and store privacy information from actual APIs, SDKs, and data uses. There are currently no business SDKs or data collection; empty files must not imply that privacy work is complete. [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

## Verification limits and ongoing maintenance

A minimum deployment target of 17 only constrains the APIs allowed by the compiler. It does not prove runtime acceptance on iOS / iPadOS 17. Release support must cover core paths on both the minimum supported and current systems; results from 26 / 27 simulators are not evidence of verification on every system.

Automated accessibility audits do not replace actual VoiceOver, keyboard, or resizable iPad window checks. Unsigned Release compilation does not replace signed archives, physical-device execution, or store uploads. Reusing projects remain responsible for signing, icons, versions, distribution, licensing, and actual product privacy information.

Review versions, sources, generated project differences, and core BDD whenever upgrading toolchains or dependencies. Update this record when SDK requirements change, runners are retired, or real user issues arise. Keeping versions pinned forever is not reproducibility.

#### Historical CI measurements (2026-11-11, when UI tests still gated PRs)

These durations run from workflow creation to completion of all jobs, including queuing. All runs used standard free runners and executed one welcome-screen BDD per device.

| Configuration | Full verification time | Run |
| --- | --- | --- |
| Before optimization, PR | 8 min 04 sec | [42935370368](https://github.com/acmerfight/swiftseed/actions/runs/42935370368) |
| Before optimization, duplicate post-merge run | 5 min 29 sec | [42936507808](https://github.com/acmerfight/swiftseed/actions/runs/42936507808) |
| After optimization, PR | 7 min 59 sec | [42941308463](https://github.com/acmerfight/swiftseed/actions/runs/42941308463) |

These samples do not establish a consistent speedup for full simulator verification. The optimization also pinned Xcode 26.3 to match local development. These measurements predate the separate scheduled UI workflow and do not represent current PR durations. That later split reduced PR waiting by changing test frequency while preserving the UI cases, assertions, and coverage of both device types that existed at the time.


## Developer workflow audit follow-up · 2026-11-12

The public command surface is `./dev`. Apple tasks share build arguments and simulator selection; every downloaded CLI tool uses `tools.lock.json` and one verified installer. Portable CI checks all repository Shell and Python scripts as well as workflow YAML. A clean project generation is compared against tracked outputs to reject missing, stale, or untracked generated files without overwriting the working project. Template acceptance covers initialization with binary artwork and omission of a generated scheme.

UI verification remains every 6 hours. A separate hourly Linux health check requires a recent successful default-branch UI run and fails for disabled workflows or failed verification. The 8-hour threshold includes scheduling grace; GitHub delay can also affect the monitor. Manual default-branch verification restores freshness but does not prove cron execution. GitHub-wide scheduling outages still require an external monitor. [GitHub schedule limitations](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule), [Notification ownership](https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs).

## Swift rule selection · 2026-11-12

The policy favors actionable diagnostics and a clear owner for each check. It is a template-specific decision, not a universal community rule set. [Swift's API guidelines](https://www.swift.org/documentation/api-design-guidelines/) prioritize clarity at the call site; naming, state ownership, and interface quality still need review.

| Decision | Reason |
| --- | --- |
| Add `discarded_notification_center_observer` | Retain block-observer tokens so subscriptions can be removed. This checks retention, not eventual cleanup. [Rule](https://realm.github.io/SwiftLint/discarded_notification_center_observer.html) |
| Add `unavailable_function` | Mark unsupported entry points unavailable instead of exposing an implementation that only traps. [Rule](https://realm.github.io/SwiftLint/unavailable_function.html) |
| Add `override_in_extension` | Reject unsupported extension-based overrides; keep overrides on the owning class. [Rule](https://realm.github.io/SwiftLint/override_in_extension.html) |
| Add `unneeded_escaping` | Avoid claiming a longer closure lifetime when it is only invoked synchronously. This is a syntax check, not a proof of ownership. [Rule](https://realm.github.io/SwiftLint/unneeded_escaping.html) |
| Add `legacy_uigraphics_function` | Prefer the renderer API over legacy image-context functions. The local Xcode 26.3 header uses `API_TO_BE_DEPRECATED`, so do not assume compiler warnings already reject them. [Rule](https://realm.github.io/SwiftLint/legacy_uigraphics_function.html) |
| Remove eight duplicate SwiftLint format checks | Colon, comma, semicolon, leading/trailing whitespace, final newline, repeated blank lines, and return-arrow spacing are enforced by the pinned formatter in the required check. Their replacement rules are named in `.swiftlint.yml`. Existing brace/comma conflict exclusions remain. [Formatter rules](https://github.com/nicklockwood/SwiftFormat/blob/0.62.1/Rules.md) |
| Retain focused safety and complexity checks | Force operations, task errors, delegate ownership, super calls, unexplained empty blocks, empty XCTest methods, and complexity limits remain enforced. Deliberately empty blocks can explain their purpose with a comment. [Empty-block behavior](https://realm.github.io/SwiftLint/no_empty_block.html) |

Do not enable every opt-in rule. SwiftLint identifies false positives, cost, and lack of consensus as reasons rules are opt-in; even [its own configuration](https://github.com/realm/SwiftLint/blob/0.65.1/.swiftlint.yml) excludes many style constraints. Keep formatter defaults rather than duplicating its style policy in a second tool. [SwiftLint selection guidance](https://github.com/realm/SwiftLint#opt-in-rules), [using both tools](https://github.com/nicklockwood/SwiftFormat#faq).

Deliberate omissions:

- Swift 5 compatibility annotations: this unreleased app uses Swift 6; `incompatible_concurrency_annotation` adds compatibility annotations rather than strengthening concurrency safety. [Rule](https://realm.github.io/SwiftLint/incompatible_concurrency_annotation.html)
- Mandatory paired XCTest setup/teardown: cleanup belongs to actual resources, often via `defer` or teardown blocks. Requiring an otherwise empty method adds ceremony without proving cleanup. [Rule](https://realm.github.io/SwiftLint/balanced_xctest_lifecycle.html)
- Mandatory documentation on every symbol, explicit types/access everywhere, magic-number bans, and extra layout rules: these can add noise without proving the architectural requirements. Document meaningful public contracts and review their use.
- Full `unused_declaration` / `unused_import` analysis: these require a separate clean compiler-log analysis and are considerably slower than lint. Reconsider when code size and demonstrated dead-code problems justify that cost. No analyzer coverage is claimed. [Analyzer requirements](https://github.com/realm/SwiftLint#analyze)
- Additional feature-specific UIKit, localization, and accessibility rules: evaluate false positives against real usage before enabling them. Syntax rules do not replace accessibility audits or device acceptance.

Verification used the pinned tools and actual configuration: all five newly selected diagnostics were absent before the change, then rejected their violating examples while accepting corrected examples. All eight delegated format categories were rejected by SwiftFormat and passed after formatting. These are configuration acceptance probes, not a duplicate permanent suite for upstream rule implementations. Application behavior, required PR checks, and the six-hour UI schedule are unchanged.


## Local commit feedback · 2026-11-13

Use the pre-commit framework to handle partial staging and hook installation, with local entries calling the shared `./dev` checks. Fast read-only checks run on staged files; Gitleaks scans the staged diff with redaction. CI retains whole-repository checks, real hook acceptance, dual-toolchain builds, and the unchanged six-hour UI schedule. The hook is installed by setup for each clone; it is not a replacement for branch protection. [Staged-content behavior](https://pre-commit.com/#pre-commit), [Git hook limitations](https://git-scm.com/docs/githooks#_pre_commit).

pre-commit 4.7 requires Python 3.11+. The project pins Python 3.13 in `.python-version`; the installer and CI use that same minor version and create an isolated environment under `.build/tools/`, leaving system Python unchanged. `tools.lock.json` owns the framework version; `scripts/requirements-hooks.txt` records its resolved dependencies and artifact hashes. Installation requires hash checking and wheels, without unpinned dependency resolution or source builds. [Upstream Python requirement](https://github.com/pre-commit/pre-commit/blob/v4.7.0/setup.cfg), [pip hash checking](https://pip.pypa.io/en/stable/topics/secure-installs/).

To update the dependency lock, resolve the version declared in `tools.lock.json` for the Python version in `.python-version` across supported platforms, generate hashes (for example with `uv pip compile --universal --python-version 3.13 --generate-hashes`), and review the full dependency diff. Reinstall using `./dev setup hooks` and verify actual commits on macOS CI. The resolver is a maintainer tool, not a runtime dependency. Keep the minimum pre-commit version in the hook configuration aligned with the lock. The initial cloud installation rejected PyYAML because its selected interpreter had no matching wheel; explicitly selecting Python 3.13 retains hash checking and the ban on source builds.
