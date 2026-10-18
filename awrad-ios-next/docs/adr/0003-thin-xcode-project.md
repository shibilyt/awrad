# 0003: A committed, thin Xcode project; warnings as errors enforced outside the package manifest

Status: Accepted (2026-10-17)

## Context

Project generators (Tuist, XcodeGen) avoid conflicts in the project file, but add a tool every developer and CI must install. With all code in `AwradKit`, the project file barely changes. Separately, Xcode compiles a local package as a dependency with `-suppress-warnings`, which conflicts with the package-level `.treatAllWarnings(as: .error)`.

## Decision

- Commit `AwradNext.xcodeproj`, using Xcode 16+ synchronized folders, with a shared `AwradNext` scheme. The app target holds only the composition root, root routing and app strings.
- Treat warnings as errors in two places:
  - the package, through `swift build -Xswiftc -warnings-as-errors` and `swift test` in `scripts/validate`;
  - the app target, through `SWIFT_TREAT_WARNINGS_AS_ERRORS`.

## Consequences

- No generator to install, and the project file rarely changes.
- A package warning doesn't fail an Xcode build of the app, but it does fail `scripts/validate` and CI. Run the script before pushing.
