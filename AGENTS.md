# Coding and delivery requirements

These requirements are mandatory for coding, refactoring, and review. Do not relax them for demos, convenience, or deadlines. See [README.md](README.md) for the environment, layout, and commands; `project.yml` is the source of truth for project configuration.

## Repository language

Use English for documentation, code comments, test scenarios, development tool output, and sample UI text. Keep a single English README. Add product localization only when explicitly required by the product; do not introduce translated documentation or mixed-language developer messages by default.

## Current stage

The project is unreleased and maintains only the latest design. Do not add compatibility layers, legacy format readers, data migrations, or compatibility tests. Save failures, data corruption, and interruption recovery in the current format remain correctness concerns and must be verified against core user promises.

## Delivery: vertical slices, BDD first

1. Identify the user entry point and state: "After this change, what can the user do, and what result can they observe?" Deliver a usable minimum end-to-end slice. Reduce feature scope if necessary; do not split by technical layer into unusable partial deliveries.
2. Before adding a feature or fixing behavior, write core BDD: Given describes the user context, When the user action, and Then the observable result, verified by assertions. Confirm that the test fails for the expected reason before implementing the change.
3. Make the smallest change to the existing usable flow that satisfies the current slice. Abstractions must serve real requirements, duplication, or boundaries; do not prebuild frameworks for hypothetical needs.
4. Acceptance must cover the promised usage path. Passing lower-level tests alone does not prove a user feature works. Report the user outcome, verification evidence, and unverified areas at delivery.

## Testing: core behavior, minimum necessary layers

- Add only core, user-perceptible BDD. Cover failures only when they threaten a core promise. Do not add tests for imperceptible internals or pursue test counts or coverage targets.
- Test at the lowest layer that reliably proves the promise: primarily the state layer for core behavior, necessary integration checks for real side effects such as persistence, and very few UI tests to prove key user paths connect. Move up a layer only for critical risks the lower layer cannot prove; do not exhaustively duplicate coverage across layers.
- Assert public outcomes and state, not private functions, internal call order, or implementation shape. Successful persistence requires verification of actual writes and reads. Device-dependent behavior and its actual effects require physical-device verification; simulated success is insufficient.
- Documentation-only changes and behavior-preserving mechanical refactors need no new tests. Run relevant checks during development and complete the necessary verification before delivery. Do not rerun valid checks without new changes or risks.

## Design constraints

### Minimum necessary state

Every stored value adds synchronization and maintenance responsibility. Do not store values derivable from existing data or add synchronization logic to maintain duplicate facts. Preserve historical facts rather than recomputing them from current data.

Caches and redundant data require an explicit source of truth, update owner, and invalidation rules. Removing an optimization must preserve correctness.

### Independent state and explicit ownership

Separate state by business responsibility and lifecycle; when uncertain, split first. Appearing on the same screen is not a reason to merge state. Each kind of state has an explicit owner and write entry point. Modules collaborate through business operations. Each business rule has one authoritative implementation.

Data structures must follow strict normalization by default. Discuss denormalization only with performance evidence from real workloads showing an actual impact on user experience.

### Data boundaries and type constraints

Parse and validate external data at entry points, then convert it into explicit internal types. Invalid data must fail explicitly; do not hide errors behind defaults or duplicate the same validation rules throughout the business layer.

Keep required data required. Allow absence only when it has business meaning. Model mutually exclusive states together with their required data to prevent contradictory combinations. Do not add redundant defenses or tests for cases already excluded by types.

### Strict separation of state and rendering

Independent state layers own business and interaction state. Rendering receives only read-only presentation data and emits user events. It must not own or mutate state, access storage, or perform business side effects.

Framework adapters only connect layers. They must not contain business rules or maintain a second copy of business state. Business outcomes must not depend on view lifecycle or refresh order.

### Pure functions and external side effects

Calculations and business rules explicitly receive the data they need and return results without implicitly reading or writing external state. Outer layers read state, request resources, and persist results. Moving a function out of a view while it still freely accesses the whole state container is not decoupling.

### Dedicated, small, explicit interfaces

Interfaces express business operations rather than exposing generic field or status mutation. "Small" means callers need to know little; the same operation should be reusable.

An operation must enforce its own consistency requirements internally. Define and implement preconditions, success outcomes, write effects after failure, and retry, cancellation, and concurrency behavior.

### Platform and concurrency boundaries

Lay out UI according to available window space and the user's text size, not device models, orientation assumptions, or fixed screen dimensions. Core content must remain readable and reachable in narrow windows, landscape, and accessibility text sizes. Do not duplicate system scrolling or layout behavior as managed state.

Each window's state layer owns its navigation, selection, and editing session. Share only genuinely shared data across windows. Closing, switching, or resizing a window must not implicitly lose data promised to be saved.

Concurrent tasks need explicit owners, cancellation timing, and result acceptance conditions. Stale requests must not overwrite newer actions, and cancellation must not masquerade as success. Expensive work must not block the UI; asynchronous does not mean background execution. Do not hide ownership problems by disabling concurrency checks or using unsafe declarations.

## Review and completion criteria

- PRs must pass security checks. Keep secrets out of code and logs, and redact scan output. Pin third-party tool versions and verify their provenance. Use least-privilege workflows. Fix security failures or provide reviewed evidence of a specific false positive; do not merge by disabling checks wholesale, lowering thresholds, or bypassing protections.
- Merge all changes through branches and PRs. Never push directly to the main branch or bypass protections. Before squash merging, the latest commit must pass lint, architecture, project consistency, compilation, and aggregate checks, and review discussions must be resolved. UI tests on both device types run on main every 6 hours and can be triggered manually; they do not gate every PR. Address failures and verify the relevant version before release. Add future core state-layer BDD to the fast checks for every code PR.
- Prioritize whether state is necessary, business concerns are improperly coupled, who may modify data, who enforces rules, and who will be affected by future changes. Passing tests cannot replace these judgments.
- Use module boundaries and access control to constrain dependencies and writes, types to express valid states, and static checks to enforce stable rules. Leave formatting to tools. Keep tests within the scope of core user BDD.
- For automated gates, verify that the intended invalid input is rejected. A configuration file or a green run alone does not prove the gate enforces its promise.
- Review the final diff, keep changes focused, and update affected documentation. Verification results must correspond to the delivered version. Never report unexecuted or failed verification as passing.
