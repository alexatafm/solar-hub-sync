# Jobs Historical Sync - Project Summary

## Overview

This is a standalone Ruby project for syncing all historical jobs from Simpro to HubSpot. It can be deployed to Railway or run locally.

## Project Structure

```
jobs-sync/
├── sync_jobs.rb          # Main sync script
├── test_sync.rb          # Test script (single job)
├── setup.sh              # Setup script
├── Gemfile               # Ruby dependencies
├── env.example           # Environment variables template
├── .gitignore           # Git ignore rules
├── railway.json         # Railway configuration
├── nixpacks.toml        # Nixpacks build config
├── README.md            # Complete documentation
├── DEPLOYMENT.md        # Railway deployment guide
├── QUICK_START.md       # Quick start guide
└── PROJECT_SUMMARY.md   # This file
```

## What It Does

### ✅ Complete Job Sync
- Fetches ALL jobs from Simpro API (with pagination)
- Maps 40+ fields from Simpro to HubSpot
- Automatically maps job statuses to HubSpot pipeline stages
- Creates new jobs or updates existing ones
- Updates Simpro with HubSpot Job IDs

### ✅ Robust Error Handling
- Rate limiting for both APIs
- Automatic retries (3 attempts with 5s delay)
- Comprehensive error logging
- CSV report with detailed results
- Graceful handling of individual job failures

### ✅ Field Mapping

**Basic Information** (5 fields)
- Job Name, ID, Stage, Status, Pipeline Stage

**Dates** (6 fields)
- Date Issued, Created, Completed, Modified, Converted Quote

**People & Assignments** (10 fields)
- Salesperson, Manager, Technicians, Contacts, IDs

**Customer & Company** (6 fields)
- Customer ID, Company ID/Name, Contract ID, Site info

**Financial** (6 fields)
- Total Ex/Inc Tax, Invoiced Value, Invoice %, Gross Margin

**Custom Fields** (9 fields)
- Region, Financing, Installation Date, Grid Approval, etc.

### ✅ Pipeline Stage Mapping

Automatically maps 14 Simpro statuses to HubSpot pipeline stages:
- Quote Accepted → Job Awaiting Confirmation
- New Job - Awaiting Review → Awaiting Review
- New Job - Awaiting Approval → Awaiting Approval
- New Job - Ready to schedule → Scheduling
- Job Scheduled → Job Scheduled
- Works Complete → Job Complete
- Job Finished → Job Invoiced
- On Hold/Site Visit/New Build → Job Stuck
- Warranty (all types) → Warranty
- Job Cancelled → Archived

## How to Use

### Quick Start

```bash
# 1. Setup
cd jobs-sync
./setup.sh

# 2. Configure
nano .env  # Add your API credentials

# 3. Test with one job
./test_sync.rb

# 4. Run full sync
./sync_jobs.rb
```

### Deploy to Railway

```bash
# 1. Create GitHub repo
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/simpro-hubspot-jobs-sync.git
git push -u origin main

# 2. Deploy to Railway
# - Go to railway.app
# - New Project → Deploy from GitHub
# - Add environment variables
# - Deploy!
```

## Configuration

### Required Environment Variables

```env
SIMPRO_API_URL=https://your-instance.simprosuite.com/api/v1.0/companies/0
SIMPRO_API_KEY=your_simpro_api_key
HUBSPOT_ACCESS_TOKEN=your_hubspot_token
HUBSPOT_PORTAL_ID=46469336
HUBSPOT_JOB_PIPELINE_ID=1051178435
```

### Optional Configuration

```env
RATE_LIMIT_SIMPRO=2         # Requests per second
RATE_LIMIT_HUBSPOT=10       # Requests per second
MAX_RETRIES=3               # Retry attempts
RETRY_DELAY=5               # Seconds between retries
```

## Output Files

### 1. `sync_jobs.log`
Detailed execution log with:
- API requests/responses
- Field extraction details
- Error messages and stack traces
- Progress updates

### 2. `jobs_sync_report_YYYYMMDD_HHMMSS.csv`
Summary report with columns:
- Simpro Job ID
- Job Name
- Status (created/updated/failed/skipped)
- HubSpot Job ID
- Error Message
- Timestamp

## Performance

### Expected Sync Times

| Jobs | Time (approx) |
|------|---------------|
| 100 | 5-10 minutes |
| 500 | 25-50 minutes |
| 1000 | 50-100 minutes |
| 5000 | 4-8 hours |

### Rate Limits

- **Simpro**: 2 requests/second (default)
- **HubSpot**: 10 requests/second (default)

Adjust in `.env` based on your API limits.

## Features

### ✅ Idempotent
- Can be safely re-run
- Updates existing jobs (using CF 262 HubSpot Job ID)
- Creates new jobs if no HubSpot ID found

### ✅ Resilient
- Individual job failures don't stop entire sync
- Automatic retries for transient errors
- Comprehensive error logging

### ✅ Observable
- Real-time progress logging
- Detailed CSV report
- Summary statistics at end

### ✅ Configurable
- Adjustable rate limits
- Configurable retry logic
- Environment-based configuration

## Dependencies

```ruby
gem 'httparty', '~> 0.23.2'  # HTTP requests
gem 'dotenv', '~> 3.1'       # Environment variables
gem 'csv', '~> 3.3'          # CSV reports
gem 'json', '~> 2.7'         # JSON parsing
```

## Testing

### Test with Single Job

```bash
./test_sync.rb
```

This will:
1. Fetch one job from Simpro
2. Process and sync to HubSpot
3. Show detailed results
4. Verify the sync works before running full sync

### Test Locally Before Railway

Always test locally first:
1. Ensures credentials work
2. Verifies field mappings
3. Catches issues early
4. Much faster to debug

## Deployment Options

### Option 1: Railway (Recommended)
✅ Automated deployment  
✅ Easy monitoring  
✅ No local setup needed  
❌ Requires GitHub repo  
❌ Small usage cost (usually <$1)

### Option 2: Local Machine
✅ Free  
✅ Direct access to files  
✅ Easy debugging  
❌ Must keep computer running  
❌ Manual setup

### Option 3: Heroku
✅ Similar to Railway  
✅ Free tier available  
❌ More complex setup  
❌ May need worker dyno

## Security

### ✅ Best Practices Implemented
- Environment variables for credentials
- .gitignore for sensitive files
- Private repository recommended
- No credentials in logs

### ⚠️ Important
- Never commit `.env` file
- Use private GitHub repository
- Rotate API keys after sync (optional)
- Review logs before sharing

## Troubleshooting

### Common Issues

**Connection Errors**
- Check API URLs and keys
- Verify network connectivity
- Check API status pages

**Rate Limit Errors**
- Reduce rate limits in `.env`
- Increase retry delay
- Check API quotas

**Date Format Errors**
- Script handles midnight UTC automatically
- Check log for specific issues

**Missing Fields**
- Verify field exists in HubSpot
- Check field internal name
- Verify permissions

## Next Steps

After successful sync:

1. ✅ Verify jobs in HubSpot
2. ✅ Check pipeline stages
3. ✅ Spot-check field accuracy
4. ✅ Enable ongoing webhook sync
5. ✅ Archive sync logs
6. ✅ Clean up Railway deployment (if done)

## Support

Need help?
1. Check `README.md` for full docs
2. Check `DEPLOYMENT.md` for Railway guide
3. Review `sync_jobs.log` for errors
4. Check CSV report for failed jobs
5. Verify API credentials and permissions

## License

MIT License

## Credits

Created for Solar Hub Simpro-HubSpot integration.
Based on the webhook sync field mappings from the main application.

