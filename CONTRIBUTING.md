# Contributing to AirflowBar

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork and clone the repository
2. Change into `macos/`
3. Build: `swift build`
4. Run tests: `swift test`

## Development Setup

A local Airflow instance makes development easier:

```bash
cd macos
docker compose up -d
```

This starts Airflow at `http://localhost:8080` with credentials `airflow`/`airflow` and example DAGs loaded.

To tear it down:

```bash
docker-compose down -v
```

## Code Style

- Follow existing conventions in the codebase
- Use Swift concurrency (`async`/`await`, actors) — avoid callbacks
- UI state uses `@Observable` macro
- Keep `AirflowBarCore` free of UI/AppKit dependencies

## Architecture

The project is split into two targets:

- **AirflowBarCore** — models, networking, and configuration (pure Swift, no UI)
- **AirflowBar** — macOS app with SwiftUI views and AppKit integration

This separation keeps the core logic testable and UI-independent.

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Ensure `swift build` and `swift test` pass
4. Update `CHANGELOG.md` under an `[Unreleased]` section
5. Open a PR against `main`

## Reporting Issues

Use [GitHub Issues](https://github.com/maroil/airflow-bar/issues) to report bugs or request features. Include:

- macOS version
- Steps to reproduce
- Expected vs actual behavior
