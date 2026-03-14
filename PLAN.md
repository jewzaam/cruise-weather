# Cruise Weather Planner — Build Plan (Android Native)

## TL;DR

A native Android app (Kotlin, Jetpack Compose, Room) where users create cruise itineraries with departure/return dates and ports of call. The app fetches real historical weather data from Open-Meteo's free API for each port day, displaying climate conditions in a calendar view per cruise and a side-by-side comparison table across cruises. All data is local to the device. Targets Android 16 (API 36).

---

## Architecture

### Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Kotlin | Android-native, first-class Compose support |
| UI | Jetpack Compose + Material 3 | Native Android 16 design system, declarative UI |
| Local DB | Room (SQLite) | Structured relational data, type-safe queries, offline-first |
| Networking | Ktor Client or Retrofit + kotlinx.serialization | Lightweight HTTP for Open-Meteo API calls |
| Async | Kotlin Coroutines + Flow | Standard for Compose + Room reactivity |
| DI | Hilt | Standard Android DI, integrates with ViewModel/Room |
| Geocoding | Open-Meteo Geocoding API | Free, no key, pairs with weather API |
| Weather | Open-Meteo Historical Weather API | Free, no key, global, data back to 1940 |
| Architecture | MVVM with Repository pattern | Clean separation, testable |
| Min SDK | 33 (Android 13) | Broad device support while using modern APIs |
| Target SDK | 36 (Android 16) | Required for Android 16 compliance |
| Build | Gradle KTS + Version Catalogs | Modern Android build setup |

### Data Flow

```
User creates cruise → enters ports + dates
        │
        ▼
Room DB stores cruise + port data locally
        │
        ▼
User taps "Fetch Weather"
        │
        ▼
Geocoding API (Open-Meteo)
  Port location text → lat/lon candidates
  User confirms if ambiguous → resolved coords saved to Room
        │
        ▼
Historical Weather API (Open-Meteo)
  lat/lon + date range (same dates, prior 5 years) → daily weather
        │
        ▼
Aggregation layer (in-app)
  Compute averages + ranges from multi-year data
  Store results in Room
        │
        ▼
Compose UI renders
  Calendar view per cruise
  Comparison table across cruises
```

---

## Open-Meteo API Details

### Geocoding — Resolve Port Locations

```
GET https://geocoding-api.open-meteo.com/v1/search
  ?name={user_entered_location}
  &count=5
  &language=en
```

Response includes `latitude`, `longitude`, `country`, `admin1` (state/region), `name`. Present candidates to user for confirmation if ambiguous. Store resolved coordinates in Room.

### Historical Weather — Fetch Real Data

```
GET https://archive-api.open-meteo.com/v1/archive
  ?latitude={lat}
  &longitude={lon}
  &start_date={YYYY-MM-DD}
  &end_date={YYYY-MM-DD}
  &daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_hours,
         wind_speed_10m_max,wind_gusts_10m_max,relative_humidity_2m_mean,
         uv_index_max,sunshine_duration
  &temperature_unit=fahrenheit
  &wind_speed_unit=mph
  &timezone=auto
```

#### Variables Mapped to Requirements

| Requirement | API Variable(s) | Notes |
|------------|-----------------|-------|
| Temperature highs/lows | `temperature_2m_max`, `temperature_2m_min` | Daily aggregation |
| Rain/precipitation | `precipitation_sum`, `precipitation_hours` | mm total + hours with precip |
| Wind speed | `wind_speed_10m_max`, `wind_gusts_10m_max` | Max sustained + gusts in mph |
| UV index | `uv_index_max` | Daily max; available ~2000+ via ERA5 |
| Humidity | `relative_humidity_2m_mean` | Daily mean relative humidity % |
| Sunshine | `sunshine_duration` | Seconds of sunshine per day |

#### Date Strategy for Future Cruises

For cruise dates beyond the ~16-day forecast window:

1. Pull the **same calendar dates from the prior 5 years** (e.g., cruise port call on Dec 15, 2026 → fetch Dec 15 from 2021–2025)
2. Compute averages + min/max ranges across those years
3. Display as "typical conditions" with spread indicators
4. If the cruise date is within forecast range, use the Forecast API for real predictions

#### Forecast API — Near-Term Dates

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &daily=temperature_2m_max,temperature_2m_min,precipitation_sum,
         precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,
         uv_index_max
  &temperature_unit=fahrenheit
  &wind_speed_unit=mph
  &timezone=auto
```

Use when port call dates fall within the next 16 days.

---

## Data Model (Room Entities)

### Implementation Decisions (deviations from original design)

1. **Unified PortOfCall model** — Departure and return ports are stored as `PortOfCall` rows with `type = DEPARTURE` / `RETURN` instead of embedded fields on `Cruise`. This enables unified weather storage for all ports. `Cruise` keeps `departurePortName`/`returnPortName` as denormalized display-only fields for fast list queries.

2. **Forecast API deferred** — Phase 1 uses historical averages only. `ForecastResponse.kt` not present in Phase 1.

3. **Derived metrics** — Rain probability (`rainyYearCount`/`totalYearCount`) and weather condition icons are kept. "Just report data" means no overall "good/bad" labels, not no derived stats.

4. **Package name** — `org.jewzaam.cruiseweather`

5. **Historical year depth** — 5 years, hardcoded.

6. **Precipitation threshold** — >1mm internally for `rainyYearCount`. Raw data (mm and hours) always displayed; no "rainy day" label shown in UI.

7. **Database migrations** — `fallbackToDestructiveMigration()` during pre-release. Switch to explicit `Migration` objects before any production release.

### Entity Relationship

```
Cruise (1) ──── (0..*) PortOfCall  (type = DEPARTURE | PORT_OF_CALL | RETURN)
                            │
                            └──── (0..*) PortWeatherYear    (one per sampled year)
                            │
                            └──── (0..1) PortWeatherSummary  (aggregated averages)
```

### Cruise

```kotlin
// Coordinates removed from Cruise — they live on PortOfCall rows (type=DEPARTURE/RETURN).
// departurePortName/returnPortName kept as denormalized display-only fields.
@Entity(tableName = "cruises")
data class Cruise(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val sailDate: LocalDate,
    val returnDate: LocalDate,
    val departurePortName: String,
    val returnPortName: String? = null,  // null = same as departure
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)
```

### PortOfCall

```kotlin
// type field added to unify departure/return storage with ports of call.
// DEPARTURE and RETURN rows are auto-created/updated when Cruise is saved.
@Entity(...)
data class PortOfCall(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val cruiseId: Long,
    val portName: String,
    val date: LocalDate,
    val type: PortType = PortType.PORT_OF_CALL,  // NEW
    val latitude: Double? = null,
    val longitude: Double? = null,
    val resolvedDisplayName: String? = null,
    val sortOrder: Int = 0,
)

enum class PortType { DEPARTURE, PORT_OF_CALL, RETURN }
```

### PortWeatherYear (raw per-year data)

```kotlin
@Entity(
    tableName = "port_weather_years",
    foreignKeys = [ForeignKey(
        entity = PortOfCall::class,
        parentColumns = ["id"],
        childColumns = ["portOfCallId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("portOfCallId")]
)
data class PortWeatherYear(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val portOfCallId: Long,
    val year: Int,                       // which historical year this came from
    val tempHighF: Double,
    val tempLowF: Double,
    val precipMm: Double,
    val precipHours: Double,
    val windMaxMph: Double,
    val windGustMph: Double,
    val humidityPct: Double,
    val uvIndexMax: Double,
    val sunshineDurationSec: Double
)
```

### PortWeatherSummary (computed aggregates)

```kotlin
@Entity(
    tableName = "port_weather_summaries",
    foreignKeys = [ForeignKey(
        entity = PortOfCall::class,
        parentColumns = ["id"],
        childColumns = ["portOfCallId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("portOfCallId", unique = true)]
)
data class PortWeatherSummary(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val portOfCallId: Long,
    val dataSource: String,              // "historical_avg" or "forecast"
    val yearsUsed: String,               // e.g. "2021,2022,2023,2024,2025"
    val avgTempHighF: Double,
    val avgTempLowF: Double,
    val tempHighMin: Double,             // lowest high across sampled years
    val tempHighMax: Double,             // highest high across sampled years
    val tempLowMin: Double,
    val tempLowMax: Double,
    val avgPrecipMm: Double,
    val avgPrecipHours: Double,
    val rainyYearCount: Int,             // years with >1mm precip (for probability)
    val totalYearCount: Int,             // total years sampled
    val avgWindMaxMph: Double,
    val avgWindGustMph: Double,
    val avgHumidityPct: Double,
    val avgUvIndexMax: Double,
    val avgSunshineMins: Double,         // converted from seconds
    val fetchedAt: Instant = Instant.now()
)
```

### Room DAOs

```kotlin
@Dao
interface CruiseDao {
    @Query("SELECT * FROM cruises ORDER BY sailDate ASC")
    fun getAllCruises(): Flow<List<Cruise>>

    @Query("SELECT * FROM cruises WHERE id = :id")
    fun getCruiseById(id: Long): Flow<Cruise?>

    @Insert
    suspend fun insert(cruise: Cruise): Long

    @Update
    suspend fun update(cruise: Cruise)

    @Delete
    suspend fun delete(cruise: Cruise)
}

@Dao
interface PortOfCallDao {
    @Query("SELECT * FROM ports_of_call WHERE cruiseId = :cruiseId ORDER BY date ASC, sortOrder ASC")
    fun getPortsForCruise(cruiseId: Long): Flow<List<PortOfCall>>

    @Insert
    suspend fun insert(port: PortOfCall): Long

    @Update
    suspend fun update(port: PortOfCall)

    @Delete
    suspend fun delete(port: PortOfCall)

    @Query("DELETE FROM ports_of_call WHERE id = :portId")
    suspend fun deleteById(portId: Long)
}

@Dao
interface WeatherDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertWeatherYear(data: PortWeatherYear)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSummary(summary: PortWeatherSummary)

    @Query("SELECT * FROM port_weather_summaries WHERE portOfCallId = :portId")
    fun getSummaryForPort(portId: Long): Flow<PortWeatherSummary?>

    @Query("SELECT * FROM port_weather_years WHERE portOfCallId = :portId ORDER BY year ASC")
    fun getYearDataForPort(portId: Long): Flow<List<PortWeatherYear>>

    @Query("DELETE FROM port_weather_years WHERE portOfCallId = :portId")
    suspend fun deleteWeatherYearsForPort(portId: Long)

    @Query("DELETE FROM port_weather_summaries WHERE portOfCallId = :portId")
    suspend fun deleteSummaryForPort(portId: Long)
}
```

---

## User Flow

### Screen 1: Cruise List (Home)

```
┌─────────────────────────────────────┐
│  ⛴️  Cruise Weather Planner        │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Harmony of the Seas         │    │
│  │ Dec 14 – Dec 21, 2026      │    │
│  │ Miami, FL • 4 ports         │    │
│  │ Weather: ✅ Fetched          │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Wonder of the Seas          │    │
│  │ Mar 8 – Mar 15, 2027       │    │
│  │ Port Canaveral, FL • 3 ports│    │
│  │ Weather: ⏳ Not fetched      │    │
│  └─────────────────────────────┘    │
│                                     │
│        [+ New Cruise]               │
│                                     │
│  [Compare Cruises]  (if 2+ exist)   │
└─────────────────────────────────────┘
```

- List of all saved cruises sorted by sail date
- Each card shows name, date range, departure port, port count, weather status
- FAB or button to add new cruise
- Compare button appears when 2+ cruises exist
- Swipe-to-delete or long-press context menu

### Screen 2: Create/Edit Cruise

```
┌─────────────────────────────────────┐
│  ← New Cruise                       │
├─────────────────────────────────────┤
│                                     │
│  Cruise Name                        │
│  ┌─────────────────────────────┐    │
│  │ Harmony of the Seas - Dec 26│    │
│  └─────────────────────────────┘    │
│                                     │
│  Sail Date              Return Date │
│  ┌────────────┐  ┌────────────┐     │
│  │ Dec 14, 2026│  │ Dec 21, 2026│   │
│  └────────────┘  └────────────┘     │
│                                     │
│  Departure Port                     │
│  ┌─────────────────────────────┐    │
│  │ Miami, FL                   │    │
│  └─────────────────────────────┘    │
│  ✅ Miami, Miami-Dade County, US    │
│     25.7617° N, 80.1918° W         │
│                                     │
│  ☐ Different return port            │
│  (unchecked by default)             │
│                                     │
│  ─── Ports of Call ───              │
│                                     │
│  No ports of call yet.              │
│                                     │
│  [+ Add Port of Call]               │
│                                     │
│  [Save Cruise]                      │
└─────────────────────────────────────┘
```

**Inputs:**
- **Cruise Name**: free text, required
- **Sail Date**: date picker, required
- **Return Date**: date picker, required, must be >= sail date
- **Departure Port**: free text location entry. On blur/confirm, geocode via Open-Meteo and show resolved result below. User taps to select from candidates if ambiguous.
- **Different return port**: checkbox, unchecked by default. When checked, shows a return port text field + geocoding. When unchecked, return port = departure port.
- **Ports of Call**: list, initially empty. Each entry added via "Add Port of Call" flow.

**Validation:**
- Name required
- Sail date required
- Return date required, >= sail date
- Departure port required, must be geocoded
- Port of call dates must fall within sail date–return date range

### Screen 2a: Add/Edit Port of Call (Bottom Sheet or Dialog)

```
┌─────────────────────────────────────┐
│  Add Port of Call                   │
├─────────────────────────────────────┤
│                                     │
│  Date                               │
│  ┌─────────────────────────────┐    │
│  │ Dec 16, 2026               │    │
│  └─────────────────────────────┘    │
│                                     │
│  Location                           │
│  ┌─────────────────────────────┐    │
│  │ Cozumel, Mexico            │    │
│  └─────────────────────────────┘    │
│                                     │
│  Select location:                   │
│  ● Cozumel, Quintana Roo, MX       │
│    20.4318° N, 86.9203° W          │
│  ○ Cozumel Island, MX              │
│    20.4230° N, 86.9223° W          │
│                                     │
│  [Cancel]            [Save Port]    │
└─────────────────────────────────────┘
```

Once saved, the port appears in the cruise's port list with edit/delete options.

### Screen 3: Cruise Detail + Calendar View

```
┌─────────────────────────────────────┐
│  ← Harmony of the Seas              │
│  Dec 14 – Dec 21, 2026             │
├─────────────────────────────────────┤
│  [Edit] [Fetch Weather] [Delete]    │
│                                     │
│  ┌──────────┐ ┌──────────┐         │
│  │ Dec 14   │ │ Dec 15   │         │
│  │ Miami    │ │ At Sea   │         │
│  │ ☀️ 79°F  │ │ ──       │         │
│  │ Lo: 68°F │ │          │         │
│  │ 🌧 12%   │ │          │         │
│  │ 💨 12mph │ │          │         │
│  │ ☀ UV: 8  │ │          │         │
│  │ 💧 72%   │ │          │         │
│  └──────────┘ └──────────┘         │
│  ┌──────────┐ ┌──────────┐         │
│  │ Dec 16   │ │ Dec 17   │         │
│  │ Cozumel  │ │ Roatán   │         │
│  │ ⛅ 82°F  │ │ 🌧 80°F   │         │
│  │ Lo: 71°F │ │ Lo: 73°F │         │
│  │ 🌧 22%   │ │ 🌧 45%    │         │
│  │ 💨 15mph │ │ 💨 18mph  │         │
│  │ ☀ UV: 9  │ │ ☀ UV: 7   │         │
│  │ 💧 78%   │ │ 💧 82%    │         │
│  └──────────┘ └──────────┘         │
│  ...                                │
│                                     │
│  * Based on 2021–2025 averages      │
│  Tap a card for year-by-year detail │
└─────────────────────────────────────┘
```

- Horizontal scrollable row or grid of weather cards
- Departure day shows weather for departure port
- Return day shows weather for return port
- Days with no port of call show "At Sea" (no weather data unless Phase 4)
- Days with a port of call show weather summary
- Tapping a card expands to show year-by-year breakdown + ranges
- "Fetch Weather" triggers geocoding (if needed) + API calls for all unresolved ports

### Screen 4: Comparison Table

```
┌─────────────────────────────────────┐
│  ← Compare Cruises                  │
├─────────────────────────────────────┤
│                                     │
│  Select cruises to compare:         │
│  ☑ Harmony (Dec 2026)              │
│  ☑ Wonder (Mar 2027)               │
│  ☐ Allure (Jun 2027)               │
│                                     │
├─────────────────────────────────────┤
│               │ Harmony  │ Wonder   │
│               │ Dec '26  │ Mar '27  │
├───────────────┼──────────┼──────────┤
│ Avg High      │ 80°F     │ 76°F    │
│ Avg Low       │ 71°F     │ 65°F    │
│ Rain Chance   │ 24%      │ 35%     │
│ Avg Precip    │ 2.1mm    │ 3.4mm   │
│ Avg Wind      │ 14 mph   │ 18 mph  │
│ Avg UV        │ 8.3      │ 6.1     │
│ Avg Humidity  │ 77%      │ 71%     │
│ Sunshine hrs  │ 7.2      │ 6.8     │
│ Rainiest Port │ Roatán   │ Nassau  │
│               │ 45%      │ 38%     │
├───────────────┴──────────┴──────────┤
│                                     │
│  ▸ Per-port breakdown (expandable)  │
│                                     │
└─────────────────────────────────────┘
```

- Select 2+ cruises with weather data to compare
- Aggregate stats across all port days per cruise
- Color coding: green/yellow/red for relative favorability
- Expandable per-port detail rows below summary
- Horizontally scrollable if comparing 3+ cruises

---

## Implementation Phases

### Phase 1: Core Data Entry + Single Cruise Weather

- [ ] Android project setup: Kotlin, Compose, Hilt, Room, Ktor/Retrofit
- [ ] Room database with Cruise, PortOfCall, PortWeatherYear, PortWeatherSummary entities
- [ ] Room type converters for LocalDate, Instant
- [ ] Cruise list screen (home) with add/delete
- [ ] Create/edit cruise screen
  - Cruise name, sail date, return date
  - Departure port with geocoding + confirmation
  - Optional different return port (checkbox toggle)
- [ ] Add/edit/delete port of call (bottom sheet)
  - Date picker constrained to sail–return range
  - Location text + geocoding + candidate selection
- [ ] Open-Meteo API client
  - Geocoding endpoint
  - Historical weather endpoint
  - Response parsing with kotlinx.serialization
- [ ] Weather fetch logic
  - Determine if date is within forecast range or historical
  - For historical: fetch same dates from prior 5 years
  - Aggregate into summary (averages + ranges)
  - Derive rain probability from multi-year sample
  - Store raw years + summary in Room
- [ ] Cruise detail screen with calendar view
  - Weather cards per port day
  - Departure and return port days included
  - "At Sea" placeholder for days without a port
- [ ] Loading states, error handling, retry logic

### Phase 2: Multi-Cruise Comparison

- [ ] Comparison screen with cruise selection (checkboxes)
- [ ] Aggregate stats computation across port days per cruise
- [ ] Comparison table layout (horizontally scrollable)
- [ ] Color coding for favorable/unfavorable metrics
- [ ] Expandable per-port detail rows
- [ ] Handle edge case: cruises with no weather data yet

### Phase 3: Polish

- [ ] Material 3 theming and dynamic color
- [ ] Unit toggle: °F/°C, mph/km/h (stored as DataStore preference)
- [ ] Swipe-to-delete on cruise list and port list
- [ ] Pull-to-refresh weather data
- [ ] Empty states with guidance text
- [ ] Date validation edge cases (leap years, year boundaries)
- [ ] Landscape support / adaptive layout for tablets
- [ ] Weather data staleness indicator (show when data was last fetched)

### Phase 4: Nice-to-Haves

- [ ] Forecast API integration for dates within 16-day window
- [ ] Year-by-year detail view (tap a weather card to see each year individually)
- [ ] Port suggestions/autocomplete from curated cruise port list
- [ ] Map view showing route with weather overlays (Google Maps SDK)
- [ ] Wind/wave data from Open-Meteo Marine API for at-sea conditions
- [ ] Export/share itinerary + weather as image or text
- [ ] Notification: "Weather data available" when a cruise enters forecast range
- [ ] Sea day interpolation (estimate mid-route ocean conditions from adjacent ports)

---

## Project Structure

```
app/
├── build.gradle.kts
├── src/main/
│   ├── AndroidManifest.xml
│   ├── java/org/jewzaam/cruiseweather/
│   │   ├── CruiseWeatherApp.kt              # Application class + Hilt entry point
│   │   ├── MainActivity.kt
│   │   │
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   ├── AppDatabase.kt            # Room database definition
│   │   │   │   ├── CruiseDao.kt
│   │   │   │   ├── PortOfCallDao.kt
│   │   │   │   ├── WeatherDao.kt
│   │   │   │   ├── Converters.kt             # Room type converters (LocalDate, Instant)
│   │   │   │   └── entity/
│   │   │   │       ├── Cruise.kt
│   │   │   │       ├── PortOfCall.kt
│   │   │   │       ├── PortWeatherYear.kt
│   │   │   │       └── PortWeatherSummary.kt
│   │   │   │
│   │   │   ├── remote/
│   │   │   │   ├── OpenMeteoApi.kt           # API interface (geocoding + weather)
│   │   │   │   └── dto/
│   │   │   │       ├── GeocodingResponse.kt  # API response models
│   │   │   │       └── HistoricalWeatherResponse.kt
│   │   │   │       # ForecastResponse.kt — Phase 4 only
│   │   │   │
│   │   │   └── repository/
│   │   │       ├── CruiseRepository.kt
│   │   │       ├── GeocodingRepository.kt
│   │   │       └── WeatherRepository.kt
│   │   │
│   │   ├── domain/
│   │   │   ├── model/
│   │   │   │   ├── CruiseWithPorts.kt        # Cruise + its ports joined
│   │   │   │   ├── PortWithWeather.kt        # Port + weather summary joined
│   │   │   │   ├── GeocodingCandidate.kt     # Geocoding result for UI
│   │   │   │   └── CruiseComparison.kt       # Aggregated stats for comparison
│   │   │   └── usecase/
│   │   │       ├── FetchWeatherForCruiseUseCase.kt
│   │   │       ├── GeocodePortUseCase.kt
│   │   │       └── CompareCruisesUseCase.kt
│   │   │
│   │   ├── ui/
│   │   │   ├── navigation/
│   │   │   │   └── NavGraph.kt               # Compose Navigation routes
│   │   │   ├── theme/
│   │   │   │   ├── Theme.kt                  # Material 3 theme
│   │   │   │   ├── Color.kt
│   │   │   │   └── Type.kt
│   │   │   ├── cruiselist/
│   │   │   │   ├── CruiseListScreen.kt
│   │   │   │   └── CruiseListViewModel.kt
│   │   │   ├── cruiseedit/
│   │   │   │   ├── CruiseEditScreen.kt
│   │   │   │   ├── CruiseEditViewModel.kt
│   │   │   │   └── PortOfCallSheet.kt        # Bottom sheet for add/edit port
│   │   │   ├── cruisedetail/
│   │   │   │   ├── CruiseDetailScreen.kt
│   │   │   │   ├── CruiseDetailViewModel.kt
│   │   │   │   └── WeatherCard.kt            # Single port-day weather card
│   │   │   ├── comparison/
│   │   │   │   ├── ComparisonScreen.kt
│   │   │   │   └── ComparisonViewModel.kt
│   │   │   └── components/
│   │   │       ├── GeocodingConfirmation.kt  # Geocoding candidate selector
│   │   │       ├── WeatherConditionIcon.kt   # Icon derivation from conditions
│   │   │       └── LoadingOverlay.kt
│   │   │
│   │   └── di/
│   │       ├── DatabaseModule.kt             # Hilt module for Room
│   │       └── NetworkModule.kt              # Hilt module for HTTP client
│   │
│   └── res/
│       └── values/
│           └── strings.xml
│
├── gradle/
│   └── libs.versions.toml                    # Version catalog
└── settings.gradle.kts
```

---

## Dependencies (Version Catalog)

```toml
[versions]
kotlin = "2.1.0"
compose-bom = "2025.01.01"  # verify latest stable at build time
hilt = "2.52"
room = "2.7.0"
ktor = "3.0.3"
navigation = "2.8.6"
serialization = "1.7.3"

[libraries]
# Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }

# Room
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }

# Hilt
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }

# Ktor
ktor-client-core = { group = "io.ktor", name = "ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { group = "io.ktor", name = "ktor-client-okhttp", version.ref = "ktor" }
ktor-serialization-json = { group = "io.ktor", name = "ktor-serialization-kotlinx-json", version.ref = "ktor" }
ktor-content-negotiation = { group = "io.ktor", name = "ktor-client-content-negotiation", version.ref = "ktor" }

# Navigation
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }

# Serialization
serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }
```

Note: verify these versions against latest stable at build time. Compose BOM and Room versions move frequently.

---

## API Rate Limiting

Open-Meteo allows 10,000 requests/day for free non-commercial use.

**Budget per cruise weather fetch:**
- Geocoding: 1 call per port needing resolution
- Historical weather: 1 call per port per year sampled (5 years × N ports)
- A cruise with 5 ports of call + departure + return = 7 locations × 5 years = **35 weather calls + 7 geocoding = 42 total**

Plenty of headroom. Implement caching: don't re-fetch weather if summary already exists and data is < 7 days old.

---

## Key Design Decisions

1. **Historical averages over forecasts for planning**: Cruise shoppers are typically comparing options months out. 5-year averages give a reliable baseline. Forecasts only useful within ~2 weeks.

2. **Departure/return ports as Cruise fields, not PortOfCall**: They're structurally different — always exactly one departure, optionally one return. Embedding them on Cruise avoids join complexity and special-casing in the PortOfCall list.

3. **No backend, no sync**: All data local to Room. No user accounts, no cloud. Device loss = data loss. Acceptable for planning-stage data.

4. **Fahrenheit default with toggle**: Primary audience is US cruise market. Support °C via DataStore preference.

5. **Port geocoding with confirmation**: Cruise port names can be ambiguous ("Nassau" → Bahamas vs. Germany). Always present candidates for user selection.

6. **Rain probability derived from historical sample**: 3 of 5 years with >1mm = 60% chance. More intuitive than raw mm for cruise decision-making. Show both in detail view.

---

## Open Questions / Decisions

1. **Historical year depth**: Default 5 years. Worth making configurable? More years = better statistics but more API calls.

5 years is fine

2. **Sea day weather**: Phase 4. For now, "At Sea" days have no weather. Future: estimate mid-route conditions from Open-Meteo Marine API using interpolated coordinates.

No forecase at sea.

3. **Package name**: `org.jewzaam.cruiseweather`

4. **Precipitation threshold for "rainy day"**: Currently >1mm. Should this be configurable, or is 1mm a reasonable universal threshold?

Just report the data, don't make assessments.