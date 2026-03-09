# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-09

Initial public release.

### Added

- Menu bar status icon with dynamic badge showing failed/running DAG counts
- DAG list popover with real-time polling via Airflow REST API (v1 and v2 auto-detection)
- Multi-environment support with per-environment enable/disable
- Basic Auth and Bearer Token authentication
- Configurable refresh intervals (10 seconds to 30 minutes) with exponential backoff
- Search and filter DAGs by ID, tag, owner, and state
- Regex-based DAG filter for granular control
- Option to show/hide paused DAGs
- macOS notifications for DAG failures and recoveries
- Airflow instance health monitoring
- Automatic update checker — checks GitHub releases daily and shows in-app notification
- Screenshot mode (`--screenshot` flag) for generating documentation assets
- AES-GCM encrypted credential storage via CryptoKit (`~/.airflowbar/credentials.enc`)
- Homebrew cask for easy installation (`brew install maroil/airflow-bar/airflow-bar`)
- DMG installer with custom background and app icon
- CI workflow (build + test on push/PR) and release automation (DMG + GitHub Release + cask update)
- Astro-based landing page

### Fixed

- Fix a startup crash in bundled `.app` releases caused by requesting notification authorization from the wrong execution context
