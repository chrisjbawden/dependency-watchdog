# dependson

A lightweight “sidecar” Docker container that watches a **primary** container and enforces ad‑hoc “depends on” behaviour - if your monitored container goes offline, any listed dependents are stopped (and prevented from starting until it’s back up).

---

## Features

- Watches Docker events (`die` / `start`) on your host’s daemon  
- On startup: if the **MONITOR** container isn’t running, it immediately stops all **DEPENDANT** containers  
- If **MONITOR** dies, waits a configurable grace period and then stops each **DEPENDANT**  
- Any time a **DEPENDANT** tries to start while **MONITOR** is down, it’s shut down immediately  
- Runs as PID 1 in its own container; supports Docker’s `--restart` policies

---

## Configuration

| Environment Variable | Description                                                                                  | Default                                    |
|----------------------|----------------------------------------------------------------------------------------------|--------------------------------------------|
| `MONITOR`            | Name of the container to watch (exact match)                                                 | `critical-container`                       |
| `DEPENDANT`          | Space‑separated list of containers to stop if `MONITOR` is not running                       | `dependent-one another-service more-containers` |
| `GRACE`              | Seconds to wait after `MONITOR` dies before stopping `DEPENDANT` containers                  | `5`                                        |

All other behaviour (listening to Docker events, parsing JSON) is built into the bundled `monitor.sh`.

---

## Usage

```
docker run -d \
  --name [container]-monitor \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e MONITOR="my-critical-container" \
  -e DEPENDANT="worker-1 worker-2 ui-service" \
  -e GRACE="10" \
  --restart unless-stopped \
  chrisjbawden/dependson:latest
```


-v /var/run/docker.sock:/var/run/docker.sock
Grants the sidecar access to Docker events and CLI on the host.

-e MONITOR="…"
Cofnigure which contained to monitor/watch

-e DEPENDANT="…"
Configure which container/s to control in response to changes in the container being monitored.

--restart unless-stopped
Ensures your watchdog will relaunch automatically if it crashes or the host reboots.

## Behaviour in action

1. On container start
  * Sidecar checks if ${MONITOR} is running.
  * If not, it stops any ${DEPENDANT} immediately.

2. When ${MONITOR} dies
  * Emits a log message, waits ${GRACE} seconds.
  * Stops each container in ${DEPENDANT}.

3. If someone (or Docker’s restart policy) tries to start a ${DEPENDANT}
  * Sidecar detects the start event.
  * If ${MONITOR} is still down, it shuts that container down again.
