# Architecture decision records

iOS-only decisions for `awrad-ios-next`. Cross-project decisions live in the root [`DECISIONS.md`](../../../DECISIONS.md). Accepted ADRs aren't re-argued: supersede them with a new one.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-local-package-modules.md) | Modules are targets of one local Swift package | Accepted |
| [0002](0002-swiftdata-pre-release-policy.md) | SwiftData: one schema, recreated on incompatibility, until the first release | Accepted |
| [0003](0003-thin-xcode-project.md) | A committed, thin Xcode project; warnings as errors enforced outside the package manifest | Accepted |
| [0004](0004-network-and-account-session-in-awraddata.md) | The API client and the account session live in AwradData | Accepted |
| [0005](0005-device-credentials.md) | Device credentials: Keychain refresh token, in-memory access token, and a new installation on reinstall | Accepted |
