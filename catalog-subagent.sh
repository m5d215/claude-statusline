#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Ceuo pipefail

show() {
  printf "%s# %s%s\n" $'\e[2m' "$1" $'\e[0m'
  jq -nc "$2" | ./subagent-statusline.sh | jq -r '.content'
  echo
}

# --- Status variations ---

show 'status: running (green …)' '{
    tasks: [{
        id: "t1",
        label: "Explore the auth module",
        description: "Explore the auth module",
        status: "running",
        tokenCount: 12345,
        startTime: (now * 1000 - 95000 | floor)
    }]
}'

show 'status: completed (cyan ✓)' '{
    tasks: [{
        id: "t1",
        label: "Search for deprecated APIs",
        description: "Search for deprecated APIs",
        status: "completed",
        tokenCount: 8765,
        startTime: (now * 1000 - 42000 | floor)
    }]
}'

show 'status: failed (red ✗)' '{
    tasks: [{
        id: "t1",
        label: "Compile rust binary",
        description: "Compile rust binary",
        status: "failed",
        tokenCount: 4321,
        startTime: (now * 1000 - 17000 | floor)
    }]
}'

show 'status: pending / unknown (gray ○)' '{
    tasks: [{
        id: "t1",
        label: "Queued task",
        description: "Queued task",
        status: "pending",
        tokenCount: 0,
        startTime: 0
    }]
}'

# --- Token count formatting ---

show 'tokens: small (<1k → raw)' '{
    tasks: [{
        id: "t1", label: "Small task", description: "Small task",
        status: "running", tokenCount: 234,
        startTime: (now * 1000 - 5000 | floor)
    }]
}'

show 'tokens: medium (<100k → X.Xk)' '{
    tasks: [{
        id: "t1", label: "Medium task", description: "Medium task",
        status: "running", tokenCount: 61470,
        startTime: (now * 1000 - 60000 | floor)
    }]
}'

show 'tokens: large (<1M → XXXk)' '{
    tasks: [{
        id: "t1", label: "Large task", description: "Large task",
        status: "running", tokenCount: 234567,
        startTime: (now * 1000 - 300000 | floor)
    }]
}'

show 'tokens: huge (>=1M → X.XM)' '{
    tasks: [{
        id: "t1", label: "Huge task", description: "Huge task",
        status: "running", tokenCount: 1234567,
        startTime: (now * 1000 - 600000 | floor)
    }]
}'

# --- Duration formatting ---

show 'duration: seconds only (0:07)' '{
    tasks: [{
        id: "t1", label: "Quick task", description: "Quick task",
        status: "completed", tokenCount: 1500,
        startTime: (now * 1000 - 7000 | floor)
    }]
}'

show 'duration: minutes (3:26)' '{
    tasks: [{
        id: "t1", label: "Mid task", description: "Mid task",
        status: "running", tokenCount: 30000,
        startTime: (now * 1000 - 206000 | floor)
    }]
}'

show 'duration: hours (1:05:07)' '{
    tasks: [{
        id: "t1", label: "Long task", description: "Long task",
        status: "running", tokenCount: 500000,
        startTime: (now * 1000 - 3907000 | floor)
    }]
}'

# --- Label / description variations ---

show 'label == description (description suppressed)' '{
    tasks: [{
        id: "t1",
        label: "Refactor parser",
        description: "Refactor parser",
        status: "running", tokenCount: 5000,
        startTime: (now * 1000 - 30000 | floor)
    }]
}'

show 'label != description (both shown)' '{
    tasks: [{
        id: "t1",
        label: "Explore",
        description: "Find all TODO comments in src/",
        status: "running", tokenCount: 5000,
        startTime: (now * 1000 - 30000 | floor)
    }]
}'

show 'description empty (omitted)' '{
    tasks: [{
        id: "t1",
        label: "Task with no description",
        description: "",
        status: "running", tokenCount: 5000,
        startTime: (now * 1000 - 30000 | floor)
    }]
}'

show 'label missing (falls back to description)' '{
    tasks: [{
        id: "t1",
        description: "Description used as label",
        status: "running", tokenCount: 5000,
        startTime: (now * 1000 - 30000 | floor)
    }]
}'

# --- Multiple tasks ---

show 'multiple: running + completed + failed' '{
    tasks: [
        { id: "t1", label: "Explore auth module", description: "Explore auth module",
          status: "running", tokenCount: 61470, startTime: (now * 1000 - 95000 | floor) },
        { id: "t2", label: "Search docs", description: "Search docs",
          status: "completed", tokenCount: 8765, startTime: (now * 1000 - 30000 | floor) },
        { id: "t3", label: "Run tests", description: "Run tests",
          status: "failed", tokenCount: 4321, startTime: (now * 1000 - 17000 | floor) }
    ]
}'

# --- Edge cases ---

show 'empty tasks (no output)' '{
    tasks: []
}'

show 'minimal: most fields missing' '{
    tasks: [{ id: "t1" }]
}'

show 'no startTime (elapsed omitted)' '{
    tasks: [{
        id: "t1",
        label: "Task without startTime",
        description: "Task without startTime",
        status: "running",
        tokenCount: 1000
    }]
}'
