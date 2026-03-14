# Code Review: cruise-weather

## TL;DR

Solid Phase 1 Android app with clean architecture, consistent naming, and good Kotlin idioms. The codebase follows MVVM/Repository with Hilt DI, Room persistence, and Ktor networking. However, there are race conditions in `CruiseDetailViewModel` and `CruiseEditViewModel` that can cause stale data or wrong-port edits, port sync operations outside transactions risk data corruption on crash, and domain models directly reference Room entities (breaking clean architecture). Tests are well-structured where they exist, but `CruiseListViewModel` is untested, Turbine is declared but unused, and `relaxed = true` on mocks weakens test sensitivity. Build targets (`make lint`, `make test`) fail on this Windows environment.

## Build & Check Results

| Target | Status | Notes |
|--------|--------|-------|
| format | N/A | No target defined |
| lint | :x: | `./gradlew` shell script not executable on Windows/MINGW — `'.' is not recognized` |
| test | :x: | Same root cause |
| check | :x: | Meta-target (`lint` + `test`), same root cause |
| coverage | N/A | No target defined |

**Root cause:** The Makefile invokes `./gradlew` (Unix shell script), which cannot execute in this Windows/MINGW environment. Fix: add `SHELL := bash` to the Makefile, use platform detection, or ensure the environment runs Make through a POSIX shell.

## Findings

### :red_circle: Critical

1. **CruiseDetailViewModel.kt:76-99 — Race condition: cancelling `collectJob` during weather fetch breaks database observation.**
   `fetchWeather()` cancels `collectJob` (line 79) to "prevent it from overwriting fresh data," then restarts observation via `loadCruise()` after the fetch completes (line 98). While `collectJob` is cancelled (the entire duration of the weather fetch), any database changes from other sources are silently dropped. If the ViewModel is cleared between cancel and restart, the new `loadCruise()` creates an orphaned coroutine.
   **Fix:** Do not cancel `collectJob`. Use a separate `MutableStateFlow` for weather state, or `combine()` to merge the cruise data Flow with a weather-refresh trigger.

2. **CruiseEditViewModel.kt:316-317 — Flawed identity comparison for unsaved ports in `updatePortOfCall`.**
   `it.id == port.id && it.date == port.date || it === port` — due to `&&` binding tighter than `||`, this evaluates as `(id match AND date match) OR identity match`. For unsaved ports (all have id=0), two ports on the same date would both match. The `===` fallback breaks with `.copy()`. Same problem in `deletePortOfCall` (line 322-324).
   **Fix:** Assign temporary client-side IDs (e.g., negative longs) to unsaved ports, or use list indices.

3. **CruiseEditViewModel.kt:242-254 — Port sync not wrapped in a transaction.**
   `saveCruise()` calls `cruiseRepository.saveCruise()` (transactional) but then performs port deletions, inserts, and updates in a loop outside any transaction. A crash mid-loop leaves the database in an inconsistent state.
   **Fix:** Move port sync into `CruiseRepository.saveCruise()` inside the existing `db.withTransaction` block.

### :yellow_circle: Important

4. **CruiseDetailViewModel.kt:44 — `hasAutoFetched` not scoped to a cruise.**
   Simple boolean flag. If user views cruise A (auto-fetch fires, flag = true), then navigates to cruise B, auto-fetch is skipped because the flag is already true.
   **Fix:** Track per cruise ID, or reset in `loadCruise()`.

5. **CruiseEditViewModel.kt:147,167 — Redundant geocode coroutines.**
   `onDeparturePortNameChange` debounces (800ms) then calls `geocodeDeparture()`, which launches a *new* coroutine. The debounce cancels the delay but not the inner geocode coroutine. Two rapid type-pause-type cycles produce two concurrent geocode requests; stale results can overwrite newer ones.
   **Fix:** Cancel previous geocode coroutine in `geocodeDeparture()`, or run geocode directly in the debounce coroutine.

6. **Converters.kt:11 — No error handling on `LocalDate.parse` in Room converter.**
   `DateTimeParseException` on corrupt DB data crashes the entire query.
   **Fix:** Wrap in try-catch returning null.

7. **WeatherRepository.kt:82-115 — Sequential API calls without parallelism.**
   5 years x N ports fetched serially. A 7-port cruise = 35 sequential HTTP calls, each with a 30s timeout.
   **Fix:** Use `async`/`awaitAll` to fetch years in parallel.

8. **Domain models depend on data-layer entities.**
   `CruiseWithPorts.kt:5-6`, `PortWithWeather.kt:4-6`, `CruiseComparison.kt:4` import Room entities. `WeatherFetchResult` (data layer) is consumed by domain use cases. UI screens also import entities directly.
   **Why it matters:** Room schema changes propagate through all layers. Violates the project's own `standards/project-structure.md`.
   **Fix:** Pragmatic trade-off for Phase 1, but create domain data classes before Phase 2.

9. **Rain probability duplicated in 4 locations with formula variations.**
   `CompareCruisesUseCase.kt:32` (proportion), `CompareCruisesUseCase.kt:50` (percentage), `PortWithWeather.kt:16` (percentage), `WeatherCard.kt:94-95` (percentage). Each has its own zero-check.
   **Fix:** Extract `PortWeatherSummary.rainProbabilityPct()` extension and use everywhere.

10. **CruiseEditViewModel.kt:63-116, 147-191 — Departure/return geocoding logic nearly identical.**
    ~80 lines duplicated, differing only in which state fields are read/written. Largest DRY violation in the codebase.
    **Fix:** Extract parameterized helper function.

11. **No test for `CruiseListViewModel`.**
    Contains `showCompareButton` derivation and `deleteCruise` method. Neither tested. Not listed in TEST_PLAN.md.
    **Fix:** Add `CruiseListViewModelTest`, update TEST_PLAN.md.

12. **`relaxed = true` on mocks weakens test sensitivity.**
    `FetchWeatherForCruiseUseCaseTest.kt:22` and `CruiseDetailViewModelTest.kt:39-40` use relaxed mocks. Unstubbed methods return defaults silently instead of failing, masking implementation changes.
    **Fix:** Remove `relaxed = true`, stub explicitly per test.

13. **Inconsistent fixture usage across test files.**
    `WeatherRepositoryTest` and `CruiseRepositoryTest` construct objects inline instead of using `TestFixtures.kt` factories. `CompareCruisesUseCaseTest` duplicates a `buildSummary` helper.
    **Fix:** Use shared fixture functions consistently.

14. **Turbine declared as test dependency but never used.**
    All Flow assertions use `.first()`, which only validates initial emission. Multi-emission ViewModel state transitions (loading -> loaded -> fetching) are not verifiable.
    **Fix:** Use Turbine's `test {}` for Flow-based ViewModel tests.

15. **`forceRefresh = true` path untested.**
    `FetchWeatherForCruiseUseCase` accepts `forceRefresh` but no test verifies it bypasses the `isFetchNeeded` check.

16. **Makefile:4 — `.PHONY` missing `itest` and `setup-check`.**
    **Fix:** Add to `.PHONY` declaration.

17. **NetworkModule.kt:32-44 — HttpClient never closed.**
    Singleton Ktor `HttpClient` leaks connection pools and threads. Mitigated by Android's process lifecycle but worth noting.

18. **DatabaseModule.kt:31-33 — `fallbackToDestructiveMigration` only guarded by DEBUG.**
    No mechanism to enforce migration creation before release. A schema version bump without migration silently deletes all user data.
    **Fix:** Add a test validating migrations exist for versions > 1.

### :green_circle: Suggestions

19. **OpenMeteoApi.kt:14-15 — API base URLs hardcoded.** Not configurable for testing. Inject via Hilt for mock server support.

20. **NavGraph.kt:51 — `getLong` returns 0L on null, not null.** The `?: return@composable` guard never triggers. Use `containsKey` check or `getString`/`toLongOrNull`.

21. **`PortFetchResult` co-located with `FetchWeatherForCruiseUseCase.kt`.** Should be its own file per Kotlin convention.

22. **`DATE_FORMAT` duplicated in 3 UI files.** `CruiseListScreen.kt:42`, `CruiseDetailScreen.kt:48`, `ComparisonScreen.kt:41`. Consolidate to shared location.

23. **`GeocodePortUseCase` is a pure pass-through.** Delegates entirely to `geocodingRepository.geocode()` with zero additional logic. Adds indirection without value.

24. **WeatherRepository.kt:144 — Catches `Exception` instead of `DateTimeException`.** Overly broad catch could mask bugs.

25. **WeatherCard.kt:35 — Dead `isSeaDay` parameter.** Never passed as `true` by any caller.

26. **WeatherRepository.kt:7 — Unused import `kotlinx.coroutines.flow.first`.**

27. **gradle/libs.versions.toml:53 — `hilt-navigation-compose` has hardcoded version** instead of version catalog reference.

28. **GETTING_STARTED.md:97-109 — References `./gradlew` instead of `make` targets.** Contradicts project convention.

29. **DTO field names embed unit assumptions** (e.g., `tempMaxF`). If API unit parameter changes, names become misleading.

30. **ComparisonViewModel uses `combine` pattern while other ViewModels use single `MutableStateFlow`.** Inconsistent state management approach.

31. **No retry logic for transient network failures.** Add Ktor `HttpRequestRetry` plugin.

32. **Makefile `setup-check` repeats SDK dir extraction 4 times.** Extract to shared variable or function.

### :white_check_mark: Strengths

- **Clean three-layer architecture.** Dependencies flow inward correctly: UI -> domain -> data. No backward references.
- **Proper `CancellationException` re-throw** in `WeatherRepository.kt:110-111`. Maintains structured concurrency — a common mistake this codebase gets right.
- **Transactional cruise save.** `CruiseRepository.saveCruise` correctly uses `db.withTransaction` for atomic multi-step operations.
- **`WhileSubscribed(5_000)` sharing strategy.** Correct pattern in `CruiseListViewModel`, avoids unnecessary DB queries while handling config changes.
- **Entity design is solid.** Foreign keys with CASCADE deletes, proper indices, documented denormalized fields.
- **Defensive JSON parsing.** `NetworkModule.kt` uses `ignoreUnknownKeys` and `coerceInputValues`.
- **Well-designed `WeatherFetchResult` sealed class.** Clean handling of Success/PartialSuccess/Failure/NoCoordinates.
- **Consistent naming conventions.** `*Screen`, `*ViewModel`, `*Repository`, `*UseCase`, `*Dao` throughout. `Generated By` headers on every file.
- **Well-organized version catalog.** All dependencies through `libs.versions.toml` with pinned versions, no known vulnerable versions.
- **Good test fixture design.** `TestFixtures.kt` with factory functions and named parameters — textbook approach.
- **Correct coroutine test patterns.** `StandardTestDispatcher`, `Dispatchers.setMain`/`resetMain`, `advanceUntilIdle()` used properly throughout.
- **Strong edge case coverage in `WeatherRepositoryTest`.** Leap year handling, exact boundary for `precipMm == 1.0`, empty daily data, partial failure, API errors.
- **Proper Room DAO testing.** In-memory databases, FK setup, `database.close()` cleanup. Real SQL behavior validated.
- **Debounced geocoding.** `CruiseEditViewModel` correctly implements 800ms debounce with job cancellation.
- **No embedded API keys.** Open-Meteo's free API requires no authentication.

## Detailed Analysis

### Architecture & Design

The project follows MVVM with Repository pattern, with structural layer separation via packages. Data flows through Room Flows -> Repositories -> ViewModels -> Compose via `collectAsStateWithLifecycle`. DI is correctly scoped: database and HttpClient are `@Singleton`, DAOs are unscoped.

The primary architectural shortcut is domain models directly referencing Room entities. This is pragmatic for Phase 1 but will become painful when entity-to-domain mapping diverges. `WeatherFetchResult` lives in the data layer but is consumed by domain use cases, inverting the intended dependency direction. `GeocodePortUseCase` is a pure pass-through that adds indirection without business logic.

The `CruiseDetailViewModel` has the most complex data flow and the most issues: the cancel-collect-restart pattern for weather fetching is fragile, and `hasAutoFetched` is not cruise-scoped.

### Implementation Quality

Strong Kotlin idioms overall. The most impactful issues are the race conditions in `CruiseDetailViewModel` (stale data overwriting fresh weather) and `CruiseEditViewModel` (unsaved port identity, redundant geocode coroutines). The port sync being outside a transaction is a data integrity risk.

Positive: proper `CancellationException` handling, `Result<T>` usage for geocoding, defensive JSON parsing, sealed class hierarchies for fetch results, and the debounced geocoding implementation.

### Test Quality & Coverage

Existing tests are well-structured with proper isolation, meaningful assertions via Google Truth, and correct coroutine test patterns. `WeatherRepositoryTest` is the standout with excellent boundary and edge case coverage.

Key gaps: `CruiseListViewModel` untested (and missing from test plan), Turbine declared but unused (Flow behavior only tested via `.first()`), `forceRefresh = true` untested, relaxed mocks reducing test sensitivity, and inconsistent fixture usage across test files.

### Maintainability & Standards

Naming is consistent and follows documented standards. Build configuration is clean with a well-organized version catalog. Functions are short and focused (longest ~35 lines).

Main DRY violations: rain probability in 4 places with formula variations, departure/return geocoding duplicated (~80 lines), date formatter in 3 files. One unused import, one hardcoded version in the catalog.

## Recommendations

Prioritized by impact:

1. **Fix `CruiseDetailViewModel` race condition** — cancel-collect-restart pattern causes stale data; use separate state flows or `combine()` (Critical #1)
2. **Fix unsaved port identity** — assign temporary IDs to prevent wrong-port edits/deletes (Critical #2)
3. **Wrap port sync in a transaction** — move into `CruiseRepository.saveCruise()` to prevent crash-induced corruption (Critical #3)
4. **Fix `hasAutoFetched` scoping** — track per cruise ID so all cruises get auto-fetched (Important #4)
5. **Fix redundant geocode launches** — cancel previous coroutine to prevent stale results (Important #5)
6. **Add error handling to `LocalDate.parse` converter** — prevent crash on corrupt data (Important #6)
7. **Parallelize weather API calls** — `async`/`awaitAll` for year fetching (Important #7)
8. **Unify rain probability calculation** — extract shared function (Important #9)
9. **Extract departure/return geocoding helper** — eliminate 80-line duplication (Important #10)
10. **Add `CruiseListViewModel` tests** — untested ViewModel with logic (Important #11)
11. **Remove `relaxed = true` from mocks** — strengthen test sensitivity (Important #12)
12. **Use Turbine for Flow testing** — validate multi-emission state transitions (Important #14)
13. **Fix Makefile for Windows** — add `SHELL := bash` or platform detection (Build)
14. **Create domain model classes** before Phase 2 — decouple from Room entities (Important #8)
