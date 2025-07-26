#!/usr/bin/env bash
set -eo pipefail

# ———————— Configuration via ENV ————————
# Name of the container whose death gates all others
MONITOR="${MONITOR:-critical-container}"
# Space-separated list of containers that must never run unless $MONITOR is up
DEPENDANT="${DEPENDANT:-dependent-one another-service more-containers}"
# Grace period (seconds) between monitor death and stopping dependants
GRACE="${GRACE:-5}"

# helper: check if $MONITOR is currently running
is_up() {
  docker ps \
    --filter "name=^/${MONITOR}$" \
    --filter status=running \
    --quiet
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring started for - $MONITOR"

# 1) On startup: if MONITOR isn’t up, stop all dependants immediately
if [[ -z "$(is_up)" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MONITOR is not running → stopping dependants"
  for c in $DEPENDANT; do docker stop "$c" || true; done
fi

# 2) Watch for MONITOR “die” events
docker events \
  --filter 'event=die' \
  --format '{{.Actor.Attributes.name}}' |
while read -r name; do
  if [[ "$name" == "$MONITOR" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MONITOR died → shutting dependants in $GRACE s"
    sleep "$GRACE"
    for c in $DEPENDANT; do docker stop "$c" || true; done
  fi
done &

# 3) Watch for dependants “start” events
docker events \
  --filter 'event=start' \
  --format '{{.Actor.Attributes.name}}' |
while read -r name; do
  # only stop if it's in our DEPENDANT list and MONITOR is down
  if [[ " $DEPENDANT " == *" $name "* ]] && [[ -z "$(is_up)" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $name attempted to start but $MONITOR is down → stopping it"
    docker stop "$name" || true
  fi
done &

wait
