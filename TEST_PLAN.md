# Test Plan

> Testing strategy for `org.jewzaam.cruiseweather`. Single source of truth for testing
> decisions and rationale.

## Overview

**Project:** Cruise Weather Planner
**Primary functionality:** Native Android app for comparing historical weather across cruise
itineraries.

## Testing Philosophy

This project follows [standards/testing.md](standards/testing.md).

Key testing principles:

- Repository and aggregation logic must have unit tests; 80%+ coverage target
- Room DAOs tested with in-memory database (no mocks for persistence layer)
- UI tests cover the primary user flows, not exhaustive widget testing

## Test Categories

### Unit Tests (`src/test/`)

| Class | What's Tested |
|---|---|
| `WeatherRepository` | Aggregation logic, cache invalidation logic, partial-failure handling |
| `CruiseRepository` | CRUD via mocked DAOs, port auto-creation on save |
| `FetchWeatherForCruiseUseCase` | Orchestration: skips fresh ports, handles no-coordinates |
| `GeocodePortUseCase` | Candidate mapping, error propagation |
| `CompareCruisesUseCase` | Cross-cruise aggregation, rain probability computation |

### Integration Tests (`src/androidTest/`)

| Class | What's Tested |
|---|---|
| `CruiseDaoTest` | Insert, update, delete, Flow emission, cascade |
| `PortOfCallDaoTest` | CRUD, sort order, departure/return type filtering |
| `WeatherDaoTest` | Insert/replace conflict behavior for summaries |

### UI Tests (`src/androidTest/`)

| Flow | What's Tested |
|---|---|
| Cruise list | FAB displayed, empty state, cruise cards |
| Create cruise | Form validation, save navigates back |
| Weather cards | Port day cards render with weather data |
| Comparison | Cruise selection, table renders metrics |

## Untested Areas

| Area | Reason |
|---|---|
| Hilt DI wiring | Framework responsibility, not business logic |
| Material 3 theming | Visual-only, no behavior |
| Real Open-Meteo API calls | External dependency; mocked in unit tests |

## Bug Fix Testing Protocol

All bug fixes **must** follow TDD. See [standards/testing.md](standards/testing.md) for the protocol.

### Regression Tests

| Issue | Test | Description |
|---|---|---|
| *(none yet)* | — | — |

## Coverage Goals

**Target:** 80%+ line coverage of `data/repository/` and `domain/` layers.

`ui/` layer: key flows covered by UI tests, no line coverage target.

## Running Tests

```bash
# Unit tests (fast, JVM)
./gradlew test

# Instrumented tests (requires device/emulator)
./gradlew connectedAndroidTest

# All
./gradlew test connectedAndroidTest
```

## Changelog

| Date | Change | Rationale |
|---|---|---|
| 2026-03-13 | Initial test plan | Project creation |
