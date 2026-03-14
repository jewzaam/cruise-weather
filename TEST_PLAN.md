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
- ViewModel tests use `StandardTestDispatcher` with MockK for dependencies

## Test Categories

### Unit Tests (`src/test/`)

| Class | What's Tested |
|---|---|
| `WeatherRepository` | Aggregation logic, existence-based fetch check, partial-failure handling, API error/empty responses, leap year handling |
| `CruiseRepository` | CRUD via mocked DAOs, port auto-creation on save, addPortOfCall/updatePortOfCall/deletePortOfCall delegation, null cruise path |
| `GeocodingRepository` | Display name building, feature code filtering, fallback on all-filtered, limit to 5, null results, API exception |
| `FetchWeatherForCruiseUseCase` | Orchestration: skips fresh ports, handles no-coordinates |
| `GeocodePortUseCase` | Candidate mapping, error propagation |
| `CompareCruisesUseCase` | Cross-cruise aggregation, rain probability computation |
| `Converters` | Round-trip LocalDate/Instant/PortType, null handling |
| `CruiseWithPorts` | departurePort, returnPort, portsOfCall filtering, allPortsChronological sorting, null/empty cases |
| `PortWithWeather` | hasWeather, rainProbabilityPct computation, null/zero cases |
| `CruiseEditViewModel` | State management, debounced geocoding, validation, save with port diffing, load, error handling |
| `CruiseDetailViewModel` | Loading from Flow, weather map building, auto-fetch, fetch messages, port CRUD with weather triggers |
| `ComparisonViewModel` | Toggle selection, comparison at 2+ cruises, job cancellation, error handling |

### Integration Tests (`src/androidTest/`)

| Class | What's Tested |
|---|---|
| `CruiseDaoTest` | Insert, update, delete, Flow emission, cascade |
| `PortOfCallDaoTest` | CRUD, sort order, departure/return type filtering |
| `WeatherDaoTest` | Insert/replace conflict behavior, getSummaryForPortOnce, getYearDataForPortOnce sorting, deleteSummaryForPort, batch insertWeatherYears |

## Untested Areas

| Area | Reason |
|---|---|
| Hilt DI wiring | Framework responsibility, not business logic |
| Material 3 theming | Visual-only, no behavior |
| Real Open-Meteo API calls | External dependency; mocked in unit tests |
| Compose UI screens | No UI tests; ViewModel tests cover logic |

## Bug Fix Testing Protocol

All bug fixes **must** follow TDD. See [standards/testing.md](standards/testing.md) for the protocol.

### Regression Tests

| Issue | Test | Description |
|---|---|---|
| *(none yet)* | — | — |

## Coverage Goals

**Target:** 80%+ line coverage of `data/repository/`, `domain/`, and ViewModel layers.

## Running Tests

```bash
# Unit tests (fast, JVM)
make test

# Instrumented tests (requires device/emulator)
make itest

# All
make test && make itest
```

## Changelog

| Date | Change | Rationale |
|---|---|---|
| 2026-03-13 | Initial test plan | Project creation |
| 2026-03-14 | Major test coverage expansion | Added ViewModel, GeocodingRepository, Converters, domain model tests; removed non-existent UI Tests section; fixed broken staleness test; updated coverage goals |
