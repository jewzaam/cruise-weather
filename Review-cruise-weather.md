# Code Review: cruise-weather

## TL;DR

The Phase 1 implementation follows clean architecture patterns with proper layer separation, Hilt DI, Room persistence, and Ktor networking. The codebase is well-organized with consistent naming and good Kotlin idioms. However, there are several issues that need attention before Phase 2: (1) non-transactional weather data replacement creates a data loss window on crash, (2) adding ports before saving a cruise creates orphaned database records, (3) multiple ViewModel operations lack error handling leaving the UI stuck in loading states, (4) date entry is non-functional (read-only fields with no picker), and (5) the `make` targets are broken on Windows due to shell compatibility. Test quality is solid where tests exist, but significant gaps remain — no ViewModel tests, no `GeocodingRepository` tests, and the test plan claims UI test coverage that doesn't exist.

## Build & Check Results

| Target | Status | Notes |
|--------|--------|-------|
| format | N/A | No target defined |
| lint | :x: | `make` uses `cmd.exe` for recipes; `./gradlew` (bash script) cannot execute. Root cause: Windows-native GNU Make dispatches to `cmd.exe` instead of a POSIX shell. |
| typecheck | N/A | No target defined |
| test | :x: | Same shell incompatibility as `lint` |
| coverage | N/A | No target defined |
| check | :x: | Meta-target (`lint` + `test`), same root cause |

**Root cause:** The installed `make` binary (ezwinports GNU Make 4.4.1) is a Windows-native build that dispatches recipes to `cmd.exe`. The Makefile recipes use `./gradlew` which is a bash script. Fix options: (1) add `SHELL := bash` to the Makefile, (2) use `gradlew.bat` with platform detection, or (3) install MSYS2/Git Bash `make`.

## Findings

### :red_circle: Critical

1. **WeatherRepository.kt:116-121 — Non-atomic delete-then-insert creates data loss window.** `deleteWeatherYearsForPort` and `deleteSummaryForPort` are called followed by inserts, but these operations are NOT wrapped in `db.withTransaction`. If the app crashes between delete and insert, all weather data for that port is lost with no recovery. Fix: wrap in `db.withTransaction {}`.

2. **CruiseEditScreen.kt:254-268 — Adding ports before saving cruise creates orphaned records.** `uiState.cruiseId` is `0L` until the cruise is first saved. `addPortOfCall` inserts a `PortOfCall` with `cruiseId = 0`, which has no matching cruise row. These records are orphaned and violate the foreign key relationship. Fix: disable "Add Port of Call" until the cruise is saved, or queue ports locally.

3. **WeatherCard.kt:71-73 — Integer division truncates rain percentage.** `summary.rainyYearCount * 100 / summary.totalYearCount` uses integer division, while `PortWithWeather.rainProbabilityPct` and `CompareCruisesUseCase` use floating-point division. This produces inconsistent rain percentages between the detail and comparison screens. Fix: use consistent floating-point calculation everywhere.

4. **DatabaseModule.kt:29 — Destructive migration enabled unconditionally.** `fallbackToDestructiveMigration(dropAllTables = true)` has no build-type guard. If this ships to users, any schema version bump silently deletes all their data. Fix: guard with `if (BuildConfig.DEBUG)` or implement proper migrations before release.

### :yellow_circle: Important

5. **CruiseEditViewModel.kt:187-200 — saveCruise has no error handling.** No try/catch around the database operation. If it throws, `isLoading` remains `true` forever, leaving the UI stuck. Same issue exists in `addPortOfCall` (line 252) and `updatePortOfCall` (line 258).

6. **CruiseDetailViewModel.kt:40-49 — Race condition between Flow collection and weather fetch.** `loadCruise` collects a reactive Flow but `buildPortWeatherMap` does one-shot queries. After `fetchWeather()` writes to `_uiState`, the Flow's `collect` callback can overwrite freshly fetched data with stale data. Fix: make weather data reactive or cancel the collect job during fetch.

7. **CruiseEditScreen.kt:106-123 — Date fields are non-functional.** Sail date and return date are `readOnly = true` with `onValueChange = {}`. No date picker exists. Users cannot change dates from the defaults (today / today+7). `onSailDateChange`/`onReturnDateChange` ViewModel methods are never called (dead code).

8. **GeocodingConfirmation.kt:78 — Hardcoded "N" and "E" coordinate labels.** Southern latitudes show as `-33.8600° N` and western longitudes as `-151.2100° E`. Fix: use `abs()` with conditional N/S and E/W.

9. **Theme.kt:59 — Unsafe cast of Context to Activity.** `(view.context as Activity)` will crash with `ClassCastException` if the context is wrapped (e.g., `ContextThemeWrapper`, Compose previews). Fix: use `view.context.findActivity()` or a safe cast.

10. **Domain models import data-layer entities directly.** `CruiseWithPorts.kt:5-6`, `PortWithWeather.kt:4-6`, `CruiseComparison.kt:4` all reference `data.local.entity.*`. Per `standards/project-structure.md:39`, domain should be pure Kotlin with no project dependencies. Room entity changes propagate into the domain layer.

11. **Repositories are concrete classes, not interfaces.** All three repositories are `@Singleton` concrete classes injected directly, preventing test double substitution via Hilt and violating dependency inversion.

12. **ComparisonViewModel.kt:66-84 — No debounce on comparison refresh.** Rapid toggling launches concurrent coroutines that all write to `_comparisons`, with no cancellation of previous jobs. Stale results can overwrite newer ones.

13. **TEST_PLAN.md claims UI tests exist, but none do.** The test plan documents UI tests for cruise list, create cruise, weather cards, and comparison flows, but zero UI test files exist under `src/androidTest/`. This gives false confidence in coverage.

14. **No ViewModel tests exist.** `CruiseEditViewModel` has non-trivial validation logic, port construction, and geocoding state management. `CruiseDetailViewModel` has fetch orchestration with message formatting. These are testable and untested.

15. **GeocodingRepository has zero test coverage.** It contains mapping logic (`GeocodingResult` → `GeocodingCandidate`), nullable field handling for `displayName`, and `results == null` handling — none of which is tested.

16. **WeatherRepository partial paths untested.** `PartialSuccess` return path, `response.error == true` path, and `daily == null` path have no test coverage.

17. **Makefile:4 — `.PHONY` omits `itest`.** The `itest` target is defined but not declared phony. If a file named `itest` were created, the target would be skipped.

18. **WeatherFetchResult defined in data layer, used in domain.** `WeatherFetchResult` is in `data.repository` but imported by `domain.usecase.FetchWeatherForCruiseUseCase`, creating a domain→data dependency.

### :green_circle: Suggestions

19. **WeatherRepository.kt:80-109 — Sequential API calls could be parallelized.** Five years × N ports are fetched serially. A 7-port cruise makes 35 sequential HTTP calls. Use `async`/`awaitAll` with a concurrency limiter.

20. **CruiseRepository.kt:29-38 — Unnecessary Flow overhead.** `flatMapLatest { ports -> flowOf(...) }` is equivalent to `.map { ... }`. The inner `flatMapLatest` + `flowOf` creates unnecessary Flow machinery.

21. **CruiseEditViewModel.kt:72-97, 122-162 — Significant code duplication.** Departure/return port-to-candidate mapping (lines 72-97) and `geocodeDeparture`/`geocodeReturn` (lines 122-162) are nearly identical. Extract shared functions.

22. **CruiseListScreen.kt:42, CruiseDetailScreen.kt:39 — Duplicated `DATE_FORMAT`.** Same `DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)` defined in two files.

23. **ComparisonScreen.kt:129 — Inconsistent date formatting.** Uses raw `toString()` (ISO format) while other screens use `DateTimeFormatter`.

24. **GeocodingConfirmation.kt:57,66 — Fully qualified class names inline.** `Row` and `Alignment` used as FQN instead of imports.

25. **Theme.kt:60 — Deprecated `window.statusBarColor`.** Deprecated in API 35+, app targets 36. `enableEdgeToEdge()` already handles this.

26. **libs.versions.toml:53 — `hilt-navigation-compose` has hardcoded version** instead of a version catalog reference.

27. **CompareCruisesUseCase.kt:31 — Non-null assertion on filtered nullable.** `pww.summary!!` is safe due to prior filter but bypasses compiler null safety. Use `let` or `mapNotNull`.

28. **CruiseListViewModel.kt:39-42 — Delete has no undo capability.** Fire-and-forget with no undo snackbar.

29. **FetchWeatherForCruiseUseCase.kt:11-14 — `PortFetchResult` defined in same file as use case.** Violates the one-class-per-file standard.

30. **CruiseDetailViewModel.kt:37 — Inconsistent naming.** Uses `detailState` instead of `uiState` used by all other ViewModels.

### :white_check_mark: Strengths

- **Clean architecture alignment.** File structure matches PLAN.md exactly. Every planned file exists in the correct package under `data/`, `domain/`, `ui/`, and `di/`.
- **Unified PortOfCall model with PortType.** Good design decision that correctly unifies weather storage for departure, port-of-call, and return port types using a single entity.
- **Proper CancellationException handling.** `WeatherRepository.kt:105-106` correctly re-throws `CancellationException` to maintain structured concurrency.
- **Transaction-wrapped cruise save.** `CruiseRepository.saveCruise` correctly uses `db.withTransaction` for atomic multi-step operations.
- **Consistent Generated By headers.** Every source file has the `// Generated By: Claude Code (claude-sonnet-4-6)` header per project standards.
- **Proper Flow sharing in ViewModels.** `SharingStarted.WhileSubscribed(5_000)` is the correct pattern, avoiding unnecessary database queries while giving grace period for config changes.
- **Defensive JSON parsing.** `NetworkModule.kt` uses `ignoreUnknownKeys` and `coerceInputValues` for graceful API response evolution.
- **No embedded API keys.** Open-Meteo's free API requires no authentication, eliminating credential management concerns.
- **Entity relationships with proper indexing.** All foreign keys have `CASCADE` delete and indexed columns.
- **Version catalog well-organized.** All dependencies properly declared through `libs.versions.toml` with pinned versions.
- **Existing tests are well-structured.** Good assertion quality using Google Truth, proper test isolation with in-memory Room databases, and correct `mockkStatic` cleanup.
- **Boundary condition testing.** `WeatherRepositoryTest` has specific tests for the `> 1.0mm` rain threshold, verifying exact boundary behavior.

## Detailed Analysis

### Architecture & Design

The project follows MVVM with Repository pattern. Layer separation is structural (packages) but not enforced by abstraction — domain models directly reference Room entities, and repositories are concrete classes rather than interfaces. The single-module structure is appropriate for this project's scope. Data flows through Room Flows → ViewModels → Compose via `collectAsStateWithLifecycle`, following recommended Android architecture patterns.

The most significant structural issue is the domain-layer dependency on Room entities. `CruiseWithPorts`, `PortWithWeather`, and `CruiseComparison` all import from `data.local.entity.*`, contradicting the project's own `standards/project-structure.md` rule that domain should depend on nothing in the project. This is a pragmatic trade-off for a small project but will become painful if entity-to-domain mapping diverges.

Sequential API calls for weather data (5 years × N ports) will cause poor UX as the app grows. The `WeatherFetchResult` sealed class with Success/PartialSuccess/Failure/NoCoordinates is well-designed for handling partial data scenarios.

### Implementation Quality

The codebase uses good Kotlin idioms overall. The most critical implementation issues are the non-transactional weather data replacement (crash between delete and insert loses data), orphaned port records when adding ports before saving a cruise, and missing error handling in several ViewModel `launch` blocks that can leave the UI permanently in a loading state.

The coordinate display bug (hardcoded N/E labels) will affect roughly half of all cruise ports. The integer-division rain percentage creates inconsistency between screens. The `CruiseDetailViewModel` Flow collection race condition can cause freshly fetched weather data to be overwritten by stale data.

On the positive side: proper `CancellationException` handling, correct `Result<T>` usage for geocoding, defensive JSON parsing, and well-designed sealed class hierarchies for fetch results.

### Test Quality & Coverage

Existing tests are well-structured with proper isolation (in-memory Room databases, MockK with cleanup), meaningful assertions (Google Truth), and good scenario coverage for the classes they test. Boundary testing for the rain threshold is particularly well-done.

Key gaps: no ViewModel tests despite non-trivial logic in `CruiseEditViewModel` and `CruiseDetailViewModel`, no `GeocodingRepository` tests, untested `WeatherRepository` paths (PartialSuccess, error responses, null daily data), no `CompareCruisesUseCase` multi-cruise test, and missing DAO operation tests (deleteSummaryForPort, update). The test plan claims UI test coverage that doesn't exist. The 80% coverage target for `data/repository/` and `domain/` layers is likely not met.

### Maintainability & Standards

Naming conventions are consistent and follow documented standards (`*Screen`, `*ViewModel`, `*Repository`, `*UseCase`, `*Dao`). Every file has the required `Generated By` header. The version catalog is well-organized.

The main DRY violations are: rain probability calculation in three places with inconsistent implementations, duplicated geocoding logic in `CruiseEditViewModel`, and duplicated date formatting across screens. The `CruiseRepository` uses unnecessary `flatMapLatest` + `flowOf` where a simple `map` would suffice. A few files use fully qualified class names inline instead of imports.

## Recommendations

Prioritized by impact:

1. **Wrap weather data replacement in a transaction** — prevents data loss on crash (Critical #1)
2. **Fix orphaned port records** — prevent adding ports before cruise is saved, or batch them in the save transaction (Critical #2)
3. **Add error handling to ViewModel operations** — try/catch around DB operations, reset `isLoading`, surface errors to UI (Important #5)
4. **Fix the Makefile for Windows** — add `SHELL := bash` or platform detection so the CI/local build targets work (Build)
5. **Implement date picker UI** — dates are currently non-functional (Important #7)
6. **Fix coordinate display** — use abs() with conditional N/S E/W (Important #8)
7. **Unify rain probability calculation** — extract shared function, fix integer division (Critical #3)
8. **Guard destructive migration with DEBUG check** — prevent user data loss on schema changes (Critical #4)
9. **Add ViewModel and GeocodingRepository tests** — biggest coverage gaps (Important #14, #15)
10. **Update TEST_PLAN.md** — remove claims of UI test coverage that doesn't exist (Important #13)
11. **Fix CruiseDetailViewModel race condition** — make weather data reactive or cancel collect during fetch (Important #6)
12. **Extract repository interfaces** — enables proper test double injection via Hilt (Important #11)
