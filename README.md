# Performance Testing Project - JMeter

A comprehensive performance testing framework built with Apache JMeter following industry best practices.

## Project Structure

```
ActiveCleaners-Performance-Test/
├── jmeter/
│   ├── config/                 # Configuration files
│   │   ├── user.properties     # JMeter user settings
│   │   ├── system.properties   # System-level settings
│   │   └── test-config.properties # Test-specific configurations
│   ├── data/                   # Test data files
│   │   ├── users.csv           # User test data
│   │   └── pagination.csv      # Pagination test data
│   ├── fragments/              # Reusable test fragments
│   │   ├── reqres-api-fragment.jmx
│   │   └── assertions-fragment.jmx
│   ├── test-plans/             # Main test plans
│   │   ├── smoke-test.jmx      # Quick validation
│   │   ├── load-test.jmx       # Normal load simulation
│   │   ├── stress-test.jmx     # Beyond normal load
│   │   ├── spike-test.jmx      # Sudden surge testing
│   │   └── first-test.jmx      # Original test plan
│   └── results/                # Test results
│       ├── jtl/                # Raw results (JTL files)
│       └── html/               # HTML reports
└── scripts/                    # Execution scripts
    ├── run-test.bat/.sh        # Main test runner
    ├── generate-report.bat/.sh # Report generator
    └── validate-tests.bat/.sh  # Test validator
```

## Prerequisites

- Apache JMeter 5.6+ installed
- Java 8+ installed
- `JMETER_HOME` environment variable set

### Setting JMETER_HOME

**Windows:**
```cmd
set JMETER_HOME=C:\apache-jmeter-5.6.3
```

**Linux/Mac:**
```bash
export JMETER_HOME=/opt/apache-jmeter-5.6.3
```

## Test Types

### 1. Smoke Test
Quick validation to ensure critical endpoints are working.

| Parameter | Value |
|-----------|-------|
| Users | 1 |
| Ramp-up | 1s |
| Duration | Quick validation |
| Think Time | 500-1000ms |

### 2. Load Test
Simulates normal expected load on the system.

| Parameter | Value |
|-----------|-------|
| Users | 50 (configurable) |
| Ramp-up | 60s |
| Iterations | 10 per user |
| Think Time | 1000-3000ms |

### 3. Stress Test
Pushes the system beyond normal load to find breaking points.

| Phase | Users | Ramp-up | Iterations |
|-------|-------|---------|------------|
| Phase 1 | 50 | 60s | 3 |
| Phase 2 | 100 | 30s | 5 |
| Phase 3 | 200 | 60s | 5 |

### 4. Spike Test
Simulates sudden surge in traffic.

| Phase | Users | Ramp-up |
|-------|-------|---------|
| Baseline | 10 | 5s |
| Spike | 500 | 10s |
| Recovery | 10 | 5s |

## Running Tests

### Using Scripts

**Windows:**
```cmd
cd scripts
run-test.bat smoke
run-test.bat load
run-test.bat stress
run-test.bat spike
run-test.bat all
```

**Linux/Mac:**
```bash
cd scripts
chmod +x *.sh
./run-test.sh smoke
./run-test.sh load
./run-test.sh stress
./run-test.sh spike
./run-test.sh all
```

### Using JMeter GUI (Development Only)

```cmd
%JMETER_HOME%\bin\jmeter.bat -t jmeter/test-plans/smoke-test.jmx
```

### Using Command Line (Production)

```cmd
%JMETER_HOME%\bin\jmeter.bat -n -t jmeter/test-plans/load-test.jmx -l jmeter/results/jtl/load-test-results.jtl -q jmeter/config/test-config.properties
```

## Configuration

### Test Configuration (test-config.properties)

| Property | Description | Default |
|----------|-------------|---------|
| BASE_URL | API base URL | https://reqres.in |
| SMOKE_USERS | Smoke test users | 1 |
| LOAD_USERS | Load test users | 50 |
| LOAD_RAMPUP | Load test ramp-up (seconds) | 60 |
| STRESS_USERS | Stress test max users | 200 |
| SPIKE_USERS | Spike test peak users | 500 |
| THINK_TIME_MIN | Min think time (ms) | 1000 |
| THINK_TIME_MAX | Max think time (ms) | 3000 |
| P99_THRESHOLD | P99 response time threshold | 2000ms |
| ERROR_RATE_THRESHOLD | Max error rate % | 5% |

### Passing Properties at Runtime

```cmd
jmeter -n -t test-plans/load-test.jmx -JLOAD_USERS=100 -JLOAD_RAMPUP=120
```

## Test Data

### users.csv
Contains user data for parameterized tests:
- userId, userName, job, email, password

### pagination.csv
Contains pagination parameters:
- page, delay

## Generating Reports

### Automatic (after test run)
Reports are automatically generated after each test run.

### Manual Report Generation

**Windows:**
```cmd
scripts\generate-report.bat jmeter\results\jtl\load-test-results.jtl
```

**Linux/Mac:**
```bash
./scripts/generate-report.sh jmeter/results/jtl/load-test-results.jtl
```

## Report Metrics

The HTML dashboard includes:

- **Statistics**: Min, Max, Mean, Median, P90, P95, P99
- **Errors**: Error count and percentage by type
- **Throughput**: Requests per second
- **Response Time**: Distribution and percentiles
- **Threads**: Active users over time
- **Charts**: Visual representation of all metrics

## API Endpoints Tested

### ReqRes API (https://reqres.in)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/users | List users |
| GET | /api/users/{id} | Get single user |
| POST | /api/users | Create user |
| PUT | /api/users/{id} | Update user |
| DELETE | /api/users/{id} | Delete user |
| POST | /api/login | User login |

### ActiveCleaners API
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /app/Dashboard | Dashboard data |

## Best Practices Implemented

1. **Parameterization**: CSV data files for test data
2. **Configuration Management**: External properties files
3. **Think Time**: Random think time between requests
4. **Assertions**: Response code, JSON path, duration assertions
5. **Modular Design**: Reusable test fragments
6. **Reporting**: Automatic HTML report generation
7. **Logging**: Separate log files per test
8. **Environment Variables**: Configurable base URLs and thresholds
9. **Thread Groups**: Proper ramp-up and iteration settings
10. **Headers**: Centralized header management

## Validating Tests

Run validation to check test plans without executing:

**Windows:**
```cmd
scripts\validate-tests.bat
```

**Linux/Mac:**
```bash
./scripts/validate-tests.sh
```

## Interpreting Results

### Key Metrics to Monitor

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Error Rate | < 1% | 1-5% | > 5% |
| P95 Response Time | < 500ms | 500-1000ms | > 1000ms |
| P99 Response Time | < 1000ms | 1000-2000ms | > 2000ms |
| Throughput | High | Medium | Low |

### Common Issues

1. **High Response Times**: Check server resources, database queries
2. **High Error Rate**: Check assertions, server logs, rate limiting
3. **Low Throughput**: Check think time, network bandwidth
4. **Memory Issues**: Reduce concurrent users, use distributed testing

## CI/CD Integration

### Jenkins Pipeline Example

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
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
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

### GitHub Actions Example

```yaml
name: Performance Tests
on: [push, pull_request]
jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup JMeter
        run: |
          wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.tgz
          tar -xzf apache-jmeter-5.6.3.tgz
          echo "JMETER_HOME=$PWD/apache-jmeter-5.6.3" >> $GITHUB_ENV
      - name: Run Smoke Test
        run: ./scripts/run-test.sh smoke
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: jmeter-results
          path: jmeter/results/
```

## Troubleshooting

### Common Errors

1. **JMETER_HOME not set**
   - Set the environment variable to your JMeter installation

2. **Out of Memory**
   - Increase JVM heap: `set JVM_ARGS=-Xms512m -Xmx2048m`

3. **Connection Refused**
   - Check target server is running
   - Verify BASE_URL configuration

4. **High Error Rate**
   - Check API rate limits
   - Verify assertions are correct

## Contributing

1. Create test plans in `jmeter/test-plans/`
2. Add test data to `jmeter/data/`
3. Update configurations in `jmeter/config/`
4. Document changes in README

## License

This project is for testing and educational purposes.
