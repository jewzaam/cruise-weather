# Getting Started

Setup guide for building and running `cruise-weather` locally on Windows.

## Prerequisites

| Tool | Version | Verify |
|---|---|---|
| Java (JDK) | 21 | `java -version` |
| Android SDK | API 36 platform (compileSdk) | `sdkmanager --list` or Android Studio SDK Manager |
| Git | any | `git --version` |

> **Gradle** is handled by the Gradle wrapper (`gradlew` / `gradlew.bat`). You do not need a system-wide Gradle install.

## Step 1 — Install JDK 21

If not already installed, download JDK 21 from [Oracle](https://www.oracle.com/java/technologies/downloads/#java21) or [Adoptium](https://adoptium.net/).

Verify:

```bash
java -version
# Expected: java version "21.x.x"
```

## Step 2 — Install the Android SDK

### Option A: Android Studio (recommended)

1. Download and install [Android Studio](https://developer.android.com/studio).
2. During first launch, the setup wizard installs the SDK (default location: `C:\Users\<you>\AppData\Local\Android\Sdk`).
3. From the Welcome screen, click **Customize** in the left sidebar, then **All settings...** at the bottom. Navigate to **Languages & Frameworks > Android SDK**.

   > **Shortcut**: Click the gear icon in the bottom-left of the Welcome screen and select **SDK Manager** to go there directly.

   **SDK Platforms** tab — install the platform matching `compileSdk` in `app/build.gradle.kts`:
   - Any **API 36** variant (e.g. Android 16.0 "Baklava" 36.1) — needed to compile the project

   That's it. You do **not** need to install API 33, 34, or 35 just to build. The `minSdk = 33` setting only controls which devices can run the app — it doesn't require that SDK platform to be installed. If you want to run an emulator at a specific API level, install that platform then.

   **SDK Tools** tab — ensure these are installed:
   - Android SDK Build-Tools (required to compile)
   - Android SDK Platform-Tools (required for `adb` and device communication)
   - Android Emulator (required only if running on an emulator instead of a physical device)

   Once you've verified the platforms and tools are installed, close the SDK Manager dialog and close Android Studio. You do not need Android Studio open to build or run the project — everything is done from the command line with `gradlew`.

### Option B: Command-line tools only

1. Download "Command line tools only" from [developer.android.com/studio#command-line-tools-only](https://developer.android.com/studio#command-line-tools-only).
2. Extract to a permanent location, e.g. `C:\Android\cmdline-tools\latest\`.
3. Add `C:\Android\cmdline-tools\latest\bin` to your `PATH`.
4. Install required SDK components:

```bash
sdkmanager "platforms;android-36" "build-tools;36.0.0" "platform-tools"
```

## Step 3 — Configure the Android SDK location

The project needs to know where the SDK is. Do **one** of the following:

### Option A: `local.properties` (per-project, recommended)

Create a file called `local.properties` in the project root:

```properties
sdk.dir=C\:\\Users\\<you>\\AppData\\Local\\Android\\Sdk
```

> Replace `<you>` with your Windows username. Use double backslashes or forward slashes.

This file is git-ignored and does not get committed.

### Option B: Environment variable (system-wide)

Set the `ANDROID_HOME` environment variable:

```
ANDROID_HOME=C:\Users\<you>\AppData\Local\Android\Sdk
```

On Windows, set this via **System Properties > Environment Variables** or in your shell profile.

## Step 4 — Validate your setup

```bash
make setup-check
```

This checks Java version, Android SDK location, Gradle wrapper, and runs a compile. If anything is missing or misconfigured it tells you what's wrong.

## Step 5 — Build the project


```bash
./gradlew build
```

This compiles the app, runs lint, and executes JVM unit tests. First run downloads dependencies and may take several minutes.

### Common build tasks

| Task | Command |
|---|---|
| Build (compile + lint + unit tests) | `./gradlew build` |
| Unit tests only (JVM, fast) | `./gradlew test` |
| Instrumented tests (requires device/emulator) | `./gradlew connectedAndroidTest` |
| Lint only | `./gradlew lint` |
| Clean | `./gradlew clean` |
| Install debug APK | `./gradlew installDebug` |

## Step 6 — Run the app

### On a physical device

1. Enable **Developer Options** and **USB Debugging** on your Android device.
2. Connect via USB.
3. Run:

```bash
./gradlew installDebug
```

### On an emulator

1. If using Android Studio: **Tools > Device Manager > Create Virtual Device** (API 33+).
2. If using command-line tools:

```bash
sdkmanager "system-images;android-33;google_apis;x86_64" "emulator"
avdmanager create avd -n test_device -k "system-images;android-33;google_apis;x86_64"
emulator -avd test_device
```

3. Once the emulator is running:

```bash
./gradlew installDebug
```

## Step 7 — Run instrumented tests

Instrumented tests (`src/androidTest/`) require a connected device or running emulator:

```bash
./gradlew connectedAndroidTest
```

## Step 8 — Firebase Setup (optional, for release builds)

Firebase App Distribution and Crashlytics are used for beta distribution and crash reporting. Skip this step if you only need debug builds.

### 8a — Create Firebase project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Create a project named `cruise-weather`.
3. Add an Android app with package name `org.jewzaam.cruiseweather`.
4. Enable **App Distribution** and **Crashlytics** in the Firebase Console.
5. Download `google-services.json` and place it in `app/`.

> `app/google-services.json` is git-ignored and must not be committed.

### 8b — Generate a release signing key

```bash
keytool -genkey -v -keystore cruise-weather-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cruise-weather
```

Store the `.jks` file somewhere safe outside the repository.

### 8c — Create `keystore.properties`

Create `keystore.properties` in the project root:

```properties
storeFile=../path/to/cruise-weather-release.jks
storePassword=your_store_password
keyAlias=cruise-weather
keyPassword=your_key_password
```

> `keystore.properties` is git-ignored and must not be committed.

### 8d — Install Firebase CLI

1. Install the Firebase CLI: [firebase.google.com/docs/cli](https://firebase.google.com/docs/cli)
2. Authenticate:

```bash
firebase login
```

### 8e — Build and distribute

| Task | Command |
|---|---|
| Signed release APK | `make release` |
| Signed release bundle (AAB) | `make release-bundle` |
| Build + upload to Firebase App Distribution | `make distribute` |

The release APK is output to `app/build/outputs/apk/release/`.

## Troubleshooting

### `SDK location not found`

Create `local.properties` or set `ANDROID_HOME` as described in Step 3.

### `The supplied javaHome seems to be invalid`

A Gradle daemon may have cached a different JDK. Stop all daemons and retry:

```bash
./gradlew --stop
./gradlew build
```

If that doesn't help, check that no `org.gradle.java.home` is set in `~/.gradle/gradle.properties` pointing to a wrong JDK.

### `Could not resolve` dependency errors

Ensure you have internet access. Gradle downloads dependencies from Maven Central and Google's Maven repository on first build.

### Emulator won't start / HAXM errors

Enable hardware virtualization (VT-x / AMD-V) in your BIOS/UEFI settings. On Windows, also ensure **Windows Hypervisor Platform** is enabled in Windows Features.

## Project structure

See [PLAN.md](PLAN.md) for architecture details and [standards/](standards/) for coding conventions.
