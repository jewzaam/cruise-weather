# Database Migrations

> Standards for Room database schema changes and data migration. Applies to all
> Android projects using Room persistence.

## Principles

1. **User data is sacred.** Never destroy it. Every schema change must preserve existing data.
2. **Lazy over eager.** Fetch or recompute data on demand, not in bulk during migration.
3. **Automated enforcement.** Migration coverage must be verified by tests that fail when a
   version step is missing.

## Rules

### Never use destructive migration

`fallbackToDestructiveMigration()` is **prohibited** in all build variants. It silently
deletes all user data when a schema version mismatch is detected.

### Every version bump requires a Migration

For each increment of `@Database(version = N)`, there must be a corresponding
`Migration(N-1, N)` object with explicit `ALTER TABLE` statements.

```kotlin
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE ports_of_call ADD COLUMN timezone TEXT NOT NULL DEFAULT ''")
    }
}
```

### Add columns — never drop or recreate tables

SQLite supports `ALTER TABLE ... ADD COLUMN`. Use it. If a column type or constraint
needs to change, create a new column and backfill from the old one.

### New columns must have sensible defaults

`ALTER TABLE` requires a `DEFAULT` clause. Choose a default that is:
- Correct for new rows going forward.
- Detectable as "stale" for existing rows (so the app knows to refresh).

### Register all migrations in one place

Maintain a single `ALL_MIGRATIONS` array. The database builder references only this array.
This makes it impossible to define a migration and forget to register it.

### Never delete cached data in a migration

If a schema change adds new fields to a cache table (e.g., weather data), do **not**
`DELETE FROM` the table in the migration. Instead, make the staleness-detection logic
aware of the new fields.

## Staleness detection pattern

When new fields are added to a cache table, the "is fetch needed" check should detect
rows that predate the schema change:

```kotlin
suspend fun isFetchNeeded(portId: Long): Boolean {
    val summary = dao.getSummaryOnce(portId) ?: return true
    // Stale if missing fields added in schema v3
    return summary.newField == 0.0
}
```

This ensures:
- Existing cached data is still displayed (with missing fields showing defaults).
- Re-fetch happens **lazily** — only when the user views the data.
- No bulk re-fetch on app startup regardless of dataset size.

## Data refresh strategy

- Cache data is refreshed **on demand**: when a user opens a detail screen or triggers
  a comparison.
- Never bulk-refresh all records at migration time or app startup.
- Loading indicators must be shown during any data fetch operation.

## Test requirements

### Migration coverage test

A JVM unit test must verify that:

1. Every version from 1 to `currentVersion` has a migration with no gaps.
2. No migration skips versions (each is exactly `N → N+1`).
3. `ALL_MIGRATIONS` starts at version 1 and ends at the current database version.

This test must reference `currentVersion` as a constant that is updated alongside
`@Database(version = ...)`. If they diverge, the test fails.

### Instrumented migration tests

For non-trivial migrations (data backfill, column renames, constraint changes), add
an instrumented test using `MigrationTestHelper` that:

1. Creates a database at version N-1 with sample data.
2. Runs the migration.
3. Verifies the schema is correct and data is preserved.

## Checklist for schema changes

- [ ] Add `ALTER TABLE` migration in `Migrations.kt`
- [ ] Register in `ALL_MIGRATIONS`
- [ ] Bump `@Database(version = N)`
- [ ] Update `MigrationCoverageTest.currentVersion`
- [ ] Update `isFetchNeeded()` if new fields are added to cache tables
- [ ] Run `make test` — migration coverage test must pass
- [ ] Verify on emulator with existing data — no data loss, stale data refreshes lazily
