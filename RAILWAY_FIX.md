# Railway Deployment Fix

## Problem

Railway is trying to pull a Docker image from Docker Hub (`solar-hub-master-sync:latest`), but the image was only built locally and never pushed to a registry.

Error: "We were unable to connect to the registry for this image"

## Solution: Build from Source

Railway needs to build the Docker image from your source code, not pull a pre-built image.

### Option 1: Connect GitHub Repo (Recommended)

1. In Railway dashboard → Your service → Settings
2. Connect your GitHub repository
3. Railway will automatically detect `railway.toml` and build from source
4. The `railway.toml` file tells Railway to:
   - Use `one-time-sync/Dockerfile.master_sync` 
   - Run `ruby one-time-sync/master_full_sync.rb`

### Option 2: Push to Docker Hub First

If you want to use a pre-built image:

```bash
# Tag for Docker Hub
docker tag solar-hub-master-sync:latest <your-dockerhub-username>/solar-hub-master-sync:latest

# Login to Docker Hub
docker login

# Push
docker push <your-dockerhub-username>/solar-hub-master-sync:latest

# Then in Railway, use: <your-dockerhub-username>/solar-hub-master-sync:latest
```

### Option 3: Use Railway CLI

```bash
# Make sure railway.toml is in root
railway link
railway up
railway deploy
```

## Current Configuration

The `railway.toml` file in the root directory is configured to:
- Build from `one-time-sync/Dockerfile.master_sync`
- Run `ruby one-time-sync/master_full_sync.rb`

This should work once Railway builds from source instead of trying to pull from Docker Hub.

