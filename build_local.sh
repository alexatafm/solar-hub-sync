#!/bin/bash
# =============================================================================
# BUILD DOCKER IMAGE LOCALLY
# =============================================================================

set -e

echo "=============================================================================="
echo "Building Docker image: solar-hub-master-sync"
echo "=============================================================================="

cd "$(dirname "$0")/.."

# Build for linux/amd64 (Railway requirement)
docker build --platform linux/amd64 \
  -f one-time-sync/Dockerfile.master_sync \
  -t solar-hub-master-sync:latest \
  .

echo ""
echo "=============================================================================="
echo "✅ Build complete!"
echo "=============================================================================="
echo ""
echo "Image: solar-hub-master-sync:latest"
echo ""
echo "To test locally:"
echo "  docker run --env-file .env solar-hub-master-sync --limit=10"
echo ""
echo "To push to Railway:"
echo "  railway up"
echo "  railway deploy"
echo ""

