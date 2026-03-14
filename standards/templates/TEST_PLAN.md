# Test Plan

> Testing strategy for `org.jewzaam.cruiseweather`. Single source of truth for testing
> decisions and rationale.

## Overview

**Project:** Cruise Weather Planner
**Primary functionality:** Native Android app for comparing historical weather across cruise
itineraries.

## Testing Philosophy

This project follows [standards/testing.md](../standards/testing.md).

Key testing principles:

- Repository and aggregation logic must have unit tests; 80%+ coverage target
- Room DAOs tested with in-memory database (no mocks for persistence layer)
- UI tests cover the primary user flows, not exhaustive widget testing

## Test Categories

### Unit Tests (`src/test/`)

| Class | What's Tested |
|---|---|
| `WeatherAggregator` | Average computation, rain probability, null handling |
| `WeatherRepository` | Cache logic, API call decisions, error handling |
| `CruiseRepository` | CRUD operations via mocked DAOs |
| `FetchWeatherForCruiseUseCase` | Orchestration logic |
| `GeocodePortUseCase` | Candidate selection, error paths |
| `CompareCruisesUseCase` | Cross-cruise aggregation |

### Integration Tests (`src/androidTest/`)

| Class | What's Tested |
|---|---|
| `CruiseDaoTest` | Insert, update, delete, Flow emission |
| `PortOfCallDaoTest` | CRUD, cascade delete, sort order |
| `WeatherDaoTest` | Insert/replace conflict behavior |

### UI Tests (`src/androidTest/`)

| Flow | What's Tested |
|---|---|
| Create cruise | Form validation, date picker, geocoding confirmation |
| Add port of call | Date constraints, location disambiguation |
| Fetch weather | Loading state, error state, success state |
| Calendar view | Weather cards rendered for port days |
| Comparison | Cruise selection, table rendering |

## Untested Areas

| Area | Reason |
|---|---|
| Hilt DI wiring | Framework responsibility, not business logic |
| Material 3 theming | Visual-only, no behavior |
| Network responses from real API | Integration tested via fake/mock |

## Bug Fix Testing Protocol

All bug fixes **must** follow TDD. See [standards/testing.md](../standards/testing.md) for the protocol.

### Regression Tests

| Issue | Test | Description |
|---|---|---|
| *(none yet)* | — | — |

## Coverage Goals

**Target:** 80%+ line coverage of `data/` and `domain/` layers.

`ui/` layer: key flows covered by UI tests, no line coverage target.

## Running Tests

```bash
# Unit tests (fast, JVM)
./gradlew test

# Instrumented tests (requires device/emulator)
./gradlew connectedAndroidTest

# All tests
./gradlew test connectedAndroidTest
```

## Changelog

| Date | Change | Rationale |
|---|---|---|
| 2026-03-13 | Initial test plan | Project creation |
