# awrad-ios-next

The Awrad iOS app (SwiftUI, SwiftData, Observation, iOS 18), rebuilt to replace `awrad-ios/`. Start with [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENTS.md`](AGENTS.md).

```bash
open AwradNext.xcodeproj     # Xcode 26.2 (.xcode-version)
scripts/validate             # the validation command CI runs
(cd AwradKit && swift test)  # domain/data/model tests on macOS, no simulator
```

## Accounts against a local server

Debug builds call `http://localhost:4000` (`APIEnvironment` in `AwradNext/AppComposition.swift`), and `Config/Debug-Info.plist` allows plain HTTP to `localhost` in Debug only.

1. Start `awrad-server-next` on port 4000 (see its README). Nothing else may be listening on 4000.
2. Run the `AwradNext` scheme on a simulator, which shares the Mac's `localhost`, and tap **Account** on the home screen.
3. Read the emailed codes in the server's dev mailbox (Swoosh).

A physical device can't reach the Mac's `localhost`; that needs a LAN URL and its own ATS exception.
