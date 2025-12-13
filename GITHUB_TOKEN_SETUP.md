# GitHub Token Setup for Railway

## Why Do I Need This?

`FileroomProjects/solar-hub-simpro` is a **private repository**, so Railway needs authentication to clone it during the Docker build process.

---

## How to Create GitHub Personal Access Token

### 1. Go to GitHub Settings
Visit: https://github.com/settings/tokens

### 2. Generate New Token
- Click **"Generate new token (classic)"**
- **Name:** `Railway Sync Deployment`
- **Expiration:** Choose "No expiration" or "1 year" or longer
- **Scopes:** Check ☑️ **`repo`** (Full control of private repositories)

### 3. Generate and Copy
- Click **"Generate token"** at the bottom
- **Copy the token** - it starts with `ghp_...`
- ⚠️ **Important:** You won't be able to see this token again!

---

## Add Token to Railway

### 1. Go to Railway Dashboard
Visit your Railway project: https://railway.app

### 2. Add Environment Variable
- Click on your service (`hubspot-sync`)
- Go to **"Variables"** tab
- Click **"+ New Variable"**
- Add:
  ```
  GITHUB_TOKEN=ghp_your_token_here
  ```

### 3. Redeploy
Railway will automatically redeploy with the new variable and the build will succeed.

---

## Security Notes

✅ **Token is only used during build** - It's not stored in the final Docker image  
✅ **Railway encrypts variables** - Your token is secure  
✅ **Limited scope** - Token only has `repo` access, nothing else  
✅ **Production app is safe** - Sync runs in completely separate Railway service

---

## Alternative: Make Repo Public

If `FileroomProjects/solar-hub-simpro` doesn't contain sensitive data, you can:

1. Go to: https://github.com/FileroomProjects/solar-hub-simpro/settings
2. Scroll to **"Danger Zone"**
3. Click **"Change repository visibility"** → **"Make public"**

Then you won't need a GitHub token at all! 🎉





