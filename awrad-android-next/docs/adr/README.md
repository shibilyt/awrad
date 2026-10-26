# Architecture decision records

Android-only decisions for `awrad-android-next`. Cross-project decisions live in the root [`DECISIONS.md`](../../../DECISIONS.md).

Status values follow the root vocabulary: Proposed, Accepted, Superseded, Rejected.
Accepted ADRs are not re-argued in reviews. Change one by adding a new ADR that supersedes it.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-one-module-per-feature.md) | One Gradle module per feature | Accepted |
| [0002](0002-no-kotlin-multiplatform.md) | Plain Kotlin/JVM domain, no Kotlin Multiplatform | Accepted |
| [0003](0003-replace-awrad-android.md) | awrad-android-next replaces awrad-android | Accepted |
| [0004](0004-conventions-enforced-by-the-build.md) | Conventions are enforced by the build, not by memory | Accepted |
| [0005](0005-network-module-and-okhttp.md) | A `:core:network` module on OkHttp, without Retrofit | Accepted |
| [0006](0006-account-credential-storage.md) | Account credentials in Keystore-encrypted files | Accepted |
