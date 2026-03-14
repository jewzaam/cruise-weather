# GitHub Workflows Standards

## Required Workflows

| Workflow | File | Trigger | Command |
|---|---|---|---|
| Build | `.github/workflows/build.yml` | push, PR to main | `./gradlew build` |
| Test | `.github/workflows/test.yml` | push, PR to main | `./gradlew test` |
| Lint | `.github/workflows/lint.yml` | push, PR to main | `./gradlew lint` |

## Build Workflow Template

```yaml
name: Build
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v3
      - run: ./gradlew build
```

## Android Emulator for Instrumented Tests

Instrumented tests require an emulator. Use `reactivecircus/android-emulator-runner`:

```yaml
- uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: 33
    script: ./gradlew connectedAndroidTest
```

Run instrumented tests in CI only on main branch (slow, expensive).

## Notes

- Use Java 21 (matches current Android Gradle Plugin requirements)
- Cache Gradle wrapper and caches with `gradle/actions/setup-gradle`
- Never store secrets in workflow files; use GitHub repository secrets
