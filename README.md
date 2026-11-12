# SwiftSeed

A reusable SwiftUI project template for iPhone and iPad, with strict state/rendering boundaries, core BDD, and verified CI.

Repository: [acmerfight/swiftseed](https://github.com/acmerfight/swiftseed). Choose **Use this template** to create an independent app repository, then follow [TEMPLATE.md](TEMPLATE.md). The starter contains only a generic welcome screen. Coding requirements are in [AGENTS.md](AGENTS.md); decisions, sources, historical measurements, and verification limits are in [ENGINEERING.md](ENGINEERING.md).

## Start developing

Install Xcode 26.3 (the local baseline in `.xcode-version`), iOS platform components, a compatible simulator runtime, and Python 3.13 (pinned in `.python-version`) for pre-commit. The project uses Swift 6 and targets iOS / iPadOS 17 or later.

```sh
./dev setup
./dev doctor
open SwiftSeed.xcodeproj
./dev check
./dev build
./dev run iphone
./dev test ipad
```

Use `./dev help` for all commands. The same entry point is used locally, by Xcode, and in CI.

| Command | Result |
| --- | --- |
| `./dev setup` | Install all pinned tools with hash verification and install the commit hook |
| `./dev hooks run` | Check staged content without committing |
| `./dev hooks install` | Reinstall the hook after moving the checkout or repairing setup |
| `./dev doctor` | Verify Xcode, tools, hook installation, SDK, and compatible iPhone / iPad runtimes |
| `./dev check` | Check workflows, Shell, Python, Swift, architecture, generated project, core template acceptance, and Git secrets |
| `./dev format` | Apply Python lint fixes and Python / Swift formatting |
| `./dev generate` | Regenerate the Xcode project from `project.yml` |
| `./dev build` | Compile Debug app / UI tests and Release against the device SDK, without signing or simulator startup |
| `./dev run iphone` / `./dev run ipad` | Build, install, and launch on a compatible simulator |
| `./dev test iphone` / `./dev test ipad` | Execute core UI BDD and reject empty, failed, or skipped tests |
| `./dev init --name MyApp --bundle-id com.example.myapp` | Initialize a clean template, preserving binary resources |
| `./dev configure OWNER/REPO` | Apply repository protections with administrator access |
| `./dev ui-health OWNER/REPO` | Check enabled, successful, recent default-branch UI verification using an authenticated `gh` session |

CI uses focused subsets: `setup apple`, `setup portable`, `setup security`, and `check apple`, `check portable`, `check secrets`. Linux runs portable and security checks. The macOS lint job installs all tools because its acceptance scenarios exercise real commits; other Apple jobs install only Apple tools. `check swift` is the Xcode build-phase subset, and `check project` verifies generated outputs only. These are shared implementations, not separate CI rules.

Scripts prefer `/Applications/Xcode.app` when `DEVELOPER_DIR` is unset and validate its version without changing the global selection. For a validated newer installation, set `DEVELOPER_DIR` and `EXPECTED_XCODE_VERSION` explicitly.

## Project and tool ownership

`project.yml` is the configuration source of truth. Generated project files are committed for direct opening in Xcode. After configuration changes, run `./dev generate` and stage the generated files before `./dev check`. The project check generates a clean copy in a temporary directory and compares content and tracked file sets. Missing, modified, obsolete, and newly generated but untracked files fail; checking does not overwrite your working project.

`tools.lock.json` owns versions, official release URLs, and platform-specific SHA-256 hashes for SwiftLint, SwiftFormat, XcodeGen, actionlint, ShellCheck, Ruff, and Gitleaks. One installer verifies archives and extracts only the named executable and declared support resources into ignored `.build/tools/`. The same installer installs pre-commit into a project-local Python environment; `scripts/requirements-hooks.txt` pins its complete dependency set with hashes and permits only binary distributions. Builds and commits never download missing tools. Tool upgrades require reviewing the release source, version, hashes, and resulting checks. Dependabot updates Actions weekly; downloaded CLI tools and the Python dependency lock require reviewed updates together with `tools.lock.json`.

## Strict checks

- SwiftLint warnings and Swift compiler warnings are errors. SwiftFormat owns formatting. No legacy violation baseline or whole-file disables hide problems. Narrow exceptions require an explanation and review.
- SwiftLint adds focused checks for observer ownership, unavailable APIs, extension overrides, unnecessary escaping closures, and legacy drawing APIs. Duplicate whitespace and punctuation checks belong to SwiftFormat's required lint step. Rule selection and deliberately omitted checks are documented in [ENGINEERING.md](ENGINEERING.md#swift-rule-selection--2026-11-12).
- The syntax-tree architecture checker verifies rendering imports, state wrappers, mutable stored properties, reference state declarations, and common side-effect entry points. It uses the selected Xcode's SwiftParser / SwiftSyntax and fails if unavailable. It cannot prove arbitrary functions pure or decide whether state is necessary; those still require design review.
- actionlint validates every workflow, including scheduled jobs. Its explicitly selected ShellCheck also inspects embedded shell. ShellCheck separately scans repository shell files, and Ruff checks Python correctness, imports, and formatting. New script files are discovered automatically. Missing tools and failures are not skipped.
- Core template acceptance verifies that initializing a new app preserves binary artwork and generates the new identity, and that omitted generated files block delivery. Health acceptance verifies recent success and rejection of disabled, missing, failed, or stale UI verification. These are developer-visible promises, not internal coverage targets.
- Required security checks scan the full Git history with redacted Gitleaks output, audit workflow security with zizmor, and reject newly introduced known vulnerable dependencies of low severity or higher. Dependency review covers recognized manifests and Actions, not every manually downloaded binary. These checks do not replace application security review.

## Local commit checks

`./dev setup` installs the real Git pre-commit hook for this checkout. Existing users can run `./dev setup hooks` after installing the other tool groups. Each clone needs installation; Git does not copy active hooks. The installer preserves existing hooks using pre-commit's migration mode and refuses a conflicting `core.hooksPath` instead of silently overriding it. `./dev doctor` checks that the hook is executable and not redirected.

`.pre-commit-config.yaml` selects changed staged Swift, Python, Shell, and workflow files. It runs the same pinned tools and configuration as CI, including rendering boundaries for changed rendering files. Gitleaks checks the staged diff with redacted output. Hooks only check: they do not fix files, stage changes, build the app, or start simulators. Run `./dev format`, review the result, and stage the intended changes explicitly when a format check fails.

pre-commit temporarily hides unstaged changes while checking staged contents and restores them afterward. Core acceptance verifies partial staging, rejected commits preserving both index and working changes, redacted secret rejection, and renamed-template rendering checks. New hook configuration must itself be staged before committing. Missing tools fail with setup instructions; hook failures never silently install dependencies.

Use `./dev hooks run` for staged checks and `./dev hooks run --all-files` to inspect tracked files (its secret hook still scans the staged diff; `./dev check secrets` scans Git history). Policy-only changes and broader cross-file consistency are checked by full CI. Local hooks are a feedback aid and can be bypassed by Git; protected-branch CI remains authoritative. There is no duplicate pre-push build. UI verification remains every 6 hours.

## PRs and CI

All changes go through branches and PRs, then squash merging. Direct pushes, force pushes, and deletion of `main` are prohibited. The live rules have no bypass list and require an up-to-date branch, resolved review discussions, and successful `Lint`, `Build`, `Security`, and `CI required` checks. The aggregate requires all jobs, including `Current SDK`, to succeed; failures, cancellations, and unexpected skips cannot pass.

The repository currently has a sole maintainer, so approval by another reviewer is not required. Require at least one independent approval when a reviewer is available. `.github/main-ruleset.json` records the rules; changing that file alone does not update GitHub. Use `./dev configure OWNER/REPO` to apply them to a new repository.

Every PR runs static checks, template acceptance, and Debug / Release compilation with Xcode 26.3 and 27.2 without starting simulators. The newer SDK uses GitHub's `xcode-27` preview runner; availability risks are documented in ENGINEERING.md. New PR commits cancel obsolete checks. UI tests are not a per-PR gate. Future core business state BDD must join the fast per-code-PR gate when real business state exists.

Actions use full SHA pins, default to read-only permissions, and cannot approve PRs. Secret Scanning, Push Protection, vulnerability alerts, and security updates remain enabled. Update PRs pass the same gates. Auto-merge must be explicitly enabled per PR.

## UI verification and health

Core UI tests run on both iPhone and iPad every 6 hours on the default branch: 00:17, 06:17, 12:17, and 18:17 UTC. They cover opening the welcome screen and reading it in landscape at the largest accessibility text size, including system text-clipping and Dynamic Type audits. Add test targets to the shared scheme. Runs reject zero or skipped tests, retain results for 7 days, and do not automatically retry tests or cache their results.

Run manually through Actions or `gh workflow run ui-tests.yml --ref main`. Simulator startup overlaps compilation; the same build products are used for testing. Logs record build time, remaining startup wait, and test time. Scheduled and manual UI runs do not cancel an in-progress run.

A separate Linux health workflow runs hourly at minute 47 and can be dispatched manually. It fails when the UI workflow is disabled, its latest completed default-branch verification did not pass, or no successful run started within the last 8 hours. This allows 2 hours of grace around the 6-hour schedule. Manual default-branch UI runs count as verification; feature-branch runs do not. API failures fail the health check. The health monitor does not launch additional UI tests or change PR gates.

Enable Actions failure notifications for the schedule owner and address health failures. A new repository needs an initial manual default-branch UI run. [GitHub schedules can be delayed, dropped, or disabled after inactivity](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule); an hourly monitor on GitHub cannot detect an outage that also stops its own schedule. An external monitor is needed for an independent availability guarantee. Before release, manually verify the exact release commit on both device types; a recent success for another commit is insufficient.

## Code boundaries and release scope

`SwiftSeed/SwiftSeedApp.swift` composes the app. `SwiftSeed/Rendering/` is a separate module of views and immutable presentation values; it does not depend on the app. `HomeViewState` is read-only presentation data, not a business store or persistence model. There is no business state layer until an actual interaction needs one.

The app defaults to main-actor isolation; rendering keeps a nonisolated default. Swift 6 strict checks and Approachable Concurrency are enabled together. Asynchronous does not imply background execution.

Simulator checks and unsigned Release compilation do not verify physical-device signing, minimum-OS runtime behavior, distribution, or App Store submission. Product-specific privacy information, icons, signing, accessibility acceptance, licensing, and device-dependent behavior remain responsibilities of each new app. See [TEMPLATE.md](TEMPLATE.md) before release. Keep personal signing configuration, build outputs, and credentials out of Git.
