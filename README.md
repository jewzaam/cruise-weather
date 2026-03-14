# Cruise Weather Planner

![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Min SDK](https://img.shields.io/badge/minSdk-33-green)

A native Android app for comparing historical weather across cruise itineraries. Create cruises
with departure and port-of-call details, fetch 5-year historical averages from Open-Meteo's free
API, and compare weather side-by-side across multiple sailings.

## Features

- Create and manage cruise itineraries with departure/return dates and ports of call
- Geocode port locations via Open-Meteo's geocoding API with candidate confirmation
- Custom display names for ports (defaults to geocoded name, overridable to match cruise itinerary)
- Fetch historical weather averages (5 years, ±2 day window) for each port day
- Day-by-day itinerary view with weather summaries and "At Sea" markers
- Auto-fetch weather when viewing a cruise — no manual step needed
- Add ports directly from the cruise overview on any sea day
- Side-by-side comparison table across multiple cruises
- Transactional cruise editing — changes aren't saved until you confirm
- All data local to the device — no accounts, no cloud

## Setup

See [GETTING_STARTED.md](GETTING_STARTED.md) for detailed setup instructions.

### Quick start

1. JDK 21 and Android SDK (API 36) required
2. Clone the repository
3. Create `local.properties` with your SDK path (or set `ANDROID_HOME`)
4. Validate: `make setup-check`
5. Build: `./gradlew build`
6. Run on a device or emulator (API 33+): `./gradlew installDebug`

### Tests

```bash
# Unit tests (JVM, no device required)
./gradlew test

# Instrumented tests (requires connected device or emulator)
./gradlew connectedAndroidTest
```

## Architecture

Kotlin + Jetpack Compose + Room + Hilt + Ktor. Clean MVVM architecture with Repository pattern.

See [PLAN.md](PLAN.md) for full architecture details and [TEST_PLAN.md](TEST_PLAN.md) for testing strategy.

## Data Sources

Weather data provided by [Open-Meteo](https://open-meteo.com/) — free, no API key required. Historical weather is fetched once per port and cached locally. Geocoding uses Open-Meteo's geocoding API with filtering to prioritize populated places over airports and other features.

## License

Copyright 2026 jewzaam

This project is dual-licensed:

- **Open source** — [GNU General Public License v3.0](LICENSE). You may use, modify, and distribute this software under the terms of the GPL-3.0.
- **Commercial** — A separate commercial license is available for use cases that are incompatible with the GPL-3.0 (e.g., proprietary distribution without source code obligations). Contact the copyright holder for terms.

Contributions are welcome under the GPL-3.0. By submitting a pull request, you agree that your contributions may also be offered under the commercial license.
