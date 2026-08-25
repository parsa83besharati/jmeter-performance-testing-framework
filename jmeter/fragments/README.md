# Load Patterns Library

This directory contains reusable JMeter load pattern fragments. Include them in your test plans using `IncludeController`.

## Available Patterns

### 1. Step Load Pattern (`step-load-pattern.jmx`)

Gradually increases users in steps. Best for finding the exact threshold where performance degrades.

```
Users
  │
  │    ┌────────┐
  │    │        │
  │  ┌─┘        │
  │  │          │
  ├──┘          └──
  └──────────────── Time
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `USERS_START` | 10 | Starting number of users |
| `STEP_SIZE` | 10 | Users added per step |
| `STEP_INTERVAL` | 60 | Seconds between steps |
| `USERS_MAX` | 100 | Maximum users |

**Example:**
```bash
jmeter -n -t test.jmx -JUSERS_START=10 -JSTEP_SIZE=10 -JSTEP_INTERVAL=60 -JUSERS_MAX=200
```

---

### 2. Ramp-Over-Time Pattern (`ramp-over-time-pattern.jmx`)

Classic linear ramp-up over a specified duration. Best for simulating realistic user onboarding.

```
Users
  │
  │              /
  │            /
  │          /
  │        /
  │      /
  │    /
  │  /
  │/
  └──────────────── Time
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `USERS` | 50 | Target number of concurrent users |
| `RAMPUP_DURATION` | 300 | Ramp-up duration in seconds |

---

### 3. Constant Arrival Rate Pattern (`constant-arrival-pattern.jmx`)

Maintains a fixed number of requests per second regardless of response time. Best for throughput testing.

```
Requests/sec
  │
  │──────────────────
  │
  └──────────────── Time
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `THREADS` | 10 | Concurrent threads |
| `TARGET_RPS` | 50 | Target requests per second |
| `INTER_ARRIVAL_MS` | 20 | Milliseconds between requests |

---

### 4. Peak Load Pattern (`peak-load-pattern.jmx`)

Quick ramp to peak load, sustained for iterations, then stop. Best for soak testing at specific load.

```
Users
  │
  │  ┌──────────────┐
  │  │              │
  │  │              │
  │  │              │
  ├──┘              └──
  └──────────────── Time
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| `PEAK_USERS` | 100 | Number of concurrent users |
| `PEAK_RAMPUP` | 30 | Ramp-up to peak in seconds |
| `PEAK_ITERATIONS` | 5 | Loops at peak load |

---

## Usage

Include any pattern in your test plan:

```xml
<IncludeController guiclass="TestFragmentGui" testclass="IncludeController">
  <stringProp name="IncludeController.filename">../fragments/step-load-pattern.jmx</stringProp>
</IncludeController>
```

Then add your API samplers as children of the included thread group.
