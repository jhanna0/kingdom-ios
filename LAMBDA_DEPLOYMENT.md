# Deploy Kingdom API to AWS Lambda (The Simple Way)

## Why Lambda?
- **Cheap AF**: Pay only for requests, not idle time
- **No servers**: AWS manages everything
- **Auto-scaling**: Handles any traffic
- **Simple**: One command to deploy

## Prerequisites
- AWS CLI installed: `brew install awscli`
- AWS credentials configured: `aws configure`
- Your RDS PostgreSQL endpoint and credentials

## Method 1: Using AWS SAM (Recommended - Easiest)

### Step 1: Install SAM CLI
```bash
brew install aws-sam-cli
```

### Step 2: Build and Deploy
```bash
cd api

# Build
sam build

# Deploy (first time)
sam deploy --guided
```

When prompted:
- Stack name: `kingdom-api`
- AWS Region: (same as your RDS)
- Parameter DatabaseURL: `postgresql://user:pass@your-rds.amazonaws.com:5432/kingdom`
- Parameter JWTSecret: (paste output from: `openssl rand -hex 32`)
- Confirm changes: `y`
- Allow SAM CLI IAM role creation: `y`
- Save arguments to config: `y`

After first deploy, just use:
```bash
sam deploy
```

### Step 3: Get Your API URL
```bash
sam list endpoints --output json
```

## Method 2: Using Serverless Framework (Alternative)

### Step 1: Install Serverless
```bash
npm install -g serverless
```

### Step 2: Deploy
```bash
cd api
serverless deploy
```

## Method 3: Manual with AWS Console (For Understanding)

### Step 1: Create Lambda Function
1. Go to AWS Lambda console
2. Create function → Author from scratch
3. Name: `kingdom-api`
4. Runtime: `Python 3.11`
5. Create function

### Step 2: Package Your Code
```bash
cd api
pip install -r requirements.txt -t ./package
cp -r . ./package/
cd package
zip -r ../lambda_deployment.zip .
cd ..
```

### Step 3: Upload to Lambda
```bash
aws lambda update-function-code \
  --function-name kingdom-api \
  --zip-file fileb://lambda_deployment.zip
```

### Step 4: Set Environment Variables
```bash
aws lambda update-function-configuration \
  --function-name kingdom-api \
  --environment Variables="{
    DATABASE_URL=postgresql://user:pass@your-rds.amazonaws.com:5432/kingdom,
    JWT_SECRET_KEY=your-secret-here,
    DEV_MODE=False
  }"
```

### Step 5: Configure Lambda Settings
In Lambda console:
- Memory: 512 MB (increase if needed)
- Timeout: 30 seconds
- Handler: `main.handler`

### Step 6: Create API Gateway
1. Go to API Gateway console
2. Create HTTP API
3. Add integration → Lambda
4. Select your `kingdom-api` function
5. Deploy

## RDS Security Configuration

**CRITICAL**: Your Lambda needs network access to RDS:

### Option A: Same VPC (Recommended)
1. Put Lambda in same VPC as RDS
2. Lambda Configuration → VPC → Select RDS VPC and subnets
3. RDS security group: Allow PostgreSQL (5432) from Lambda security group

### Option B: Public RDS (Not recommended for production)
1. Make RDS publicly accessible (not secure!)
2. RDS security group: Allow 0.0.0.0/0 (very insecure!)

## Testing

```bash
# Get your API URL from Lambda/API Gateway console
curl https://your-api-id.execute-api.region.amazonaws.com/

# Should return:
# {"status": "online", "service": "Kingdom Game API", "version": "1.0.0"}
```

## Cost Estimate
- **Lambda**: Free tier = 1M requests/month, then $0.20 per 1M requests
- **API Gateway**: $1 per million requests
- **Total for small app**: ~$0-5/month

Compare to:
- EC2: ~$15-30/month (always running)
- Elastic Beanstalk: ~$30/month
- App Runner: ~$25/month

## Troubleshooting

### "Task timed out after 3.00 seconds"
Increase Lambda timeout:
```bash
aws lambda update-function-configuration \
  --function-name kingdom-api \
  --timeout 30
```

### "Unable to connect to database"
- Check VPC configuration
- Check security groups
- Test connection from Lambda console

### "Module not found"
Your dependencies aren't packaged:
```bash
pip install -r requirements.txt -t ./package
```

## Production Checklist
- [ ] Set DEV_MODE=False
- [ ] Use strong JWT_SECRET_KEY
- [ ] Configure CORS properly (not allow_origins=["*"])
- [ ] Set up CloudWatch alarms
- [ ] Enable Lambda reserved concurrency if needed
- [ ] Use RDS Proxy for connection pooling (optional, for high traffic)

## Updates
```bash
# After code changes
cd api
sam build && sam deploy
# or
serverless deploy
```



