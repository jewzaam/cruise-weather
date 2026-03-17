# Convenience wrapper around Gradle targets.
# Gradle is authoritative; this Makefile just saves typing.

.PHONY: build test lint check clean itest setup-check release release-bundle distribute emulator-start emulator-wipe deploy-debug deploy-run

build:
	gradlew build

test:
	gradlew test

lint:
	gradlew lint

check: lint test

clean:
	gradlew clean

# Release builds
release:
	gradlew assembleRelease

release-bundle:
	gradlew bundleRelease

# Upload to Firebase App Distribution
distribute:
	gradlew assembleRelease appDistributionUploadRelease

# Instrumented tests — requires connected device or emulator
itest:
	gradlew connectedAndroidTest

# Launch the Android emulator using the first available AVD
emulator-start:
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	AVD=$$("$$SDK_DIR/emulator/emulator" -list-avds 2>/dev/null | head -1); \
	if [ -z "$$AVD" ]; then \
		echo "FAIL: No AVDs found. Create one via Android Studio Device Manager."; exit 1; \
	fi; \
	echo "Starting emulator: $$AVD"; \
	"$$SDK_DIR/emulator/emulator" -avd "$$AVD" -no-snapshot-load &

# Kill existing emulator, wipe data, and restart with fresh state
emulator-wipe:
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	"$$SDK_DIR/platform-tools/adb" kill-server 2>/dev/null; \
	AVD=$$("$$SDK_DIR/emulator/emulator" -list-avds 2>/dev/null | head -1); \
	if [ -z "$$AVD" ]; then \
		echo "FAIL: No AVDs found."; exit 1; \
	fi; \
	echo "Wiping and restarting emulator: $$AVD"; \
	"$$SDK_DIR/emulator/emulator" -avd "$$AVD" -no-snapshot-load -wipe-data &

# Build debug APK and install it on the connected emulator/device
deploy-debug:
	gradlew installDebug

# Build, install, and launch the app on the connected emulator/device
deploy-run: deploy-debug
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	"$$SDK_DIR/platform-tools/adb" shell am start -n org.jewzaam.cruiseweather/.MainActivity

# Validate development environment setup
setup-check:
	@echo "=== Java ==="
	@java -version 2>&1 | head -1 || (echo "FAIL: java not found" && exit 1)
	@JAVA_VER=$$(java -version 2>&1 | head -1 | grep -oP '"(\d+)' | tr -d '"'); \
	if [ "$$JAVA_VER" != "21" ]; then \
		echo "FAIL: Java 21 required, found Java $$JAVA_VER"; exit 1; \
	fi
	@echo "OK"
	@echo ""
	@echo "=== Android SDK ==="
	@if [ -f local.properties ]; then \
		SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
		if [ -d "$$SDK_DIR" ]; then \
			echo "SDK location: $$SDK_DIR"; \
			echo "OK"; \
		else \
			echo "FAIL: sdk.dir in local.properties points to missing directory: $$SDK_DIR"; exit 1; \
		fi; \
	elif [ -n "$$ANDROID_HOME" ]; then \
		if [ -d "$$ANDROID_HOME" ]; then \
			echo "SDK location: $$ANDROID_HOME"; \
			echo "OK"; \
		else \
			echo "FAIL: ANDROID_HOME points to missing directory: $$ANDROID_HOME"; exit 1; \
		fi; \
	else \
		echo "FAIL: No Android SDK configured. Create local.properties with sdk.dir or set ANDROID_HOME"; exit 1; \
	fi
	@echo ""
	@echo "=== Gradle wrapper ==="
	@./gradlew --version 2>&1 | grep -E "^Gradle |^Kotlin" || (echo "FAIL: gradlew not working" && exit 1)
	@echo "OK"
	@echo ""
	@echo "=== SDK Platform (compileSdk 36) ==="
	@if [ -f local.properties ]; then \
		SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	else \
		SDK_DIR="$$ANDROID_HOME"; \
	fi; \
	if ls "$$SDK_DIR/platforms/" 2>/dev/null | grep -q 'android-36'; then \
		echo "OK"; \
	else \
		echo "FAIL: No API 36 platform found in $$SDK_DIR/platforms/"; exit 1; \
	fi
	@echo ""
	@echo "=== Build Tools ==="
	@if [ -f local.properties ]; then \
		SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	else \
		SDK_DIR="$$ANDROID_HOME"; \
	fi; \
	if ls "$$SDK_DIR/build-tools/" 2>/dev/null | head -1 | grep -q .; then \
		echo "OK"; \
	else \
		echo "FAIL: No build-tools found in $$SDK_DIR/build-tools/"; exit 1; \
	fi
	@echo ""
	@echo "=== Emulator AVDs ==="
	@if [ -f local.properties ]; then \
		SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	else \
		SDK_DIR="$$ANDROID_HOME"; \
	fi; \
	EMU="$$SDK_DIR/emulator/emulator"; \
	if [ -x "$$EMU" ]; then \
		AVDS=$$("$$EMU" -list-avds 2>/dev/null); \
		if [ -n "$$AVDS" ]; then \
			echo "$$AVDS"; \
			echo "OK"; \
		else \
			echo "WARN: No AVDs configured. Create one via Android Studio Device Manager or avdmanager."; \
		fi; \
	else \
		echo "WARN: Emulator not installed. Install via SDK Manager if you want to run on an emulator."; \
	fi
	@echo ""
	@echo "=== All checks passed ==="
