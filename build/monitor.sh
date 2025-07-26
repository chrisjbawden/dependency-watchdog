#!/usr/bin/env bash
set -eo pipefail

# ———————— Configuration via ENV ————————
# Name of the container whose death gates all others
TRIGGER="${TRIGGER:-critical-container}"
# Space-separated list of containers that must never run unless $TRIGGER is up
OTHERS="${OTHERS:-dependent-one another-service more-containers}"
# Grace period (seconds) between trigger death and stopping dependents
GRACE="${GRACE:-5}"

# helper: check if $TRIGGER is currently running
is_up() {
  docker ps \
    --filter "name=^/${TRIGGER}$" \
    --filter status=running \
    --quiet
}

# 1) On startup: if trigger isn’t up, stop all dependents immediately
if [[ -z "$(is_up)" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $TRIGGER is not running → stopping dependents"
  for c in $OTHERS; do docker stop "$c" || true; done
fi

# 2) Watch for trigger “die” events
docker events \
  --filter 'event=die' \
  --format '{{.Actor.Attributes.name}}' |
while read -r name; do
  if [[ "$name" == "$TRIGGER" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $TRIGGER died → shutting dependents in $GRACE s"
    sleep "$GRACE"
    for c in $OTHERS; do docker stop "$c" || true; done
  fi
done &

# 3) Watch for dependents “start” events
docker events \
  --filter 'event=start' \
  --format '{{.Actor.Attributes.name}}' |
while read -r name; do
  if [[ " $OTHERS " == *" $name "* ]] && [[ -z "$(is_up)" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempted to start $name but $TRIGGER is down → stopping it"
    docker stop "$name" || true
  fi
done &

wait
