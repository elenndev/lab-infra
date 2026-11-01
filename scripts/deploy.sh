#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="${1:?Usage: ./scripts/deploy.sh <image>}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

CONTAINER="lab-backend"
MAX_ATTEMPTS=30
SLEEP_SECONDS=2

echo "===================================="
echo "Initiating backend deployment"
echo "Image: $IMAGE"
echo "===================================="

PREVIOUS_IMAGE=""

if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    PREVIOUS_IMAGE=$(docker inspect \
        --format '{{.Config.Image}}' \
        "$CONTAINER")

    echo "Previous image: $PREVIOUS_IMAGE"
else
    echo "No previous container found."
fi

wait_for_health() {
    local attempt=0
    local status

    while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
        if ! status=$(docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
            "$CONTAINER" 2>/dev/null); then
            echo "Container not found."
            return 1
        fi

        if [ "$status" = "healthy" ]; then
            return 0
        fi

        if [ "$status" = "unhealthy" ] ||
           [ "$status" = "exited" ] ||
           [ "$status" = "dead" ]; then
            echo "Container entered state: $status"
            return 1
        fi

        attempt=$((attempt + 1))

        echo "Waiting for health check... ($attempt/$MAX_ATTEMPTS)"
        sleep "$SLEEP_SECONDS"
    done

    echo "Health check timeout."
    return 1
}

rollback() {
    echo "===================================="
    echo "Initiating rollback"
    echo "===================================="

    if [ -z "$PREVIOUS_IMAGE" ]; then
        echo "ERROR: No previous image available for rollback."
        return 1
    fi

    export BACKEND_IMAGE="$PREVIOUS_IMAGE"

    echo "Restoring image: $PREVIOUS_IMAGE"

    if ! docker compose pull backend; then
        echo "ERROR: Failed to pull previous image."
        return 1
    fi

    if ! docker compose up -d --no-deps backend; then
        echo "ERROR: Failed to restore previous container."
        return 1
    fi

    if wait_for_health; then
        echo "Rollback completed successfully!"
        return 0
    fi

    echo "ERROR: Previous version did not become healthy."
    docker compose logs --tail=50 backend
    return 1
}

export BACKEND_IMAGE="$IMAGE"

echo "[1/3] Downloading image..."

if ! docker compose pull backend; then
    echo "ERROR: Failed to download new image."
    rollback || true
    exit 1
fi

echo "[2/3] Updating container..."

if ! docker compose up -d --no-deps backend; then
    echo "ERROR: Failed to update container."
    rollback || true
    exit 1
fi

echo "[3/3] Waiting for health check..."

if wait_for_health; then
    echo "===================================="
    echo "Deployment completed successfully!"
    echo "Active image: $IMAGE"
    echo "===================================="
    exit 0
fi

echo "ERROR: New deployment failed."
docker compose logs --tail=50 backend

if rollback; then
    echo "Deployment failed, but previous version was restored."
else
    echo "CRITICAL: Deployment and rollback both failed."
fi

exit 1
