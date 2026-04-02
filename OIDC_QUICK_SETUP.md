# Quick OIDC Setup Guide - 5 Simple Steps

This is a simplified step-by-step guide to set up OIDC authentication for GitHub Actions with AWS.

---

## Prerequisites

- AWS Account with admin access
- GitHub repository
- AWS CLI installed on your computer

---

## Step 1: Create OIDC Provider in AWS (2 minutes)

Run this command in your terminal:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

✅ **Done!** OIDC provider created.

---

## Step 2: Create Bootstrap IAM Role (5 minutes)

### 2.1 Get your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

Save this number (e.g., `123456789012`)

### 2.2 Create trust policy file

Create a file named `trust-policy.json` and paste this (replace the placeholders):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**Replace:**
- `YOUR_ACCOUNT_ID` → Your AWS account ID from step 2.1
- `YOUR_GITHUB_USERNAME/YOUR_REPO_NAME` → Your GitHub repo (e.g., `john/hackathon-usecase-main`)

### 2.3 Create the role

```bash
aws iam create-role \
  --role-name GitHubActionsBootstrapRole \
  --assume-role-policy-document file://trust-policy.json
```

### 2.4 Create permissions file

Create a file named `permissions.json` and paste this (replace YOUR_ACCOUNT_ID):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:github-actions/*"
    },
    {
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
```

### 2.5 Attach permissions

```bash
aws iam put-role-policy \
  --role-name GitHubActionsBootstrapRole \
  --policy-name SecretsManagerAccess \
  --policy-document file://permissions.json
```

### 2.6 Get the Role ARN (save this!)

```bash
aws iam get-role --role-name GitHubActionsBootstrapRole --query 'Role.Arn' --output text
```

**Copy the output** (e.g., `arn:aws:iam::123456789012:role/GitHubActionsBootstrapRole`)

✅ **Done!** Bootstrap role created.

---

## Step 3: Create AWS Credentials for Each Environment (10 minutes)

### For DEV Environment:

```bash
# 1. Create IAM user
aws iam create-user --user-name github-actions-dev

# 2. Attach admin policy (or use a custom policy)
aws iam attach-user-policy \
  --user-name github-actions-dev \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. Create access key
aws iam create-access-key --user-name github-actions-dev
```

**Save the output** - you'll need `AccessKeyId` and `SecretAccessKey`

### For UAT Environment:

```bash
# 1. Create IAM user
aws iam create-user --user-name github-actions-uat

# 2. Attach admin policy
aws iam attach-user-policy \
  --user-name github-actions-uat \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. Create access key
aws iam create-access-key --user-name github-actions-uat
```

**Save the output**

### For PROD Environment:

```bash
# 1. Create IAM user
aws iam create-user --user-name github-actions-prod

# 2. Attach admin policy
aws iam attach-user-policy \
  --user-name github-actions-prod \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 3. Create access key
aws iam create-access-key --user-name github-actions-prod
```

**Save the output**

✅ **Done!** IAM users and access keys created.

---

## Step 4: Store Credentials in AWS Secrets Manager (5 minutes)

### For DEV:

```bash
aws secretsmanager create-secret \
  --name github-actions/dev/aws-credentials \
  --secret-string '{
    "aws_access_key_id": "PASTE_DEV_ACCESS_KEY_HERE",
    "aws_secret_access_key": "PASTE_DEV_SECRET_KEY_HERE"
  }' \
  --region us-east-1
```

### For UAT:

```bash
aws secretsmanager create-secret \
  --name github-actions/uat/aws-credentials \
  --secret-string '{
    "aws_access_key_id": "PASTE_UAT_ACCESS_KEY_HERE",
    "aws_secret_access_key": "PASTE_UAT_SECRET_KEY_HERE"
  }' \
  --region us-east-1
```

### For PROD:

```bash
aws secretsmanager create-secret \
  --name github-actions/prod/aws-credentials \
  --secret-string '{
    "aws_access_key_id": "PASTE_PROD_ACCESS_KEY_HERE",
    "aws_secret_access_key": "PASTE_PROD_SECRET_KEY_HERE"
  }' \
  --region us-east-1
```

✅ **Done!** Credentials stored in Secrets Manager.

---

## Step 5: Add Secret to GitHub (2 minutes)

### 5.1 Go to GitHub

1. Open your repository on GitHub
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret** (green button)

### 5.2 Add the secret

- **Name**: `AWS_BOOTSTRAP_ROLE_ARN`
- **Value**: Paste the Role ARN from Step 2.6 (e.g., `arn:aws:iam::123456789012:role/GitHubActionsBootstrapRole`)

### 5.3 Click "Add secret"

✅ **Done!** GitHub is configured.

---

## ✅ Verification

Test your setup by running a GitHub Actions workflow:

1. Go to **Actions** tab in GitHub
2. Select any workflow (e.g., "Terraform Deploy")
3. Click **Run workflow**
4. Select environment (dev/uat/prod)
5. Click **Run workflow**

Check the logs - you should see:
- ✅ "Configure AWS Credentials (Bootstrap)" - SUCCESS
- ✅ "Retrieve Secrets from AWS Secrets Manager" - SUCCESS

---

## 🎉 You're Done!

Your setup is complete. GitHub Actions can now:
1. Authenticate with AWS using OIDC (no credentials in GitHub)
2. Retrieve environment-specific credentials from Secrets Manager
3. Deploy infrastructure and applications to AWS

---

## Quick Reference

| What | Where |
|------|-------|
| OIDC Provider | AWS IAM → Identity Providers |
| Bootstrap Role | AWS IAM → Roles → GitHubActionsBootstrapRole |
| Credentials | AWS Secrets Manager → github-actions/{env}/aws-credentials |
| GitHub Secret | GitHub Repo → Settings → Secrets → AWS_BOOTSTRAP_ROLE_ARN |

---

## Troubleshooting

### "Error assuming role"
- Check the trust policy has correct GitHub repo name
- Verify OIDC provider exists in AWS

### "Access denied to Secrets Manager"
- Check bootstrap role has `secretsmanager:GetSecretValue` permission
- Verify secret names are exactly: `github-actions/dev/aws-credentials`

### "Invalid credentials"
- Verify access keys are correct in Secrets Manager
- Check IAM users have necessary permissions

---

## Next Steps

- Review the full documentation: [`AWS_OIDC_SETUP.md`](AWS_OIDC_SETUP.md)
- Check the architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Set up Terraform state: [`STATE_BUCKET_SETUP.md`](STATE_BUCKET_SETUP.md)
