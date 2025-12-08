# Railway Environment Variables

## ❌ Current Railway Variables (WRONG)

These are what Railway currently has, but they don't match what the code expects:

```
SIMPRO_URL=https://yourcompany.simprosuite.com/api/v1.0/companies/4
SIMPRO_API_KEY=your_simpro_api_key_here
HUBSPOT_TOKEN=your_hubspot_token_here
```

## ✅ Required Environment Variables (CORRECT)

The Docker image expects these exact variable names:

```
SIMPRO_TEST_URL=https://yourcompany.simprosuite.com/api/v1.0/companies/4
SIMPRO_TEST_KEY_ID=your_simpro_api_key_here
HUBSPOT_ACCESS_TOKEN=your_hubspot_access_token_here
```

## 🔧 Fix in Railway

1. Go to Railway dashboard → Your service → Variables
2. **Delete** the old variables:
   - `SIMPRO_URL`
   - `SIMPRO_API_KEY`
   - `HUBSPOT_TOKEN`
3. **Add** the correct variables:
   - `SIMPRO_TEST_URL` = `https://yourcompany.simprosuite.com/api/v1.0/companies/4`
   - `SIMPRO_TEST_KEY_ID` = `your_simpro_api_key_here`
   - `HUBSPOT_ACCESS_TOKEN` = `your_hubspot_access_token_here`

## 📝 Note on SIMPRO_TEST_URL

The URL should be the base API URL, not including `/companies/4`. It should be:
```
SIMPRO_TEST_URL=https://yourcompany.simprosuite.com/api/v1.0
```

The code will append endpoints like `/quotes/`, `/timelines/`, etc.

