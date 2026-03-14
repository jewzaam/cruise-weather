# Project Instructions

## Build System

- **Use `make` targets**, not `./gradlew` directly. The Makefile wraps Gradle and is the project's CLI interface.
- Available targets: `build`, `test`, `lint`, `check`, `clean`, `itest`, `setup-check`
- If a make target doesn't exist for what you need, add one to the Makefile rather than running Gradle directly.

## Working with the User

- **Do not search the filesystem speculatively.** Use `ls`, `find`, or glob only when you already know what you're looking for or the user has told you where to look.
- **Do not run commands that will trigger approval prompts** when you can avoid it. If a dedicated tool (Read, Glob, Grep, Edit) can do the job, use it instead of Bash.
- **Verify your own output.** If you write documentation, re-read it and check that every statement is accurate before presenting it. Getting it wrong the first time and iterating through corrections wastes time.
- **Do not assume paths, versions, or tool names.** Check first, then act. If you don't know, ask — don't guess.

## Android Development

- SDK configuration lives in `local.properties` (git-ignored).
- `make setup-check` validates the development environment.
- Instrumented tests (`make itest`) require a connected device or emulator.
- JVM unit tests (`make test`) run without a device.
