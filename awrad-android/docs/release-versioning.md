# Release Versioning

Release builds must provide an explicit app version.

Use a `versionCode` that is higher than the previous Play Store release and a user-visible `versionName`:

```bash
AWRAD_RELEASE_API_BASE_URL=https://api.example.com \
./gradlew assembleRelease \
  -PAWRAD_VERSION_CODE=2 \
  -PAWRAD_VERSION_NAME=1.1.0
```

Debug builds use local defaults, but any Gradle task containing `Release` fails unless `AWRAD_VERSION_CODE` and `AWRAD_VERSION_NAME` are set as Gradle properties or environment variables.
