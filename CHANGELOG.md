# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-09

### Added

- Menu bar status icon with dynamic badge showing failed/running DAG counts
- DAG list popover with real-time polling via Airflow REST API
- Multi-environment support with per-environment enable/disable
- Basic Auth and Bearer Token authentication methods
- Configurable refresh intervals (1 minute to 30 minutes)
- Search and filter DAGs by ID, tag, owner, and state
- Option to show/hide paused DAGs
- Regex-based DAG filter for granular control
- macOS notifications for DAG failures and recoveries
- Airflow instance health monitoring
- Configuration persistence at `~/.airflowbar/config.json`
