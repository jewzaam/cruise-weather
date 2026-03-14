# Project Structure Standards

## Required Files in Repository Root

| File | Required | Purpose |
|---|---|---|
| `LICENSE` | ✅ | Apache 2.0 |
| `README.md` | ✅ | Project overview, setup, usage |
| `TEST_PLAN.md` | ✅ | Testing strategy and rationale |
| `standards/` | ✅ | This directory |
| `PLAN.md` | ✅ | Original project design document |
| `.gitignore` | ✅ | Standard Android ignores |

## Android Module Structure

Follow clean architecture with clear layer separation:

```
app/src/main/java/org/jewzaam/cruiseweather/
├── data/
│   ├── local/          # Room: entities, DAOs, database, converters
│   ├── remote/         # Network: API client, DTOs
│   └── repository/     # Repository implementations
├── domain/
│   ├── model/          # Domain models (not Room entities)
│   └── usecase/        # Business logic
├── ui/
│   ├── navigation/     # NavGraph
│   ├── theme/          # Material 3 theme
│   └── <feature>/      # One package per screen: Screen.kt + ViewModel.kt
├── di/                 # Hilt modules
└── CruiseWeatherApp.kt
```

## Layer Rules

- `data/local/` depends on nothing in the project
- `data/repository/` depends on `data/local/` and `data/remote/`
- `domain/` depends on nothing in the project (pure Kotlin)
- `ui/` depends on `domain/` and injects repositories via Hilt
- `di/` wires everything together

## Naming

| Item | Convention | Example |
|---|---|---|
| Screens | `<Feature>Screen.kt` | `CruiseDetailScreen.kt` |
| ViewModels | `<Feature>ViewModel.kt` | `CruiseDetailViewModel.kt` |
| Repositories | `<Domain>Repository.kt` | `WeatherRepository.kt` |
| Use cases | `<Verb><Noun>UseCase.kt` | `FetchWeatherForCruiseUseCase.kt` |
| DAOs | `<Entity>Dao.kt` | `CruiseDao.kt` |
| Entities | `<Name>.kt` (no suffix) | `Cruise.kt`, `PortOfCall.kt` |
| DTOs | `<Name>Response.kt` | `GeocodingResponse.kt` |

## One Class Per File

Each Kotlin file contains exactly one top-level class/interface/object. Companion data classes
and sealed class variants are the exception.
