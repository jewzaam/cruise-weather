# Logging Standards

Android logging conventions using [Timber](https://github.com/JakeWharton/timber).

## Setup

Initialize Timber in the `Application` class (debug builds only):

```kotlin
class CruiseWeatherApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }
}
```

## Log Levels

| Level | Use For |
|---|---|
| `Timber.v()` | Verbose: detailed execution flow, loop iterations |
| `Timber.d()` | Debug: variable values, state transitions |
| `Timber.i()` | Info: operational milestones, API responses received |
| `Timber.w()` | Warning: recoverable issues, unexpected-but-handled states |
| `Timber.e()` | Error: failures that prevent an operation from completing |

## Guidelines

**Log operational milestones at INFO:**

```kotlin
Timber.i("Fetching weather for portId=%d, years=%d", portId, yearsBack)
Timber.i("Weather fetch complete: portId=%d, summaryId=%d", portId, summaryId)
```

**Log details at DEBUG:**

```kotlin
Timber.d("Geocoding result: name=%s lat=%f lon=%f", name, lat, lon)
```

**Log failures at ERROR with context:**

```kotlin
Timber.e(exception, "Weather fetch failed: portId=%d", portId)
```

**Log unexpected-but-handled states at WARNING:**

```kotlin
Timber.w("Port %d has no resolved coordinates, skipping weather fetch", portId)
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| `Log.d(TAG, ...)` directly | Bypasses Timber, inconsistent | Use `Timber.d()` |
| String concatenation in log args | Wastes memory even when not logging | Use format args |
| `if (BuildConfig.DEBUG) Timber.d(...)` | Redundant — Timber handles this | Remove the conditional |
| Logging in DAO/Entity classes | Wrong layer | Log in repository or use case |
| Single log call per field | Fragmented, hard to read | Combine into one log with key=value |

```kotlin
// BAD — multiple fragmented calls
Timber.d("Fetching weather")
Timber.d("Port: $portName")
Timber.d("Coordinates: $lat, $lon")

// GOOD — single structured call
Timber.d("Fetching weather: port=%s lat=%f lon=%f", portName, lat, lon)
```

## What Not to Log

- Personally identifiable information
- User-entered cruise names or notes (they may contain PII)
- Raw API response bodies in production
