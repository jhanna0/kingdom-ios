# AWS Deployment Guide

## Option 1: AWS App Runner (Recommended - Easiest)

### Prerequisites
- AWS Account
- GitHub repo with your code
- AWS CLI installed (optional, can use console)

### Step 1: Create RDS PostgreSQL Database

```bash
# Via AWS Console:
# 1. Go to RDS Console
# 2. Create Database → PostgreSQL
# 3. Choose "Free tier" or "Dev/Test"
# 4. Set master username/password
# 5. Make note of endpoint URL
# 6. Security group: Allow inbound on port 5432 from your VPC
```

Or via CLI:
```bash
aws rds create-db-instance \
    --db-instance-identifier kingdom-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username admin \
    --master-user-password YOUR_PASSWORD \
    --allocated-storage 20 \
    --publicly-accessible
```

### Step 2: Deploy with App Runner

#### Option A: Deploy from GitHub (Easiest - Auto Deploy on Push)

1. **Via AWS Console:**
   - Go to AWS App Runner
   - Click "Create service"
   - Source: "Source code repository"
   - Connect your GitHub account
   - Select your `kingdom` repository
   - Branch: `main` (or your branch)
   - Build settings:
     - Runtime: Python 3.11
     - Build command: `pip install -r api/requirements.txt`
     - Start command: `uvicorn main:app --host 0.0.0.0 --port 8000`
     - Working directory: `api`

2. **Configure:**
   - Environment variables:
     ```
     DATABASE_URL=postgresql://admin:PASSWORD@your-rds-endpoint:5432/kingdom
     JWT_SECRET_KEY=your-secret-key-here
     PORT=8000
     ```
   - Auto deployments: Enable
   - Health check: `/`

3. **Deploy!** - Takes 5-10 minutes first time

#### Option B: Deploy from Container (More Control)

1. **Build and push to ECR:**
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Create ECR repository
aws ecr create-repository --repository-name kingdom-api

# Build and push
docker build -t kingdom-api .
docker tag kingdom-api:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/kingdom-api:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/kingdom-api:latest
```

2. **Create App Runner service from ECR:**
   - Source: Container registry
   - Select your ECR image
   - Set environment variables (same as above)

### Step 3: Update Your iOS App

Update `Config.swift`:
```swift
static let apiBaseURL = "https://YOUR_APP.us-east-1.awsapprunner.com"
```

### Updating Your API

**With GitHub auto-deploy:**
```bash
git add .
git commit -m "Update API"
git push
# App Runner automatically deploys in 1-2 minutes!
```

**With ECR (manual):**
```bash
docker build -t kingdom-api .
docker tag kingdom-api:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/kingdom-api:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/kingdom-api:latest
# Then trigger deployment in App Runner console or wait for auto-deploy
```

### Costs
- **App Runner:** ~$0.064/hour when running (~$46/month if always on, or ~$5-10/month with auto-pause)
- **RDS db.t3.micro:** Free tier for 1 year, then ~$15/month
- **Data transfer:** Usually negligible for testing

---

## Option 2: AWS Lightsail Containers

### Step 1: Create Lightsail Container Service

```bash
# Install AWS CLI and Lightsail plugin
aws lightsail create-container-service \
    --service-name kingdom-api \
    --power small \
    --scale 1
```

Or via Console:
1. Go to Lightsail → Containers
2. Create container service
3. Choose power: Nano ($7/month) or Micro ($10/month)

### Step 2: Create Lightsail Database

```bash
aws lightsail create-relational-database \
    --relational-database-name kingdom-db \
    --relational-database-bundle-id micro_2_0 \
    --master-database-name kingdom \
    --master-username admin
```

### Step 3: Deploy Container

```bash
# Build locally
docker build -t kingdom-api .

# Push to Lightsail
aws lightsail push-container-image \
    --service-name kingdom-api \
    --label kingdom-api \
    --image kingdom-api

# Create deployment
aws lightsail create-container-service-deployment \
    --service-name kingdom-api \
    --containers file://lightsail-deployment.json
```

Create `lightsail-deployment.json`:
```json
{
  "kingdom-api": {
    "image": ":kingdom-api.latest",
    "ports": {
      "8000": "HTTP"
    },
    "environment": {
      "DATABASE_URL": "postgresql://admin:password@your-db-endpoint:5432/kingdom",
      "JWT_SECRET_KEY": "your-secret-key"
    }
  }
}
```

### Updating
```bash
docker build -t kingdom-api .
aws lightsail push-container-image --service-name kingdom-api --label kingdom-api --image kingdom-api
# Then create new deployment
```

---

## Option 3: ECS Fargate (More Complex, Production-Grade)

Only recommended if you need:
- Fine-grained control
- Complex networking
- Integration with other AWS services

Setup is more involved - let me know if you want this guide.

---

## Recommended: AWS App Runner with GitHub Auto-Deploy

**Why:** 
- ✅ Push code → Auto deploys (perfect for your "constantly changing" requirement)
- ✅ Easiest to maintain
- ✅ Built-in HTTPS
- ✅ Scales automatically
- ✅ Only pay when running

**Next Steps:**
1. Push your code to GitHub
2. Create RDS database (5 min)
3. Create App Runner service (5 min)
4. Done! Every push auto-deploys

Need help with any specific step?

