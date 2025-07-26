# Use Docker-in-Docker image for Docker CLI + bash
FROM docker:24.0.10-dind

# Install jq (for JSON parsing) & bash
RUN apk add --no-cache bash jq

# Copy in our monitor script
COPY monitor.sh /usr/local/bin/docker-monitor.sh
RUN chmod +x /usr/local/bin/docker-monitor.sh

# Run it as PID 1
ENTRYPOINT ["/usr/local/bin/docker-monitor.sh"]
