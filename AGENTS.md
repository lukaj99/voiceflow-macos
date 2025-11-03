# Repository Guidelines

## Project Structure & Module Organization
VoiceFlow is a Swift 6 macOS app. Core executable sources live in `VoiceFlow/` with `App` bootstrapping, `Core` handling shared state, `Features/*` providing modular flows, `Services` managing integrations (Deepgram, Keychain, audio), `Shared` utilities, `Resources` assets/entitlements, and SwiftUI layers in `ViewModels` plus `Views`. Vendored dependencies sit under `ThirdParty/`, and reusable tooling scripts reside in `Scripts/`. Automated tests live in `VoiceFlowTests` with `Unit`, `Integration`, `Performance`, `Security`, and `LLM` suites plus mocks; UI harnesses go in `VoiceFlowUITests`.

## Build, Test, and Development Commands
Use `swift build` for incremental debug builds and `swift build --configuration release` before performance or App Store checks. `swift run VoiceFlow` launches the executable locally; add `--enable-testing` when running from CI to expose diagnostics. `swift test` executes XCTest targets, while `swift test --filter VoiceFlowTests.Unit` narrows scope. Format and lint before pushing: `swiftformat VoiceFlow VoiceFlowTests` and `swiftlint --strict`. Regenerate dependencies with `swift package resolve` after touching `Package.swift`.

## Coding Style & Naming Conventions
Follow the repo’s `.swiftformat` profile: 4-space indentation, 120-character lines, argument wrapping on the first line, and no trailing semicolons. Keep types and protocols UpperCamelCase, members lowerCamelCase, and honor acronym casing from the config (`URL`, `API`, `LLM`). Prefer `@MainActor` annotations for UI-bound APIs, inject dependencies via initializers, and organize files with `// MARK:` blocks that mirror module boundaries. Run SwiftLint locally; warnings are treated as failures in CI.

## Testing Guidelines
New code requires unit coverage in the matching folder (e.g., `VoiceFlowTests/Unit/FeatureNameTests.swift`). Integration flows belong in `Integration`, with mocked network traffic under `Mocks`. Performance and concurrency scenarios should extend `PerformanceSystemTest.swift`, gated behind `#if PERFORMANCE`. Maintain ≥90% coverage; run `swift test --enable-code-coverage` before reviews and attach HTML reports for regressions. UI-level smoke tests belong in `VoiceFlowUITests` using the supplied fixtures.

## Commit & Pull Request Guidelines
Commit messages follow `<type>: <imperative summary>` with optional emoji (see `git log`). Group related changes, keep bodies bulleted, and squash fixups before opening a PR. PRs must include a concise summary, linked issues, screenshots for UI-affecting work, and test command outputs. Highlight security-sensitive updates (Keychain, entitlements) and call out manual steps reviewers must perform.

## Security & Configuration Tips
Never hard-code API secrets; rely on `SecureCredentialService` and macOS Keychain. When modifying entitlements or bundle identifiers, update `Resources/Entitlements/VoiceFlow.entitlements` and note the change in the PR. External WebSocket tweaks should stay isolated to `ThirdParty/Starscream` to simplify audits.
