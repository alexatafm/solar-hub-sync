#!/bin/bash
# =============================================================================
# BUILD AND PUSH DOCKER IMAGE FOR RAILWAY
# =============================================================================

set -e

echo "=============================================================================="
echo "Building Docker image for Railway deployment"
echo "=============================================================================="

# Build for linux/amd64 (Railway requirement)
docker build --platform linux/amd64 \
  -f one-time-sync/Dockerfile.master_sync \
  -t solar-hub-master-sync:latest \
  -t solar-hub-master-sync:$(date +%Y%m%d-%H%M%S) \
  .

echo ""
echo "=============================================================================="
echo "Build complete!"
echo "=============================================================================="
echo ""
echo "To push to Railway:"
echo "  1. Tag for your Railway registry (if using Railway's registry):"
echo "     docker tag solar-hub-master-sync:latest <your-registry>/solar-hub-master-sync:latest"
echo ""
echo "  2. Or use Railway CLI:"
echo "     railway up"
echo "     railway deploy"
echo ""
echo "  3. Or push to Docker Hub (if using):"
echo "     docker tag solar-hub-master-sync:latest <your-dockerhub>/solar-hub-master-sync:latest"
echo "     docker push <your-dockerhub>/solar-hub-master-sync:latest"
echo ""
echo "=============================================================================="

