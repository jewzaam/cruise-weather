# Convenience wrapper around Gradle targets.
# Gradle is authoritative; this Makefile just saves typing.

.PHONY: help build test lint check clean itest setup-check release release-bundle distribute emulator-start emulator-stop emulator-wipe deploy-debug deploy-run

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

build: ## Build the project
	gradlew build

test: ## Run JVM unit tests
	gradlew test

lint: ## Run Android lint
	gradlew lint

check: lint test ## Run lint + test

clean: ## Clean build outputs
	gradlew clean

release: ## Build release APK
	gradlew assembleRelease

release-bundle: ## Build release AAB
	gradlew bundleRelease

distribute: ## Build and upload to Firebase App Distribution
	gradlew assembleRelease appDistributionUploadRelease

itest: ## Run instrumented tests - requires device/emulator
	gradlew connectedAndroidTest

emulator-start: ## Launch the Android emulator
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	AVD=$$("$$SDK_DIR/emulator/emulator" -list-avds 2>/dev/null | head -1); \
	if [ -z "$$AVD" ]; then \
		echo "FAIL: No AVDs found. Create one via Android Studio Device Manager."; exit 1; \
	fi; \
	echo "Starting emulator: $$AVD"; \
	"$$SDK_DIR/emulator/emulator" -avd "$$AVD" -no-snapshot-load &

emulator-stop: ## Kill the running emulator
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	"$$SDK_DIR/platform-tools/adb" emu kill 2>/dev/null || true

emulator-wipe: ## Wipe emulator data and restart fresh
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	"$$SDK_DIR/platform-tools/adb" kill-server 2>/dev/null; \
	AVD=$$("$$SDK_DIR/emulator/emulator" -list-avds 2>/dev/null | head -1); \
	if [ -z "$$AVD" ]; then \
		echo "FAIL: No AVDs found."; exit 1; \
	fi; \
	echo "Wiping and restarting emulator: $$AVD"; \
	"$$SDK_DIR/emulator/emulator" -avd "$$AVD" -no-snapshot-load -wipe-data &

deploy-debug: ## Build and install debug APK on device/emulator
	gradlew installDebug

deploy-run: deploy-debug ## Build, install, and launch app on device/emulator
	@SDK_DIR=$$(grep '^sdk.dir' local.properties | sed 's/sdk.dir=//;s/\\\\//g;s/\\:/:/g'); \
	"$$SDK_DIR/platform-tools/adb" shell am start -n org.jewzaam.cruiseweather/.MainActivity

setup-check: ## Validate development environment
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
