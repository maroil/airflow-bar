# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AirflowBar is a native macOS menu bar app (Swift 6, macOS 14+) for monitoring Apache Airflow DAGs. No external dependencies — pure Swift using Foundation, CryptoKit, AppKit, SwiftUI.

## Build & Test Commands

All commands run from `macos/` directory:

```bash
make build          # swift build
make test           # swift test
make run            # swift run AirflowBar
make release        # Release build
make app            # Create .app bundle
make dmg VERSION=x.y.z  # Create DMG installer

# Run a single test suite
cd macos && swift test --filter ConfigStoreTests

# Local Airflow for development (Docker required)
make airflow-up     # http://localhost:8080 (airflow/airflow)
make airflow-down
```

Website (`website/` directory): `npm ci && npm run build` (Astro, Node 22)

## Architecture

Two-target SPM structure in `macos/Package.swift`:

- **AirflowBarCore** (library) — Pure Swift, no UI imports. Contains models, networking, config. This is where all testable logic lives.
- **AirflowBar** (executable) — SwiftUI views + AppKit integration. Depends on AirflowBarCore.

Key rule: **never import AppKit/SwiftUI in AirflowBarCore**.

### Core Components

- **AppDelegate** — Entry point. Initializes ConfigStore, ViewModels, StatusItemController. Manages popover and settings windows.
- **DAGStatusViewModel** (`@Observable`, `@MainActor`) — Central state hub. Polling orchestration with exponential backoff, concurrent multi-environment fetching via TaskGroup, notification tracking, DAG filtering (regex + search + state).
- **StatusItemController** — NSStatusBar icon, dynamic badge (failed/running counts), popover management.
- **ConfigStore** (`@Observable`) — Loads/saves `~/.airflowbar/config.json`. Hydrates credentials from KeychainService. Runs versioned config migrations.
- **KeychainService** — AES-GCM encryption via CryptoKit. Stores credentials at `~/.airflowbar/credentials.enc`. Uses file-based encryption instead of macOS Keychain to avoid prompts in unsigned builds.
- **AirflowAPIClient** (actor) — Auto-detects Airflow API v1 vs v2, paginated DAG fetching, concurrent requests.

### Concurrency Patterns

- Actors for thread safety (AirflowAPIClient, ConfigStore internals)
- `async`/`await` everywhere — no completion handlers
- TaskGroups for concurrent multi-environment fetches
- `@MainActor` for all UI state

### Tests

Swift Testing framework (`@Suite`, `@Test` macros) — not XCTest. All tests in `macos/Tests/AirflowBarCoreTests/`.

## Other Directories

- `website/` — Astro landing page
- `Casks/` — Homebrew cask formula
- `.github/workflows/` — CI (build+test on push/PR) and Release (DMG + GitHub Release + cask update on version tags)
