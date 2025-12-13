# Simpro to HubSpot Jobs Historical Sync

A standalone Ruby script to perform a one-time sync of all historical jobs from Simpro to HubSpot's custom Job object.

## Features

- ✅ **Complete field mapping** - Syncs all job fields including status, dates, people, financials, and custom fields
- ✅ **Automatic pipeline stage mapping** - Maps Simpro job statuses to correct HubSpot pipeline stages
- ✅ **Rate limiting** - Respects API rate limits for both Simpro and HubSpot
- ✅ **Retry logic** - Automatically retries failed requests with exponential backoff
- ✅ **Error handling** - Comprehensive error logging and recovery
- ✅ **Pagination** - Handles large datasets efficiently
- ✅ **Progress tracking** - CSV report with detailed sync results
- ✅ **Idempotent** - Can be safely re-run; updates existing jobs instead of creating duplicates

## Prerequisites

- Ruby 3.3.1 or later
- Simpro API access
- HubSpot Private App access token with Jobs object permissions

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/simpro-hubspot-jobs-sync.git
cd simpro-hubspot-jobs-sync
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Configure Environment Variables

Copy the example environment file:

```bash
cp env.example .env
```

Edit `.env` with your credentials:

```env
# Simpro API Configuration
SIMPRO_API_URL=https://your-instance.simprosuite.com/api/v1.0/companies/0
SIMPRO_API_KEY=your_simpro_api_key_here

# HubSpot API Configuration
HUBSPOT_ACCESS_TOKEN=your_hubspot_access_token_here
HUBSPOT_PORTAL_ID=46469336

# Job Pipeline Configuration
HUBSPOT_JOB_PIPELINE_ID=1051178435

# Rate Limiting Configuration (requests per second)
RATE_LIMIT_SIMPRO=2
RATE_LIMIT_HUBSPOT=10

# Batch Configuration
MAX_RETRIES=3
RETRY_DELAY=5
```

### 4. Run the Sync

```bash
ruby sync_jobs.rb
```

## Field Mapping

### Basic Information
- Job Name → `jobs`
- Simpro Job ID → `simpro_job_id`
- Stage → `stage`
- Status → `status`, `job_status`
- **Pipeline Stage** → `hs_pipeline_stage` (auto-mapped from status)

### Dates
- Date Issued → `date_issued`
- Date Created → `date_created`
- Completed Date → `completed_date`, `completion_date`
- Last Modified → `last_modified_date`
- Date Converted Quote → `date_converted_quote`

### People & Assignments
- Salesperson → `salesperson`, `sales_person_id`
- Project Manager → `project_manager`, `manager_id`
- Technician → `assigned_technicians`, `technician_id`
- Primary Contact → `primary_contact_name`, `primary_customer_contact_id`
- Site Contact → `site_contact_name`

### Customer & Company
- Customer ID → `simpro_customer_id`
- Company ID → `simpro_company_id`
- Company Name → `simpro_company_name`
- Contract ID → `simpro_customer_contract_id`
- Site → `site`, `site_id`

### Financial
- Total Ex Tax → `total_price_ex_tax`
- Total Inc Tax → `total_price_inc_tax`, `total_amount_inc_tax_`
- Invoiced Value → `invoiced_value`
- Invoice % → `invoice_percentage` (calculated)
- Actual Gross Margin → `actual_gross_margin`

### Custom Fields
- Region (CF 111) → `region`
- Financing (CF 52) → `financing`
- SmartRQuoteLink (CF 226) → `custom_29_smartrquotelink`
- Installation Date (CF 85) → `installation_date`
- Grid Approval Number (CF 9) → `grid_approval_number`
- Grid Approval Submitted (CF 80) → `grid_approval_submitted_date`
- Metering Request Date (CF 7) → `metering_requested_date`
- Inspection Date (CF 6) → `inspection_date`
- CES Submitted (CF 11) → `ces_submitted_date`

## Pipeline Stage Mapping

| Simpro Status | HubSpot Stage | Stage ID |
|---------------|---------------|----------|
| Quote Accepted | Job Awaiting Confirmation | 1654704594 |
| New Job - Awaiting Review | Awaiting Review | 1654704595 |
| New Job - Awaiting Approval | Awaiting Approval | 1654704596 |
| New Job - Ready to schedule | Scheduling | 1654704597 |
| Job Scheduled | Job Scheduled | 1654704598 |
| Works Complete | Job Complete | 1654704600 |
| Job Finished | Job Invoiced | 1654704601 |
| On Hold / Site Visit Required / New Build | Job Stuck | 1654704602 |
| Warranty (all types) | Warranty | 1823035851 |
| Job Cancelled | Archived | 1654704603 |

## Output

The script generates two output files:

### 1. Log File: `sync_jobs.log`
Contains detailed execution logs including:
- API requests and responses
- Field extraction details
- Error messages and stack traces
- Progress updates

### 2. CSV Report: `jobs_sync_report_YYYYMMDD_HHMMSS.csv`
Contains a summary row for each job:
- Simpro Job ID
- Job Name
- Status (created/updated/failed/skipped)
- HubSpot Job ID (if successful)
- Error Message (if failed)
- Timestamp

## Rate Limiting

The script implements rate limiting to respect API quotas:

- **Simpro**: 2 requests/second (configurable)
- **HubSpot**: 10 requests/second (configurable)

Adjust these in your `.env` file based on your API limits.

## Error Handling

The script includes comprehensive error handling:

1. **Retry Logic**: Failed requests are automatically retried up to 3 times with 5-second delays
2. **Graceful Degradation**: Individual job failures don't stop the entire sync
3. **Detailed Logging**: All errors are logged with context for debugging
4. **CSV Reporting**: Failed jobs are tracked in the CSV report

## Running on Railway

### 1. Create a New Repository

```bash
# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit: Jobs sync script"

# Create GitHub repo and push
git remote add origin https://github.com/yourusername/simpro-hubspot-jobs-sync.git
git branch -M main
git push -u origin main
```

### 2. Deploy to Railway

1. Go to [railway.app](https://railway.app)
2. Click "New Project"
3. Select "Deploy from GitHub repo"
4. Choose your repository
5. Add environment variables in Railway dashboard
6. Deploy!

### 3. Run the Sync

In Railway, open the deployment and run:

```bash
ruby sync_jobs.rb
```

Or set it as a one-off job in Railway's settings.

### 4. Download Results

After the sync completes, download the log and CSV files from Railway to review results.

## Railway Configuration

Create a `railway.json` file for Railway-specific configuration:

```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "ruby sync_jobs.rb",
    "restartPolicyType": "never"
  }
}
```

## Monitoring Progress

The script provides real-time progress updates:

```
Fetching page 1 from Simpro...
Fetched 250 jobs (total: 250)
Processing job 1/250: 33784 - Test Job Name
✅ Created HubSpot job 188423226839
Processing job 2/250: 33785 - Another Job
✅ Updated HubSpot job 188423226840
...
```

## Performance

Typical sync times (approximate):

- **100 jobs**: 5-10 minutes
- **500 jobs**: 25-50 minutes
- **1000 jobs**: 50-100 minutes
- **5000 jobs**: 4-8 hours

Performance depends on:
- API rate limits
- Network latency
- Job complexity
- Number of custom fields

## Troubleshooting

### API Rate Limit Errors

If you see rate limit errors, reduce the rate in `.env`:

```env
RATE_LIMIT_SIMPRO=1
RATE_LIMIT_HUBSPOT=5
```

### Timeout Errors

Increase the retry delay:

```env
RETRY_DELAY=10
MAX_RETRIES=5
```

### Date Format Errors

The script formats dates to midnight UTC as required by HubSpot. If you see date errors, check the log for the specific job and date field.

### Missing Fields

If fields aren't syncing, check:
1. Field exists in HubSpot Job object
2. Field internal name matches exactly
3. Field has correct permissions
4. Data exists in Simpro

## Re-running the Sync

The script is idempotent and can be safely re-run:

1. Jobs with HubSpot IDs (CF 262) will be **updated**
2. Jobs without HubSpot IDs will be **created**
3. The CSV report will show which action was taken

To force re-sync all jobs, you would need to clear the HubSpot Job ID custom field in Simpro first (not recommended).

## Support

For issues or questions:
1. Check the log file (`sync_jobs.log`)
2. Review the CSV report
3. Check Simpro and HubSpot API documentation
4. Verify environment variables are correct

## License

MIT License - See LICENSE file for details

