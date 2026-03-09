# AirflowBar

A macOS menu bar app for monitoring Apache Airflow DAGs.

[![CI](https://github.com/maroil/airflow-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/maroil/airflow-bar/actions/workflows/ci.yml)

## Features

- **Menu bar status icon** with dynamic badge showing failed/running DAG counts
- **Real-time DAG monitoring** via Airflow REST API polling
- **Multi-environment support** — manage multiple Airflow instances, enable/disable each
- **Authentication** — Basic Auth and Bearer Token
- **Configurable refresh** — intervals from 1 minute to 30 minutes
- **Search & filter** — by DAG ID, tag, owner, or state
- **Show/hide paused DAGs** and regex-based DAG filtering
- **macOS notifications** for DAG failures and recoveries
- **Health monitoring** — track Airflow instance availability

## Requirements

- macOS 14+ (Sonoma)
- Swift 6.0+

## Installation

### Download

Download `AirflowBar.app` from the [GitHub Releases page](https://github.com/maroil/airflow-bar/releases) once a public build is published.

> **Note**: The initial OSS release is intentionally unsigned and not notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper.

### Build from Source

```bash
git clone https://github.com/maroil/airflow-bar.git
cd airflow-bar/macos
swift build -c release
```

The binary will be at `.build/release/AirflowBar`.

## Configuration

On first launch, the settings window opens automatically. Configure your Airflow environments with:

- **URL** — base URL of your Airflow webserver (e.g., `http://localhost:8080`)
- **Authentication** — Basic Auth (username/password) or Bearer Token
- **Refresh interval** — how often to poll (1m, 2m, 5m, 10m, 15m, 30m)
- **DAG filtering** — regex pattern, show/hide paused DAGs
- **Notifications** — toggle alerts for failures and recoveries

Configuration is stored at `~/.airflowbar/config.json`.

> **Security**: Environment metadata is stored in `~/.airflowbar/config.json`. Credentials are stored separately in the macOS Keychain.

## Development

### Build & Test

```bash
git clone https://github.com/maroil/airflow-bar.git
cd airflow-bar/macos
swift build
swift test
```

Or use the Makefile:

```bash
cd macos
make build
make test
```

### Local Airflow

A `docker-compose.yaml` is included for local development:

```bash
cd macos
docker compose up -d
```

This starts Airflow with example DAGs at `http://localhost:8080` (credentials: `airflow`/`airflow`).

### Project Structure

```text
macos/
├── Sources/
│   ├── AirflowBar/           # macOS app (SwiftUI + AppKit)
│   └── AirflowBarCore/       # Core library
├── Tests/
│   └── AirflowBarCoreTests/  # Unit tests
└── docker-compose.yaml       # Local Airflow stack

website/
└── src/                      # Landing page
```

## License

[MIT](LICENSE)
