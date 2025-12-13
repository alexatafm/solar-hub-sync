# Quick Start Guide

Get the Jobs sync running in 5 minutes!

## Option 1: Run Locally (Fastest)

### 1. Install Dependencies

```bash
cd one-time-sync/jobs-sync
bundle install
```

### 2. Configure Environment

```bash
cp env.example .env
```

Edit `.env`:
```env
SIMPRO_API_URL=https://your-instance.simprosuite.com/api/v1.0/companies/0
SIMPRO_API_KEY=your_simpro_api_key
HUBSPOT_ACCESS_TOKEN=your_hubspot_token
HUBSPOT_PORTAL_ID=46469336
HUBSPOT_JOB_PIPELINE_ID=1051178435
```

### 3. Run Sync

```bash
ruby sync_jobs.rb
```

### 4. Review Results

- Check `sync_jobs.log` for detailed logs
- Check `jobs_sync_report_*.csv` for summary

---

## Option 2: Deploy to Railway

### 1. Create GitHub Repo

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/simpro-hubspot-jobs-sync.git
git push -u origin main
```

### 2. Deploy to Railway

1. Go to [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository
4. Add environment variables in Railway dashboard
5. Deploy!

### 3. Monitor Progress

Watch the logs in Railway to see sync progress.

### 4. Download Results

Use Railway CLI to download results:

```bash
railway login
railway link
railway logs
```

---

## What Gets Synced?

✅ All job fields (names, IDs, stages, statuses)  
✅ All dates (issued, completed, modified)  
✅ People (salesperson, PM, technicians, contacts)  
✅ Financial data (totals, invoiced, margins)  
✅ Custom fields (region, financing, installation dates)  
✅ **Automatic pipeline stage mapping**

## Expected Time

- 100 jobs: ~5-10 minutes
- 500 jobs: ~25-50 minutes
- 1000 jobs: ~50-100 minutes

## What to Check After

1. Go to HubSpot → Jobs
2. Verify jobs are created
3. Check pipeline stages are correct
4. Spot-check a few jobs for field accuracy

## Need Help?

- Check `README.md` for full documentation
- Check `DEPLOYMENT.md` for Railway details
- Review logs for specific errors

