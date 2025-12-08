# Environment Variable Mapping

## What the Docker Image Expects

The `master_full_sync.rb` script uses these environment variables:

| Variable Name | Purpose | Example |
|--------------|---------|---------|
| `SIMPRO_TEST_URL` | Base SimPRO API URL | `https://yourcompany.simprosuite.com/api/v1.0` |
| `SIMPRO_TEST_KEY_ID` | SimPRO API Key | `your_simpro_api_key_here` |
| `HUBSPOT_ACCESS_TOKEN` | HubSpot API Token | `your_hubspot_access_token_here` |

## Where They're Used

- **SIMPRO_TEST_URL**: Used in `SimProAPI` class to build API endpoints
- **SIMPRO_TEST_KEY_ID**: Used in Authorization headers for SimPRO API calls
- **HUBSPOT_ACCESS_TOKEN**: Used in Authorization headers for HubSpot API calls

## Railway Configuration

Set these exact variable names in Railway dashboard under your service → Variables.

