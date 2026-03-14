# README Format Standards

## Required Structure

Every README must contain these sections in order:

1. **Title** — App name
2. **Badges** — Build status, coverage, license, min SDK
3. **Description** — 1-3 sentence summary of what the app does
4. **Screenshots** — At least one screen (or mockup during development)
5. **Features** — Bulleted list of key capabilities
6. **Setup** — How to build and run locally
7. **Architecture** — Brief description of tech stack with link to PLAN.md
8. **License** — Apache 2.0 boilerplate

## Badge Line

```markdown
![Build](https://github.com/jewzaam/cruise-weather/actions/workflows/build.yml/badge.svg)
![Coverage](https://img.shields.io/badge/coverage-80%25-brightgreen)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Min SDK](https://img.shields.io/badge/minSdk-33-green)
```

## What Not to Put in README

- Step-by-step implementation details (use PLAN.md)
- Testing rationale (use TEST_PLAN.md)
- Standards documentation (use standards/)
