# Versioning Standards

## Semantic Versioning

Use `MAJOR.MINOR.PATCH` as defined at https://semver.org.

The **public API** for this project is the **user-facing UI/UX**:
- Screen layouts and navigation
- Data the user enters and can expect to retrieve
- Behavior the user can observe

## Version Increment Rules

| Change | Increment | Example |
|---|---|---|
| Removes or renames a screen | MAJOR | Removing the comparison screen |
| Breaks backward compat with stored data (destructive migration) | MAJOR | Dropping a Room table |
| New feature visible to users | MINOR | Adding a new weather metric |
| Bug fix, performance, refactor (no behavior change) | PATCH | Fixing an off-by-one in averages |

## Android Version Fields

Set in `app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        versionCode = 1          // Monotonically increasing integer for Play Store
        versionName = "1.0.0"    // Semantic version shown to users
    }
}
```

`versionCode` increments on every release regardless of semantic version bump.

## Room Schema Migrations

A schema migration is required whenever Room entities change after any public release.
During pre-release development, `fallbackToDestructiveMigration()` is acceptable.

Before any production release: switch to explicit `Migration` objects.
