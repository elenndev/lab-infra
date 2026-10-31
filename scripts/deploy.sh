#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="${1:?Usage: ./scripts/deploy.sh <image>}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

export BACKEND_IMAGE="$IMAGE"

echo "===================================="
echo "Initiating backend deployment"
echo "Image: $BACKEND_IMAGE"
echo "===================================="

echo "[1/3] Downloading image..."
docker compose pull backend

echo "[2/3] Updating container..."
docker compose up -d --no-deps backend

echo "[3/3] Waiting for health check..."

CONTAINER="lab-backend"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
    STATUS=$(docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$CONTAINER")

    if [ "$STATUS" = "healthy" ]; then
        echo "Deployment completed successfully!"
        exit 0
    fi

    if [ "$STATUS" = "unhealthy" ] || [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
        echo "ERROR: Backend presented '$STATUS' state ."
        docker compose logs --tail=50 backend
        exit 1
    fi

    ATTEMPT=$((ATTEMPT + 1))

    echo "Waiting backend... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 2
done

echo "ERRO: Timeout waiting for Health Check."
docker compose logs --tail=50 backend
exit 1
