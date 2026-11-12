# SwiftSeed

A reusable SwiftUI project template for iPhone and iPad, with strict state/rendering boundaries, core BDD, and verified CI.

Repository: [acmerfight/swiftseed](https://github.com/acmerfight/swiftseed). To reuse this template, start with [TEMPLATE.md](TEMPLATE.md), which covers initialization, repository protections, and responsibilities before release. See the [engineering review](ENGINEERING.md) for design decisions, official references, and verification limits.

SwiftSeed is a starting point for multiple independent iPhone and iPad apps. It currently contains a generic welcome screen with no predefined business features. For each new app, choose **Use this template** on GitHub to create a separate repository, then follow the [initialization steps](TEMPLATE.md) to replace the name and app identifier.

## Development environment

- Xcode 26.3 is the local baseline (`.xcode-version`), with iOS platform components installed. Running simulators also requires an iOS simulator runtime compatible with your Mac.
- Swift 6, with a minimum deployment target of iOS / iPadOS 17.
- XcodeGen 2.46.0, SwiftFormat 0.62.1, and SwiftLint 0.65.1 are pinned in `tools.lock.json`. Local development and CI use the same official release artifacts.

Install the development tools:

```sh
python3 scripts/tools.py install
bash scripts/doctor.sh
```

When `DEVELOPER_DIR` is unset, scripts prefer `/Applications/Xcode.app` and verify its version without changing the global developer tools selection. To use an installed newer Xcode, explicitly set `DEVELOPER_DIR` and `EXPECTED_XCODE_VERSION=27.2` for the same checks; the selected version must be validated in practice.

## Development and verification

`project.yml` is the source of truth for project configuration. The generated Xcode project is committed so it can be opened directly.

```sh
python3 scripts/tools.py run xcodegen generate
open SwiftSeed.xcodeproj
bash scripts/check.sh
bash scripts/verify-builds.sh
bash scripts/test-simulator.sh iphone
bash scripts/test-simulator.sh ipad
```

`check.sh` runs strict lint, positive and negative architecture checker fixtures, rendering boundary checks, and formatting checks. GitHub Actions runs static checks and compilation on PRs. UI tests run separately on a schedule or manually, without an immediate duplicate run after merging.

### PRs and CI

Submit all changes through a branch and PR, then squash merge after checks pass. Direct pushes, force pushes, and deletion of `main` are prohibited, with no administrator bypass list. Merging requires an up-to-date branch, resolved review discussions, and successful `Lint`, `Build`, `Security`, and `CI required` checks. The final check aggregates all jobs and rejects failures, cancellations, and unexpected skips.

The repository currently has one collaborator, so approval by another reviewer is not required: authors cannot approve their own PRs. Require at least one approval when an independent reviewer is available. Rules are defined in `.github/main-ruleset.json`; they must be applied through GitHub settings or the API. Editing the file alone does not change the live rules.

PRs run static and project consistency checks, compile the Debug app and UI tests, and build Release against the device SDK using both Xcode 26.3 and 27.2, without booting simulators. `Current SDK` is included in `CI required`, which requires static checks, security checks, and both compilation jobs to succeed. Failures, cancellations, or skips block merging. UI tests on both device types run in `Scheduled UI tests` and no longer gate every PR.

UI tests run against the latest main commit every 6 hours: 00:17, 06:17, 12:17, and 18:17 UTC, or 02:17, 08:17, 14:17, and 20:17 Beijing time. Scheduling away from the hour may reduce queuing, but GitHub schedules can be delayed and are not punctuality guarantees. Run them manually in Actions or with `gh workflow run ui-tests.yml --ref main`. Address failures and manually verify the relevant commit before release. The tradeoff is that UI regressions may only be detected after merging; under normal scheduling, detection starts within approximately 6 hours.

New PR commits cancel older checks. Scheduled and manual UI runs do not interrupt one another, and test results are retained for 7 days. Workflows have read-only repository permissions, and external actions are pinned to commits. Add new test targets to the shared scheme. UI test scripts reject zero tests and skipped tests. There are currently no business state tests; future core state-layer BDD belongs in the fast checks for every code PR.

Baseline CI checks use Xcode 26.3, matching local development. `Current SDK` and scheduled UI tests on both device types use pinned Xcode 27.2 on GitHub's `xcode-27` preview runner. Its availability risks are documented in the engineering review; failures are never automatically skipped. Tool versions come from the lock file. Scheduled UI jobs start the simulator after installing tools and overlap startup with `build-for-testing`. Once startup and compilation succeed, `test-without-building` uses those same build products. Logs report compilation, remaining startup wait, and test durations separately so optimization can be assessed with actual measurements. Test results are not cached, tests are not automatically retried, and device coverage is not reduced to improve speed.

There are currently two core UI BDD scenarios: app installed → open it → see the welcome message; largest accessibility text size and landscape orientation → open and scroll → read unclipped text and reach the description. The latter includes a system accessibility audit and covers an observed reading problem. Add future core business behavior at the lowest reliable test layer, following [AGENTS.md](AGENTS.md), without adding tests to meet a count.

#### Historical CI measurements (2026-11-11, when UI tests still gated PRs)

These durations run from workflow creation to completion of all jobs, including queuing. All runs used standard free runners and executed one welcome-screen BDD per device.

| Configuration | Full verification time | Run |
| --- | --- | --- |
| Before optimization, PR | 8 min 04 sec | [42935370368](https://github.com/acmerfight/swiftseed/actions/runs/42935370368) |
| Before optimization, duplicate post-merge run | 5 min 29 sec | [42936507808](https://github.com/acmerfight/swiftseed/actions/runs/42936507808) |
| After optimization, PR | 7 min 59 sec | [42941308463](https://github.com/acmerfight/swiftseed/actions/runs/42941308463) |

These samples do not establish a consistent speedup for full simulator verification. The optimization also pinned Xcode 26.3 to match local development. These measurements predate the separate scheduled UI workflow and do not represent current PR durations. That later split reduced PR waiting by changing test frequency while preserving the UI cases, assertions, and coverage of both device types that existed at the time.

### Static checks

- `.swiftlint.yml` retains default rules and adds checks for force unwraps, implicitly unwrapped optionals, unhandled throwing tasks, empty blocks, and more. All warnings are errors. Checks scan the whole repository, excluding build outputs, so new source and test directories are included automatically.
- SwiftFormat owns formatting; conflicting SwiftLint brace-position and trailing-comma rules are disabled. Run `python3 scripts/tools.py run swiftformat .` to fix formatting, then `bash scripts/check.sh`.
- Xcode builds run the same lint and rendering boundary checks. Swift compiler warnings also fail the build. Missing tools, version mismatches, or failed checks cause explicit errors; checks are not skipped and tools are not downloaded during a build.
- Do not hide violations behind a legacy baseline or whole-file disables. A justified exception must exempt only the necessary lines from a single rule, with an explanation alongside it. Rule changes require review. State necessity, business boundaries, and function purity still require human review; lint cannot replace design judgment.

The app composition target defaults to main-actor isolation. The rendering module keeps a nonisolated default so pure presentation values are not bound to the UI thread. Swift 6 strict checking and Approachable Concurrency are enabled together; asynchronous does not mean background execution.

The installer verifies SHA-256 hashes of official release artifacts and stores tools in the ignored `.build/tools/` directory. To upgrade, update `tools.lock.json`, reinstall, and verify checks and builds.

### Security checks

The required `Security` check runs in parallel on Linux for every PR and is included in the final aggregate gate. Gitleaks scans the full Git history for secrets with redacted output. zizmor audits workflow permissions, injection, and supply-chain risks, failing on findings. Dependency Review blocks newly introduced dependencies with known vulnerabilities of low severity or higher; findings are not merely advisory.

The repository requires full SHA pins for actions, defaults to read-only permissions, and prevents workflows from approving PRs. GitHub Secret Scanning and Push Protection remain enabled. Dependabot opens weekly Actions update PRs; vulnerability alerts and security updates remain enabled. Update PRs pass the same merge gates. Enabling the repository's auto-merge feature does not automatically merge all future PRs; it must be explicitly enabled for each PR.

There are currently no third-party business dependencies. Dependency checks mainly cover manifests and actions recognized by GitHub. Manually downloaded tools use pinned versions and SHA-256 verification, with upgrades requiring review. These checks do not replace application security review. Changes to security tool versions or hashes must also go through a PR.

Start a simulator:

```sh
bash scripts/run-simulator.sh iphone
bash scripts/run-simulator.sh ipad
```

The script generates the project, builds it, creates or reuses the corresponding simulator, and installs and launches the app.

## Code boundaries

All coding and review follow [AGENTS.md](AGENTS.md).

- `SwiftSeed/SwiftSeedApp.swift`: the app composition entry point, supplying presentation inputs.
- `SwiftSeed/Rendering/`: a separate rendering module containing only views and immutable presentation data. The app depends on this module; the module does not depend on the app implementation.
- `HomeViewState` is a read-only presentation value, not a business state container or persistence model. There are currently no interactions that require a business state layer.
- `scripts/architecture/`: syntax-tree boundary checks using SwiftParser / SwiftSyntax bundled with the selected Xcode. Missing parsers fail the check rather than skipping it.

The checker covers rendering-module imports, state property wrappers, mutable stored properties, reference state declarations, and common side-effect entry points. Comments and ordinary strings are not treated as code. It does not prove arbitrary functions pure or determine whether state is necessary. New business features still require review of state ownership and interface contracts, plus constraints and tests for actual business rules.

## Verification scope

The local development baseline is Xcode 26.3. The project has passed architecture rule fixtures, build rejection of violating code, formatting checks, and simulator compilation. Installation, launch, and visual checks have been completed on iPhone 16 and iPad A16 simulators. Physical-device signing and installation have not been verified, and there are currently no business features to validate.

To run on a physical device, select your own signing team in Xcode and confirm that the device is compatible with the selected Xcode. Do not commit personal signing configuration, build outputs, or local credentials.
