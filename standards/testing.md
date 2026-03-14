# Testing Standards

Android testing conventions for `org.jewzaam.cruiseweather`.

## Testing Philosophy

Tests exist to prevent regressions and validate functionality. A test that cannot catch a real bug
provides false confidence and wastes maintenance effort.

**Guiding principles:**

1. **Tests must have teeth** — Every test should be capable of failing when the code it tests is broken
2. **TDD for bug fixes** — Write a failing test before fixing a bug to prove the test catches the defect
3. **Functionality over coverage** — 80% meaningful coverage beats 100% superficial coverage
4. **Document the "why"** — Each project maintains a `TEST_PLAN.md` explaining testing rationale

## Test Types

### Unit Tests (JVM, no Android framework)

Test a single function or class in isolation. Run with `./gradlew test`. Fast.

| Characteristic | Requirement |
|---|---|
| Scope | Single class/function |
| Dependencies | All mocked (MockK) |
| Android framework | Not required |
| Location | `src/test/` |

Target: repository layer, use cases, aggregation/computation logic, data mappers.

```kotlin
@Test
fun `computeRainProbability returns correct percentage from yearly data`() {
    val years = listOf(
        PortWeatherYear(precipMm = 2.0, ...),  // rainy
        PortWeatherYear(precipMm = 0.0, ...),  // dry
        PortWeatherYear(precipMm = 1.5, ...),  // rainy
        PortWeatherYear(precipMm = 0.0, ...),  // dry
        PortWeatherYear(precipMm = 3.0, ...),  // rainy
    )
    val result = computeWeatherSummary(years)
    assertThat(result.rainyYearCount).isEqualTo(3)
    assertThat(result.totalYearCount).isEqualTo(5)
}
```

### Integration Tests (Android instrumented)

Test multiple components together with real dependencies. Run with `./gradlew connectedAndroidTest`.
Slower — require device or emulator.

| Characteristic | Requirement |
|---|---|
| Scope | Multiple classes cooperating |
| Dependencies | Real Room DB (in-memory), real repositories |
| Android framework | Required |
| Location | `src/androidTest/` |

Target: Room DAOs with in-memory database, repository with real DAO.

```kotlin
@Test
fun insertAndRetrieveCruise() = runTest {
    val cruise = Cruise(name = "Test", sailDate = LocalDate.now(), ...)
    val id = cruiseDao.insert(cruise)
    val retrieved = cruiseDao.getCruiseById(id).first()
    assertThat(retrieved?.name).isEqualTo("Test")
}
```

### UI Tests (Compose)

Test screens in isolation. Run with `./gradlew connectedAndroidTest`. Slowest.

Target: key user flows — create cruise, fetch weather, view calendar, comparison selection.

```kotlin
@Test
fun cruiseListShowsAddButton() {
    composeTestRule.setContent { CruiseListScreen(...) }
    composeTestRule.onNodeWithContentDescription("Add cruise").assertIsDisplayed()
}
```

## Test-Driven Development (TDD)

TDD is **required** for bug fixes. New features follow standard test-after development.

```
1. Reproduce    — Confirm the bug exists
2. Write test   — Create a test that exposes the bug
3. Verify red   — Run test, confirm it FAILS
4. Implement    — Write the minimal fix
5. Verify green — Run test, confirm it PASSES
6. Commit       — Commit test and fix together
```

Link regression tests to the bug they validate:

```kotlin
/**
 * Regression test for https://github.com/jewzaam/cruise-weather/issues/42
 *
 * Bug: Weather aggregation included years with null UV data, producing wrong averages.
 * Fix: Null UV values are excluded from the average calculation.
 */
@Test
fun `aggregation excludes null uv values from average`() { ... }
```

## Naming

| Item | Pattern | Example |
|---|---|---|
| Test files | `<Subject>Test.kt` | `WeatherRepositoryTest.kt` |
| Unit test functions | `` `does thing when condition` `` | `` `returns empty list when no ports exist` `` |
| Integration test classes | `<Subject>IntegrationTest.kt` | `CruiseDaoIntegrationTest.kt` |
| Bug regression tests | includes issue reference | `` `averages exclude nulls issue_42` `` |

## Test Location

```
src/
├── test/                         # JVM unit tests
│   └── java/org/jewzaam/cruiseweather/
│       ├── data/
│       ├── domain/
│       └── ui/
└── androidTest/                  # Instrumented tests
    └── java/org/jewzaam/cruiseweather/
        ├── data/local/           # DAO integration tests
        └── ui/                   # Compose UI tests
```

## Test Isolation

- No persistent state between tests
- Use `@Before` / `@After` for setup/teardown
- Room: use `Room.inMemoryDatabaseBuilder()` in tests
- Network: mock with MockK or use fake repository implementations
- Never call real network APIs from tests

## Coverage

Target: **80%+ line coverage** of business logic (repositories, use cases, aggregation).

UI and DI wiring are exempt from the 80% target but key flows must have UI tests.

## What to Test

- Repository logic (CRUD, cache invalidation)
- Aggregation/computation (weather averages, rain probability)
- Use cases
- Edge cases: empty port list, single-year data, all-null fields
- Error paths: network failure, DB error

## What Not to Test

- Third-party library behavior (Room, Ktor internals)
- Hilt wiring
- Data class equality (Kotlin guarantees it)
- Logging calls

## Common Anti-Patterns

```kotlin
// BAD — only tests that no exception is raised
@Test
fun fetchWeather() {
    repository.fetchWeather(portId = 1)
    // No assertions!
}

// GOOD — verifies expected outcome
@Test
fun `fetchWeather stores summary in database`() = runTest {
    repository.fetchWeather(portId = 1L)
    val summary = weatherDao.getSummaryForPort(1L).first()
    assertThat(summary).isNotNull()
    assertThat(summary!!.avgTempHighF).isGreaterThan(0.0)
}
```

## Required Dependencies

```toml
# Test
junit = { group = "junit", name = "junit", version = "4.13.2" }
mockk = { group = "io.mockk", name = "mockk", version = "1.13.x" }
coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }
turbine = { group = "app.cash.turbine", name = "turbine", version = "1.x" }
truth = { group = "com.google.truth", name = "truth", version = "1.4.x" }

# Android test
compose-test-junit4 = { group = "androidx.compose.ui", name = "ui-test-junit4" }
room-testing = { group = "androidx.room", name = "room-testing", version.ref = "room" }
```
