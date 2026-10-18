# awrad-ios-next

The Awrad iOS app (SwiftUI, SwiftData, Observation, iOS 18), rebuilt to replace `awrad-ios/`. Start with [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENTS.md`](AGENTS.md).

```bash
open AwradNext.xcodeproj     # Xcode 26.2 (.xcode-version)
scripts/validate             # the validation command CI runs
(cd AwradKit && swift test)  # domain/data/model tests on macOS, no simulator
```
