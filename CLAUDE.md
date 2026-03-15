# Project Instructions

## Build System

- **Use `make` targets**, not `./gradlew` directly. The Makefile wraps Gradle and is the project's CLI interface.
- Available targets: `build`, `test`, `lint`, `check`, `clean`, `itest`, `setup-check`
- If a make target doesn't exist for what you need, add one to the Makefile rather than running Gradle directly.

## Working with the User

- **Do not search the filesystem speculatively.** Use `ls`, `find`, or glob only when you already know what you're looking for or the user has told you where to look.
- **Do not run commands that will trigger approval prompts** when you can avoid it. If a dedicated tool (Read, Glob, Grep, Edit) can do the job, use it instead of Bash.
- **Verify your own output.** If you write documentation, re-read it and check that every statement is accurate before presenting it. Getting it wrong the first time and iterating through corrections wastes time.
- **Do not assume paths, versions, or tool names.** Check first, then act. If you don't know, ask — don't guess.

## Android Development

- SDK configuration lives in `local.properties` (git-ignored).
- `make setup-check` validates the development environment.
- Instrumented tests (`make itest`) require a connected device or emulator.
- JVM unit tests (`make test`) run without a device.

## Database & Migrations

### Rules

- **Never use `fallbackToDestructiveMigration`.** User data must be preserved across schema changes.
- **Never wipe the emulator/device database** (`adb shell pm clear`) unless the user explicitly requests it.
- **Every schema change requires a `Migration` object** in `data/local/Migrations.kt` with `ALTER TABLE` statements.
- **Always ask the user** before making a schema change: "This requires a DB migration. Proceed?"
- **Bump `@Database(version = N)`** and add a corresponding `MIGRATION_(N-1)_N` to `ALL_MIGRATIONS`.

### Migration checklist

1. Add new columns with `ALTER TABLE ... ADD COLUMN ... DEFAULT <value>` — never drop/recreate tables.
2. If new columns replace data that was previously unfetchable, use `isFetchNeeded()` to detect stale rows (e.g., check if a new field is still at its default value). Do **not** delete cached data in the migration.
3. Register the migration in `ALL_MIGRATIONS` in `Migrations.kt`.
4. Update `MigrationCoverageTest.currentVersion` to match the new version.
5. Run `make test` — the migration coverage test will fail if any version step is missing.

### Data refresh strategy

- Weather data is a **cache of historical averages** — safe to re-fetch but never silently deleted.
- `isFetchNeeded()` returns true when data is missing **or stale** (e.g., missing fields added in a newer schema).
- Fetching is **lazy** — only when a user opens a cruise detail or triggers a comparison. Never bulk-fetch on app startup.
- The comparison screen fetches any missing/stale weather before computing results, with a loading overlay.
