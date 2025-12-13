# Deployment Guide for Railway

This guide walks you through deploying the Jobs Sync script to Railway as a standalone project.

## Prerequisites

1. **GitHub Account** - You'll need a GitHub account to create a repository
2. **Railway Account** - Sign up at [railway.app](https://railway.app) (free tier available)
3. **API Credentials**:
   - Simpro API URL and Key
   - HubSpot Private App Access Token

## Step 1: Create a New GitHub Repository

### Option A: Using GitHub Web Interface

1. Go to [github.com/new](https://github.com/new)
2. Repository name: `simpro-hubspot-jobs-sync`
3. Description: "One-time sync of Simpro jobs to HubSpot"
4. Set to **Private** (recommended for security)
5. Click "Create repository"

### Option B: Using Git CLI

```bash
# Navigate to the jobs-sync directory
cd one-time-sync/jobs-sync

# Initialize git
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: Jobs historical sync script"

# Create repo on GitHub (if using GitHub CLI)
gh repo create simpro-hubspot-jobs-sync --private --source=. --push

# Or push to existing repo
git remote add origin https://github.com/YOUR_USERNAME/simpro-hubspot-jobs-sync.git
git branch -M main
git push -u origin main
```

## Step 2: Deploy to Railway

### Connect Repository

1. Go to [railway.app/dashboard](https://railway.app/dashboard)
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Authorize Railway to access your GitHub account (if first time)
5. Select the `simpro-hubspot-jobs-sync` repository
6. Railway will automatically detect it's a Ruby project

### Configure Environment Variables

1. In your Railway project, click **"Variables"** tab
2. Add the following environment variables:

```env
SIMPRO_API_URL=https://your-instance.simprosuite.com/api/v1.0/companies/0
SIMPRO_API_KEY=your_simpro_api_key_here
HUBSPOT_ACCESS_TOKEN=your_hubspot_access_token_here
HUBSPOT_PORTAL_ID=46469336
HUBSPOT_JOB_PIPELINE_ID=1051178435
RATE_LIMIT_SIMPRO=2
RATE_LIMIT_HUBSPOT=10
MAX_RETRIES=3
RETRY_DELAY=5
```

**Important**: Keep these values secure! Railway encrypts environment variables.

### Initial Deployment

1. Railway will automatically trigger a deployment
2. Watch the build logs in the **"Deployments"** tab
3. The build should complete successfully
4. The script will start running automatically

## Step 3: Monitor the Sync

### View Logs

1. Click on the deployment in Railway
2. Click **"View Logs"**
3. Watch real-time progress:

```
Fetching page 1 from Simpro...
Fetched 250 jobs (total: 250)
Processing job 1/250: 33784 - Test Job Name
✅ Created HubSpot job 188423226839
...
```

### Check Progress

The logs will show:
- Number of jobs fetched
- Current job being processed
- Success/failure status for each job
- Final summary with statistics

## Step 4: Download Results

After the sync completes:

### Download Log File

1. In Railway, go to your deployment
2. Click **"Logs"** → **"Download Logs"**
3. This downloads `sync_jobs.log` with full details

### Download CSV Report

The CSV report is generated at: `jobs_sync_report_YYYYMMDD_HHMMSS.csv`

To download:
1. Railway doesn't have direct file download
2. Two options:

**Option A: Use Railway CLI**
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Link to your project
railway link

# Shell into the container
railway shell

# Copy the CSV content
cat jobs_sync_report_*.csv
```

**Option B: Add file upload to script**
You can modify the script to upload results to S3, Google Drive, or send via email.

## Step 5: Verify Results in HubSpot

1. Go to HubSpot → **Jobs** (custom object)
2. Check that jobs are created
3. Verify pipeline stages are correct
4. Spot-check field mappings

## Troubleshooting

### Build Fails

**Error**: `Ruby version not found`
- **Solution**: Ensure `nixpacks.toml` specifies `ruby_3_3`

**Error**: `Bundle install failed`
- **Solution**: Check `Gemfile` is correct and committed

### Deployment Crashes

**Error**: `Connection refused`
- **Solution**: Check `SIMPRO_API_URL` and `HUBSPOT_ACCESS_TOKEN` are set correctly

**Error**: `401 Unauthorized`
- **Solution**: Verify API credentials are valid and have correct permissions

### Rate Limit Errors

**Error**: `429 Too Many Requests`
- **Solution**: Reduce `RATE_LIMIT_SIMPRO` or `RATE_LIMIT_HUBSPOT` in environment variables

### Out of Memory

**Error**: `Killed` or OOM errors
- **Solution**: Railway free tier has memory limits. Consider:
  - Processing in smaller batches
  - Upgrading Railway plan
  - Running locally instead

## Re-running the Sync

To run the sync again:

1. **Manual trigger**: Railway may auto-restart. To prevent this:
   - Set `restartPolicyType: "never"` in `railway.json` (already done)
   
2. **New deployment**: Push a commit to trigger new deployment:
   ```bash
   git commit --allow-empty -m "Trigger re-sync"
   git push
   ```

3. **Use Railway CLI**:
   ```bash
   railway run ruby sync_jobs.rb
   ```

## Cost Considerations

### Railway Pricing

- **Free Tier**: $5 credit/month, up to 500 execution hours
- **Pro Tier**: $20/month for 100 execution hours

### Estimated Costs

For a one-time sync:
- **Small dataset (<500 jobs)**: Free tier sufficient
- **Medium dataset (500-2000 jobs)**: Free tier sufficient
- **Large dataset (2000+ jobs)**: May need Pro tier for execution time

This is a **one-time sync**, so even on Pro tier, you'd only pay for the single execution time (~$0.10-$1.00 for most syncs).

## Alternative: Run Locally

If you prefer not to use Railway, run locally:

```bash
# Install dependencies
bundle install

# Set up .env file
cp env.example .env
# Edit .env with your credentials

# Run sync
ruby sync_jobs.rb
```

This is free and gives you direct access to the CSV and log files.

## Security Best Practices

1. ✅ **Use Private Repository** - Don't expose credentials
2. ✅ **Environment Variables** - Never commit credentials
3. ✅ **Review Logs** - Check for sensitive data before sharing
4. ✅ **Rotate Keys** - Consider rotating API keys after sync
5. ✅ **Delete Deployment** - Remove Railway project after sync if not needed

## Post-Sync Cleanup

After successful sync:

1. ✅ Verify all jobs in HubSpot
2. ✅ Download and archive logs/CSV report
3. ✅ Delete Railway project (if no longer needed)
4. ✅ Archive GitHub repository (optional)
5. ✅ Document any issues/learnings

## Support

If you encounter issues:

1. Check the Railway logs
2. Review `sync_jobs.log` for detailed errors
3. Check the CSV report for failed jobs
4. Verify API credentials and permissions
5. Check Simpro/HubSpot API status pages

## Next Steps

After the historical sync:

1. **Enable webhooks** in the main Rails app for ongoing sync
2. **Monitor** the webhook sync for any issues
3. **Document** any custom fields or special cases
4. **Train users** on the Job object in HubSpot

