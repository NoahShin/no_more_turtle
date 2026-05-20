#!/usr/bin/env bash
# Sample CPU% and memory of the running NoMoreTurtle process.
# Uses `top` in logging mode — its CPU% is delta-based from sample 2 onward,
# unlike `ps -o %cpu` which reports lifetime average. First sample is dropped.
#
# Usage: scripts/measure-cpu.sh [DURATION_SECONDS]
# Example: scripts/measure-cpu.sh 30

set -euo pipefail

DURATION="${1:-30}"
# Use `pgrep -fl` so we see the full command line, then filter out the zsh wrapper
# whose command line contains the app path as a literal string.
PID="$(pgrep -fl 'MacOS/NoMoreTurtle' | grep -v 'zsh' | awk '{print $1}' | head -1 || true)"

if [ -z "$PID" ]; then
    echo "NoMoreTurtle is not running."
    exit 1
fi

echo "PID=$PID, sampling ${DURATION}s (1Hz)…"

# -l N: log N samples
# -s 1: 1-second interval
# -stats pid,cpu,mem: fields per process
# Output is parsed by matching the line starting with our PID.
top -l "$((DURATION + 1))" -s 1 -pid "$PID" -stats pid,cpu,mem 2>/dev/null \
  | awk -v pid="$PID" '
      $1 == pid {
          sample++
          if (sample >= 2) {           # drop first (it shows lifetime CPU%)
              cpu_sum += $2
              # $3 looks like "47M+" or "12M"; strip non-numeric suffix
              mem = $3
              gsub(/[^0-9.]/, "", mem)
              mem_sum += mem
              if ($2 > cpu_peak) cpu_peak = $2
              n++
          }
      }
      END {
          if (n == 0) { print "no samples captured"; exit 1 }
          printf "samples=%d  cpu_avg=%.2f%%  cpu_peak=%.2f%%  mem_avg=%.1fMB\n",
                 n, cpu_sum / n, cpu_peak, mem_sum / n
      }
  '
