# Docker Setup for One-Time Job Sync

This guide covers Docker-based deployment for the one-time job sync, providing complete isolation and easy testing.

## 🐳 Quick Start (Local Testing)

### 1. Prerequisites

```bash
# Install Docker
# macOS: Download from https://www.docker.com/products/docker-desktop
# Verify installation
docker --version
docker-compose --version
```

### 2. Setup Environment Variables

Create `.env` file in this directory:

```bash
cp env.example .env
```

Edit `.env` with your actual credentials.

### 3. Test with 5 Jobs First

**ALWAYS test before running the full sync!**

```bash
# Build and run test (5 jobs only)
docker-compose --profile test up job-sync-test

# Or with custom number of jobs
MAX_JOBS=10 docker-compose --profile test up job-sync-test
```

**Expected output:**
- ✅ Successfully connected to Simpro
- ✅ Successfully connected to HubSpot
- Processing 5 jobs...
- Stats at the end

### 4. Run Full Sync Locally (if test passes)

```bash
# Build and run full sync
docker-compose up job-sync

# Or build first, then run
docker-compose build
docker-compose up job-sync
```

### 5. View Logs and Reports

```bash
# Logs are saved to ./logs/sync_jobs.log
tail -f logs/sync_jobs.log

# Reports are saved to ./reports/
ls -lh reports/
```

## 🚂 Railway Deployment via CLI

### Step 1: Install Railway CLI

```bash
# macOS/Linux
curl -fsSL https://railway.app/install.sh | sh

# Or with Homebrew
brew install railway

# Verify installation
railway --version
```

### Step 2: Login to Railway

```bash
railway login
```

This opens your browser to authenticate.

### Step 3: Link to Your Railway Project

```bash
# In this directory, link to your project
railway link

# Select your project from the list
# Or link by project ID if you know it
railway link <project-id>
```

### Step 4: Build Docker Image Locally

```bash
# Build the Docker image
docker build -t solarhub-job-sync:latest .

# Test it locally first!
docker run --env-file .env solarhub-job-sync:latest ruby test_sync.rb
```

### Step 5: Deploy to Railway

**Option A: Deploy from Local Docker Image**

```bash
# Deploy the current directory (Railway will detect Dockerfile)
railway up

# Or deploy in detached mode
railway up --detach
```

**Option B: Add as Railway Service with Docker**

1. In Railway dashboard, click "New Service"
2. Select "Docker Image"
3. Use the Docker image option

**Option C: Deploy via Railway CLI with custom image**

```bash
# If you pushed to Docker Hub
docker tag solarhub-job-sync:latest your-dockerhub-username/solarhub-job-sync:latest
docker push your-dockerhub-username/solarhub-job-sync:latest

# Then in Railway, add service with Docker image:
# your-dockerhub-username/solarhub-job-sync:latest
```

### Step 6: Set Environment Variables in Railway

```bash
# Set variables via CLI
railway variables --set "SIMPRO_API_KEY=your_key_here"
railway variables --set "SIMPRO_API_URL=https://solarhub.simprosuite.com/api/v1.0/companies/4"
railway variables --set "HUBSPOT_ACCESS_TOKEN=your_token_here"
railway variables --set "HUBSPOT_PIPELINE_ID=1051178435"

# Or set all at once from your .env file
cat .env | grep -v '^#' | while read line; do
  if [ ! -z "$line" ]; then
    railway variables --set "$line"
  fi
done
```

### Step 7: Monitor the Deployment

```bash
# Watch logs in real-time
railway logs

# Check status
railway status

# Open Railway dashboard
railway open
```

### Step 8: Run Test Mode on Railway First!

Before running the full sync, test with limited jobs:

```bash
# Set test mode
railway variables --set "MAX_JOBS=5"

# Deploy and watch
railway up --detach
railway logs --follow
```

If successful, remove the limit:

```bash
# Remove test limit
railway variables --set "MAX_JOBS="

# Redeploy for full sync
railway redeploy
```

## 🛠️ Docker Commands Reference

### Build and Test

```bash
# Build image
docker build -t solarhub-job-sync .

# Run test (5 jobs)
docker run --env-file .env -e MAX_JOBS=5 solarhub-job-sync ruby test_sync.rb

# Run full sync
docker run --env-file .env solarhub-job-sync

# Run with volume mounts (to save logs locally)
docker run --env-file .env \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/reports:/app/reports \
  solarhub-job-sync
```

### Debug

```bash
# Interactive shell in container
docker run -it --env-file .env --entrypoint /bin/bash solarhub-job-sync

# Then inside container:
ruby test_sync.rb
ruby sync_jobs.rb
```

### Clean Up

```bash
# Stop and remove containers
docker-compose down

# Remove image
docker rmi solarhub-job-sync

# Clean up all
docker system prune -a
```

## 🚀 Deployment Workflow

### Recommended Flow:

1. **Local Test (5 jobs)**
   ```bash
   docker-compose --profile test up job-sync-test
   ```

2. **Check Results**
   - Check logs: `cat logs/sync_jobs.log`
   - Verify in HubSpot: Check that 5 jobs synced correctly
   - Verify percentages are correct (e.g., 8.05% not 805%)

3. **Local Test (50 jobs)**
   ```bash
   MAX_JOBS=50 docker-compose --profile test up job-sync-test
   ```

4. **Deploy to Railway (Test Mode)**
   ```bash
   railway variables --set "MAX_JOBS=10"
   railway up --detach
   railway logs --follow
   ```

5. **Full Sync on Railway**
   ```bash
   railway variables --set "MAX_JOBS="
   railway redeploy
   railway logs --follow
   ```

## 📊 Monitoring

### Railway CLI Monitoring

```bash
# Real-time logs
railway logs --follow

# Recent logs
railway logs

# Check deployment status
railway status

# SSH into the running container (if needed)
railway ssh

# Inside SSH, check:
ls -lh /app/logs/
tail /app/logs/sync_jobs.log
```

### Local Monitoring

```bash
# Watch logs
tail -f logs/sync_jobs.log

# Check reports
ls -lh reports/

# View latest report
cat reports/jobs_sync_report_*.csv | head -20
```

## 🔧 Troubleshooting

### Issue: "Cannot connect to Docker daemon"
```bash
# Start Docker Desktop
open -a Docker

# Or restart Docker service
sudo systemctl restart docker
```

### Issue: "Port already in use"
```bash
# This shouldn't happen as we're not exposing ports
# But if needed, kill process on port
lsof -ti:3000 | xargs kill -9
```

### Issue: "Railway CLI not found"
```bash
# Reinstall Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# Add to PATH
export PATH="$HOME/.railway/bin:$PATH"
```

### Issue: "Environment variables not loading"
```bash
# Verify .env file exists
ls -la .env

# Check variables in Railway
railway variables

# Test locally with explicit env vars
docker run -e SIMPRO_API_KEY=test solarhub-job-sync env | grep SIMPRO
```

## 🎯 Testing Strategy

1. ✅ **Test 1**: 5 jobs locally
2. ✅ **Test 2**: 50 jobs locally
3. ✅ **Test 3**: 10 jobs on Railway
4. ✅ **Test 4**: Full sync on Railway

This ensures everything works before processing 25,000+ jobs!

## 📝 Notes

- **One-time container**: Containers exit after completion (not continuous)
- **Logs persist**: Mounted volumes keep logs even after container stops
- **Cost**: Railway charges per minute of compute time
- **Duration**: ~9-10 hours for full sync (25,840 jobs)
- **Resume**: If interrupted, script will update existing jobs on re-run

