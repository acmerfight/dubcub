# Using the template

SwiftSeed is a native iPhone / iPad project template with a static welcome screen that can be removed. Strict separation of state and rendering is this template's design choice, not a requirement for every iOS project.

## Create a project

1. Choose **Use this template → Create a new repository** on GitHub, copy only the default branch, and clone your new repository. GitHub copies files; do not assume branch protections, security settings, or historical CI results are inherited.
2. Install full Xcode 26.3 (the current local baseline), the iOS SDK, and a compatible simulator runtime to satisfy the development environment checks. Run `python3 scripts/tools.py install` to install pinned development tools with SHA-256 verification.
3. From a clean working tree, run `python3 scripts/initialize-template.py --name MyApp --bundle-id com.example.myapp`. It updates the project name, source paths, scripts, UI tests, and Bundle ID, then regenerates the project. It does not change Git remotes, commit history, or signing teams. Review the diff and update the README repository links, product description, and sample copy.
4. Run `bash scripts/doctor.sh`, `bash scripts/check.sh`, and `bash scripts/verify-builds.sh`. The last command compiles the Debug app and UI tests and builds Release against the device SDK without booting a simulator or signing.
5. Submit the initialized project to the new repository through a branch and PR, then run `python3 scripts/configure-repository.py OWNER/REPO` to apply protections. This repeatable command requires an authenticated `gh` session and administrator access to the target repository. It enables PR gates, squash merging, auto-merge capability, vulnerability alerts, secret push protection, action SHA pinning, and read-only workflow defaults. Auto-merge still requires explicit activation for each PR.
6. Confirm that Actions is enabled, all required checks succeed on the first run, and the scheduled UI workflow is active. Public repositories can use standard free runners; private repository features and quotas depend on the plan. The script explicitly reports unsupported settings instead of silently skipping protections.

`tools.lock.json` is the single source of truth for development tool versions and artifact hashes. CI and local development invoke the same tools through `scripts/tools.py`, without relying on the latest Homebrew versions. Review release sources, versions, and hashes together when upgrading, then verify that generated project files and formatting have not changed unexpectedly.

After initialization, run `rg 'acmerfight|SwiftSeed|swiftseed'` to inspect remaining sample text and source links, deciding individually what to retain or replace. Do not indiscriminately delete historical references or treat the template's verification results as evidence that the new project has been verified. Choose an appropriate license before distributing your project; a public repository or template flag does not grant a license.

## Add the first business slice

Define a user entry point and observable outcome, then add core BDD. Prefer Swift Testing for new business unit and integration tests, and XCTest for UI automation. Keep pure business rules and state transitions in modules independent of UI and device APIs, verify them quickly on the Mac, and include them in every PR. Add only necessary integration checks for real storage and device capabilities. Do not prebuild empty stores, service containers, persistence models, or always-passing placeholder tests.

There are currently only two core UI scenarios: opening the welcome screen and reading it in landscape at the largest text size. They run every 6 hours and support manual execution. They do not prove business correctness or replace release-candidate acceptance. Scheduled UI tests use Xcode 27.2; PRs compile with both the local baseline and the newer SDK. See the [engineering review](ENGINEERING.md) for the newer runner's preview status and local hardware limitations. Explicitly add new test targets to the shared scheme and new fast tests to the CI aggregate gate.

## Work required before release

- Verify signing, installation, Release execution, and relevant core paths such as audio, denied permissions, and interruption recovery on physical devices.
- Verify iPad split view and resizable windows, portrait and landscape, maximum Dynamic Type, VoiceOver, and light and dark appearances. Add only the verification needed for real issues; large snapshot suites do not replace experience checks.
- Complete privacy manifests, purpose strings, and App Store privacy information based on the data actually collected, APIs used, and third-party SDKs included. Do not invent data uses or request unused permissions.
- Configure product icons, versions, signing teams, and distribution. Keep signing credentials in controlled environments. The current unsigned Release CI build does not verify archiving, distribution, or App Store submission.

Complete these tasks as the product develops. Empty files and inaccurate declarations do not make the template production-ready.
