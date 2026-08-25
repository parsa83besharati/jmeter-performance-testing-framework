# JMeter Performance Testing Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![JMeter](https://img.shields.io/badge/JMeter-5.6.3-blue.svg)](https://jmeter.apache.org/)
[![Java](https://img.shields.io/badge/Java-8%2B-orange.svg)](https://www.java.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

A production-ready, modular performance testing framework built with Apache JMeter. Designed for CI/CD integration with automated validation, threshold enforcement, and distributed testing support.

---

## Key Features

- **Modular Architecture** - Single source of truth via `IncludeController` eliminates duplication
- **5 Test Types** - Smoke, Load, Stress, Spike, and Soak tests
- **Automated Validation** - Post-test threshold checking (P95, P99, error rate)
- **CI/CD Ready** - GitHub Actions workflow with gated test execution
- **Docker Support** - Containerized execution with distributed testing
- **Cross-Platform** - Full Windows and Linux/Mac support
- **Result Comparison** - Regression detection between baseline and current runs

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Test Plans                               │
├──────────┬──────────┬──────────┬──────────┬──────────┤
│  Smoke   │   Load   │  Stress  │  Spike   │   Soak   │
│  (1u)    │  (50u)   │ (50-200) │ (500u)   │  (20u)   │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘
     │          │          │          │          │
     └──────────┴──────────┴──────────┴──────────┘
                           │
                    IncludeController
                           │
                           ▼
              ┌────────────────────────┐
              │  reqres-api-samplers   │
              │  ├── GET /users        │
              │  ├── GET /users/{id}   │
              │  ├── POST /users       │
              │  ├── PUT /users/{id}   │
              │  └── DELETE /users/{id}│
              └────────────────────────┘
```

### Why This Matters

| Before (Duplicated) | After (Modular) |
|---------------------|-----------------|
| Same samplers in 4+ files | Single fragment file |
| Change = edit 4 files | Change = edit 1 file |
| Inconsistent assertions | Consistent across all tests |
| High maintenance cost | Low maintenance cost |

---

## Project Structure

```
jmeter-performance-testing-framework/
├── jmeter/
│   ├── config/
│   │   ├── test-config.properties  # Tunable test parameters
│   │   ├── user.properties         # JMeter save/service settings
│   │   └── system.properties       # System-level settings
│   ├── data/
│   │   ├── users.csv               # User test data (20 records)
│   │   └── pagination.csv          # Pagination data (10 records)
│   ├── fragments/
│   │   ├── reqres-api-samplers.jmx # All API samplers + assertions
│   │   └── health-check.jmx        # Pre-test health check
│   ├── test-plans/
│   │   ├── smoke-test.jmx
│   │   ├── load-test.jmx
│   │   ├── stress-test.jmx
│   │   ├── spike-test.jmx
│   │   └── soak-test.jmx
│   └── results/
│       ├── jtl/                    # Raw JTL results
│       └── html/                   # HTML dashboards
├── scripts/
│   ├── run-test.bat/.sh           # Test executor
│   ├── validate-tests.bat/.sh     # Plan syntax validator
│   ├── validate-results.bat/.sh   # Threshold enforcer
│   ├── compare-results.bat/.sh    # Regression detector
│   ├── generate-report.bat/.sh    # HTML report generator
│   └── docker-run.sh              # Docker entrypoint
├── .github/
│   └── workflows/
│       └── performance-tests.yml  # CI/CD pipeline
├── Dockerfile
├── docker-compose.yml
├── LICENSE
└── README.md
```

---

## Quick Start

### Prerequisites

- Apache JMeter 5.6+
- Java 8+
- Docker (optional)

### Setup

```bash
# Clone the repository
git clone https://github.com/pouya-besharati/jmeter-performance-testing-framework.git
cd jmeter-performance-testing-framework

# Set JMeter home (Linux/Mac)
export JMETER_HOME=/opt/apache-jmeter-5.6.3

# Set JMeter home (Windows)
set JMETER_HOME=C:\apache-jmeter-5.6.3
```

### Run Your First Test

```bash
# Run smoke test (takes ~10 seconds)
./scripts/run-test.sh smoke

# Run load test
./scripts/run-test.sh load

# Run all tests
./scripts/run-test.sh all
```

---

## Test Types

| Test | Threads | Ramp-up | Iterations | Think Time | Purpose |
|------|---------|---------|------------|------------|---------|
| **Smoke** | 1 | 1s | 1 | 500-1000ms | Quick endpoint validation |
| **Load** | 50* | 60s* | 10* | 1000-3000ms | Normal expected load |
| **Stress** | 50→100→200 | 60/30/60s | 3/5/5 | 500-1500ms | Find breaking point |
| **Spike** | 10→500→10 | 5/10/5s | 10/3/10 | 100-500ms | Sudden surge resilience |
| **Soak** | 20* | 30s* | ∞ (1hr) | 1000-3000ms | Memory leak detection |

*\* Configurable via `test-config.properties`*

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JMETER_HOME` | JMeter installation path | *Required* |
| `BASE_URL` | Target API URL | `https://reqres.in` |
| `API_KEY` | API authentication key | `reqres-free-v1` |

### Test Parameters (test-config.properties)

| Property | Description | Default |
|----------|-------------|---------|
| `LOAD_USERS` | Concurrent users for load test | 50 |
| `LOAD_RAMPUP` | Ramp-up period (seconds) | 60 |
| `LOAD_ITERATIONS` | Iterations per user | 10 |
| `STRESS_USERS` | Max users for stress test | 200 |
| `SPIKE_USERS` | Peak users for spike test | 500 |
| `SOAK_USERS` | Concurrent users for soak test | 20 |
| `SOAK_DURATION` | Soak test duration (seconds) | 3600 |
| `THINK_TIME_MIN` | Minimum think time (ms) | 1000 |
| `THINK_TIME_MAX` | Maximum think time (ms) | 3000 |
| `P95_THRESHOLD` | P99 response time limit (ms) | 1000 |
| `P99_THRESHOLD` | P99 response time limit (ms) | 2000 |
| `ERROR_RATE_THRESHOLD` | Max error rate (%) | 5 |

### Runtime Override

```bash
# Override at runtime
./scripts/run-test.sh load  # Uses default config

# Or pass properties directly
$JMETER_HOME/bin/jmeter -n \
  -t jmeter/test-plans/load-test.jmx \
  -JLOAD_USERS=100 \
  -JLOAD_RAMPUP=120 \
  -JBASE_URL=https://staging.example.com
```

---

## API Endpoints

| Method | Endpoint | Description | Expected |
|--------|----------|-------------|----------|
| `GET` | `/api/users?page={page}` | List users with pagination | 200 |
| `GET` | `/api/users/{id}` | Get single user | 200 |
| `POST` | `/api/users` | Create new user | 201 |
| `PUT` | `/api/users/{id}` | Update existing user | 200 |
| `DELETE` | `/api/users/{id}` | Delete user | 204 |

---

## Result Validation

Results are automatically validated against configured thresholds after each test run.

### Manual Validation

```bash
# Validate a specific JTL file
./scripts/validate-results.sh jmeter/results/jtl/load-test.jtl 1000 2000 5

# Arguments: <jtl-file> <p95-threshold> <p99-threshold> <error-rate-threshold>
```

### Compare Results

```bash
# Compare baseline vs current
./scripts/compare-results.sh baseline.jtl current.jtl
```

### Threshold Matrix

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Error Rate | < 1% | 1-5% | > 5% |
| P95 Response | < 500ms | 500-1000ms | > 1000ms |
| P99 Response | < 1000ms | 1000-2000ms | > 2000ms |

---

## Docker

### Single Node

```bash
# Build image
docker build -t jmeter-framework .

# Run smoke test
docker run --rm -v $(pwd)/jmeter/results:/jmeter/jmeter/results \
  jmeter-framework smoke
```

### Distributed Testing

```bash
# Start 2 slave nodes
docker-compose up -d jmeter-slave-1 jmeter-slave-2

# Run distributed load test
docker-compose run --rm jmeter-master

# Stop all
docker-compose down
```

---

## CI/CD Integration

### GitHub Actions

The included workflow (`.github/workflows/performance-tests.yml`) provides:

- **Gated execution**: Smoke → Load → Stress
- **Automatic validation**: Threshold checks after each test
- **Artifact storage**: Results retained for 30 days
- **Manual trigger**: Select test type via workflow dispatch

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Performance Test') {
            steps {
                sh './scripts/run-test.sh load'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'jmeter/results/**/*'
                    publishHTML(target: [
                        reportDir: 'jmeter/results/html',
                        reportFiles: 'index.html',
                        reportName: 'Performance Report'
                    ])
                }
            }
        }
    }
}
```

---

## Adding New Test Plans

1. Create a new JMX file in `jmeter/test-plans/`
2. Use `IncludeController` to reference the API fragment:

```xml
<IncludeController guiclass="TestFragmentGui" testclass="IncludeController">
  <stringProp name="IncludeController.filename">../fragments/reqres-api-samplers.jmx</stringProp>
</IncludeController>
```

3. Configure thread groups and loop controllers
4. Add a `ResultCollector` for JTL output
5. Update `run-test.sh/bat` to support the new test type

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

**Parsa Besharati** - Software QA Engineer

---

## Acknowledgments

- [Apache JMeter](https://jmeter.apache.org/) - The foundation of this framework
- [ReqRes API](https://reqres.in/) - Mock API for testing
