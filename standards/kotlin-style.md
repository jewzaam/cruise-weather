# Kotlin Style Standards

## Named Parameters

**Prefer explicit named parameters over positional parameters when calling functions with optional arguments.**

This is the same principle as Python's named-parameter rule, enforced by Kotlin's native named-argument syntax.

### Rule

When calling functions with multiple parameters, especially those with default values, use named
argument syntax instead of relying on positional order.

### Rationale

Positional parameters are error-prone:
- Parameter order changes can silently break callers
- Boolean flags are unreadable without names
- Code is harder to understand without reading the full signature

### Example

```kotlin
// BAD — what does true, false mean here?
fetchWeather(portId, true, false)

// GOOD — intent is clear
fetchWeather(portId = portId, forceRefresh = true, historical = false)
```

### Guidelines

**Required parameters (no default):** positional or named, both acceptable.

```kotlin
// Both acceptable for required params
Cruise(name = "Test", sailDate = today, returnDate = nextWeek)
Cruise("Test", today, nextWeek)
```

**Optional parameters (have defaults):** must use named syntax.

```kotlin
// WRONG
viewModel.loadCruise(cruiseId, true, 5)

// CORRECT
viewModel.loadCruise(
    cruiseId = cruiseId,
    forceRefresh = true,
    historyYears = 5,
)
```

**Boolean flags:** always use named syntax regardless of position.

```kotlin
// WRONG
repository.fetchWeather(portId, true)

// CORRECT
repository.fetchWeather(portId = portId, forceRefresh = true)
```

## Function Definitions: Enforce Named Parameters

For functions with optional parameters, place them after required parameters and document
intent clearly. Kotlin does not have `*` syntax, but use default-value parameters in a
distinct group at the end of the parameter list.

```kotlin
// Required params first, optional params last
suspend fun fetchHistoricalWeather(
    latitude: Double,
    longitude: Double,
    date: LocalDate,
    yearsBack: Int = 5,          // optional — always call as named
    forceRefresh: Boolean = false // optional — always call as named
): WeatherResult
```

## Trailing Commas

Always use trailing commas in multi-line parameter lists and argument lists. This reduces diff
noise when adding/removing parameters.

```kotlin
// CORRECT
data class Cruise(
    val id: Long = 0,
    val name: String,
    val sailDate: LocalDate,
    val returnDate: LocalDate,   // trailing comma
)
```

## Immutability Preference

- Prefer `val` over `var` everywhere possible
- Prefer immutable data classes
- Prefer `listOf()` / `mapOf()` over mutable collections unless mutation is required
