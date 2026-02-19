
# 📚 Book Review App — Three-Tier AWS Architecture

A production-grade, highly available, and secure three-tier architecture deployment of the [Book Review App](https://github.com/pravinmishraaws/book-review-app) on AWS using Terraform.

**TOVADEL Academy | Senior DevOps Engineer Program**
**Author:** Olusola (etaoko333)

---

## 🏗️ Architecture

```
                         INTERNET
                            │
                            ▼
                 ┌─────────────────────┐
                 │   Public ALB (:80)   │  ← Internet-facing
                 └──────────┬──────────┘
                            │
                 ┌──────────▼──────────┐
                 │   Web EC2 (Nginx)    │  ← Next.js + Nginx
                 │   Public Subnet      │     :80 → localhost:3000
                 │                      │     /api/ → Internal ALB
                 └──────────┬──────────┘
                            │
                 ┌──────────▼──────────┐
                 │  Internal ALB (:3001)│  ← VPC-internal only
                 └──────────┬──────────┘
                            │
                 ┌──────────▼──────────┐
                 │   App EC2 (Express)  │  ← Node.js/Express API
                 │   Private Subnet     │     Port 3001
                 └──────────┬──────────┘
                            │
                 ┌──────────▼──────────┐
                 │   RDS MySQL          │  ← Multi-AZ + Read Replica
                 │   Private Subnet     │     Port 3306
                 └─────────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Next.js, Nginx (reverse proxy) |
| **Backend** | Node.js 18.x, Express.js, Sequelize ORM |
| **Database** | Amazon RDS MySQL 8.0 (Multi-AZ + Read Replica) |
| **Infrastructure** | Terraform, AWS (VPC, EC2, ALB, RDS, NAT GW) |
| **OS** | Ubuntu 20.04 LTS |
| **Auth** | JWT (JSON Web Tokens) |

---

## 📁 Project Structure

```
bookreview-terraform/
├── main.tf                 # Core infrastructure (VPC, SGs, ALBs, EC2, RDS)
├── variables.tf            # Input variables
├── outputs.tf              # Output values (IPs, DNS, SG chain)
├── terraform.tfvars        # Variable values (⚠️ not committed — sensitive)
├── userdata-web.sh         # Web EC2 bootstrap (Next.js + Nginx)
├── userdata-app.sh         # App EC2 bootstrap (Node.js + Express)
├── .gitignore              # Excludes sensitive files and Terraform state
└── README.md               # This file
```

---

## 🌐 Network Design

**VPC:** `10.0.0.0/16` across 2 Availability Zones with 6 subnets:

| Tier | Subnet | CIDR | AZ | Type |
|------|--------|------|----|------|
| Web | web-public-a | 10.0.1.0/24 | us-east-1a | Public |
| Web | web-public-b | 10.0.2.0/24 | us-east-1b | Public |
| App | app-private-a | 10.0.11.0/24 | us-east-1a | Private |
| App | app-private-b | 10.0.12.0/24 | us-east-1b | Private |
| DB | db-private-a | 10.0.21.0/24 | us-east-1a | Private |
| DB | db-private-b | 10.0.22.0/24 | us-east-1b | Private |

---

## 🔒 Security Group Chain

Each layer only accepts traffic from the layer directly above it:

```
Internet → Public ALB SG (:80) → Web EC2 SG (:80) → Internal ALB SG (:3001) → App EC2 SG (:3001) → DB SG (:3306)
```

| Security Group | Inbound From | Port |
|---------------|-------------|------|
| Public ALB SG | 0.0.0.0/0 | 80 |
| Web EC2 SG | Public ALB SG | 80 |
| Web EC2 SG | Your IP | 22 |
| Internal ALB SG | Web EC2 SG | 3001 |
| App EC2 SG | Internal ALB SG | 3001 |
| App EC2 SG | Web EC2 SG | 22 |
| DB SG | App EC2 SG | 3306 |

---

## 🚀 Deployment Guide

Follow these steps to deploy the full three-tier architecture from scratch.

### Prerequisites

| Requirement | How to Get It |
|------------|--------------|
| **AWS Account** | [Sign up](https://aws.amazon.com/) — Free Tier eligible |
| **Terraform >= 1.0** | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| **AWS CLI** | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| **EC2 Key Pair** | Create in AWS Console → EC2 → Key Pairs |
| **Git** | [Install Git](https://git-scm.com/downloads) |

---

### Step 1: Configure AWS CLI

```bash
aws configure
```

Enter your AWS Access Key, Secret Key, region (`us-east-1`), and output format (`json`).

Verify it works:

```bash
aws sts get-caller-identity
```

---

### Step 2: Create an EC2 Key Pair

If you don't have one already:

```bash
aws ec2 create-key-pair --key-name mykey --query 'KeyMaterial' --output text > mykey.pem
chmod 400 mykey.pem
```

Or create in **AWS Console** → **EC2** → **Key Pairs** → **Create Key Pair** → Download the `.pem` file.

---

### Step 3: Clone This Repository

```bash
git clone https://github.com/etaoko333/bookreview-terraform.git
cd bookreview-terraform
```

---

### Step 4: Create Your `terraform.tfvars`

This file is excluded from Git for security. Create it manually:

```bash
cat > terraform.tfvars << 'EOF'
aws_region         = "us-east-1"
key_pair_name      = "mykey"
ec2_instance_type  = "t2.micro"
rds_instance_class = "db.t3.micro"
db_name            = "bookreview"
db_username        = "admin"
db_password        = "YourSecurePassword123"
EOF
```

⚠️ **Important:**
- Replace `mykey` with the name of your EC2 key pair
- Use a strong password without special characters like `!` (avoids shell escaping issues)
- **Never commit this file to Git**

---

### Step 5: Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview what will be created (26 resources)
terraform plan

# Deploy everything — type 'yes' when prompted
terraform apply
```

⏳ **This takes 15–20 minutes.** RDS Multi-AZ is the slowest component.

**What gets created:**

| Count | Resources |
|-------|----------|
| 1 | VPC |
| 6 | Subnets (2 public, 4 private) |
| 1 | Internet Gateway |
| 1 | NAT Gateway + Elastic IP |
| 2 | Route Tables (public + private) |
| 5 | Security Groups (SG-to-SG chaining) |
| 2 | Application Load Balancers (Public + Internal) |
| 2 | Target Groups |
| 2 | EC2 Instances (Web + App) |
| 1 | RDS MySQL Multi-AZ Primary |
| 1 | RDS Read Replica |
| **~26** | **Total resources** |

---

### Step 6: Get Your Deployment Info

```bash
terraform output
```

**Save these values** — you'll need them:

```
public_alb_dns       = "http://bookreview-public-alb-XXXXXXXX.us-east-1.elb.amazonaws.com"
internal_alb_dns     = "internal-bookreview-internal-alb-XXXXXXXX.us-east-1.elb.amazonaws.com"
web_ec2_public_ip    = "X.X.X.X"
app_ec2_private_ip   = "10.0.11.X"
rds_primary_hostname = "bookreview-db-primary.XXXXXXXX.us-east-1.rds.amazonaws.com"
```

---

### Step 7: Configure the Backend (App EC2)

The userdata script handles most setup, but you need to verify everything is running.

**SSH to the App EC2 (via Web EC2 bastion):**

The App EC2 is in a private subnet with no public IP. You must hop through the Web EC2:

```bash
# From your laptop — copy key to Web EC2
scp -i "mykey.pem" mykey.pem ubuntu@<WEB_PUBLIC_IP>:/tmp/

# SSH to Web EC2
ssh -i "mykey.pem" ubuntu@<WEB_PUBLIC_IP>

# From Web EC2 — hop to App EC2
chmod 400 /tmp/mykey.pem
ssh -i /tmp/mykey.pem ubuntu@<APP_PRIVATE_IP>
```

**Check if the backend is running:**

```bash
curl -s http://localhost:3001
```

✅ If you see `📚 Book Review API is running...` — skip to Step 8!

❌ If not running, follow the manual fix below:

```bash
cd /home/ubuntu/book-review-app/backend

# Fix the database config — remove SSL (required for AWS RDS)
sudo tee src/config/db.js > /dev/null << 'DBEOF'
const { Sequelize } = require("sequelize");
require("dotenv").config();
const sequelize = new Sequelize(process.env.DB_NAME, process.env.DB_USER, process.env.DB_PASS, {
  host: process.env.DB_HOST,
  dialect: "mysql",
  port: process.env.DB_PORT || 3306,
  logging: false,
});
async function initializeDatabase() {
  try {
    await sequelize.authenticate();
    console.log("Database connected successfully!");
    return sequelize;
  } catch (error) {
    console.error("Database initialization failed:", error);
    process.exit(1);
  }
}
module.exports = initializeDatabase;
DBEOF

# Create the .env file — REPLACE placeholders with YOUR actual values
sudo tee .env > /dev/null << 'ENVEOF'
DB_HOST=<YOUR_RDS_PRIMARY_HOSTNAME>
DB_USER=admin
DB_PASS=<YOUR_RDS_PASSWORD>
DB_NAME=bookreview
DB_PORT=3306
PORT=3001
JWT_SECRET=your-secret-key-change-this
NODE_ENV=development
ALLOWED_ORIGINS=http://<YOUR_PUBLIC_ALB_DNS>,http://localhost:3000
ENVEOF

# Test database connection
mysql -h <YOUR_RDS_HOSTNAME> -u admin -p'<YOUR_PASSWORD>' -e "SELECT 1;"

# Create the database if it doesn't exist
mysql -h <YOUR_RDS_HOSTNAME> -u admin -p'<YOUR_PASSWORD>' -e "CREATE DATABASE IF NOT EXISTS bookreview;"

# Start the backend
nohup node src/server.js &>/dev/null &
sleep 3
curl -s http://localhost:3001
# Should show: 📚 Book Review API is running...
```

⚠️ **Common gotchas:**
- Use `DB_PASS` not `DB_PASSWORD` — the app code reads `process.env.DB_PASS`
- Remove SSL `dialectOptions` from `db.js` — AWS RDS in VPC doesn't need it
- Add your Public ALB DNS to `ALLOWED_ORIGINS` — required for CORS

**Exit back to the Web EC2:**

```bash
exit
```

---

### Step 8: Configure the Frontend (Web EC2)

You should now be on the Web EC2. If not:

```bash
ssh -i "mykey.pem" ubuntu@<WEB_PUBLIC_IP>
```

**Check if the frontend is running:**

```bash
curl -I http://localhost:3000   # Next.js
curl -I http://localhost        # Nginx proxy
```

✅ If both return `200 OK` — skip to Step 9!

❌ If not running, follow the manual fix below:

```bash
cd /home/ubuntu/book-review-app/frontend
sudo chown -R ubuntu:ubuntu /home/ubuntu/book-review-app

# Set the API URL — MUST be the PUBLIC ALB (browser can't reach Internal ALB)
sudo tee .env > /dev/null << 'ENVEOF'
NEXT_PUBLIC_API_URL=http://<YOUR_PUBLIC_ALB_DNS>
PORT=3000
ENVEOF

sudo tee .env.local > /dev/null << 'ENVEOF'
NEXT_PUBLIC_API_URL=http://<YOUR_PUBLIC_ALB_DNS>
ENVEOF

# Build and start Next.js
npm run build
nohup npm start > /tmp/web.log 2>&1 &
sleep 5

# Verify Next.js is running
curl -I http://localhost:3000
```

**Configure Nginx — replace `<YOUR_INTERNAL_ALB_DNS>` with your actual value:**

```bash
sudo tee /etc/nginx/sites-available/bookreview > /dev/null << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    # Frontend — proxy to Next.js on port 3000
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # API calls — proxy to Internal ALB (App Tier)
    location /api/ {
        proxy_pass http://<YOUR_INTERNAL_ALB_DNS>:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINXEOF

# Enable and restart Nginx
sudo ln -sf /etc/nginx/sites-available/bookreview /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

⚠️ **Common gotchas:**
- `NEXT_PUBLIC_API_URL` must point to the **Public ALB** — the browser cannot resolve internal ALB DNS
- Do NOT include `/api` at the end of `NEXT_PUBLIC_API_URL` — the app code adds it automatically
- `NEXT_PUBLIC_` variables are **build-time** — changing `.env` requires `rm -rf .next && npm run build`

---

### Step 9: Test the Full Application

**From the Web EC2 — test the entire chain:**

```bash
# Test Nginx → Next.js
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

# Test Nginx → Internal ALB → Backend → RDS
curl -s http://localhost/api/books
# Expected: JSON array of books

# Test user registration
curl -s http://localhost/api/users/register \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"password123"}'
# Expected: {"message":"User registered successfully"}

# Test login
curl -s http://localhost/api/users/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
# Expected: JSON with token
```

**From your browser:**

1. Open `http://<YOUR_PUBLIC_ALB_DNS>`
2. You should see the Book Review App home page with sample books
3. Click **Register** → Create a new account
4. **Login** with your new credentials
5. Click on any book → **Submit a review**

🎉 **If everything works — congratulations! Your three-tier architecture is live!**

---

## 🔄 How the Request Flow Works

```
1. Browser sends POST to http://<PUBLIC_ALB_DNS>/api/reviews
2. Public ALB → routes to Web EC2 on port 80
3. Nginx → matches /api/ → proxies to Internal ALB on port 3001
4. Internal ALB → routes to App EC2 on port 3001
5. Express.js → validates JWT token → processes the request
6. Sequelize ORM → writes the review to RDS MySQL
7. Response flows back: RDS → Express → Internal ALB → Nginx → Public ALB → Browser
```

The user sees "Review submitted!" — never knowing their request traversed 3 network tiers, 2 load balancers, and a managed database.

---

## 🔑 SSH Quick Reference

| Target | Command |
|--------|---------|
| Web EC2 (direct) | `ssh -i "mykey.pem" ubuntu@<WEB_PUBLIC_IP>` |
| App EC2 (bastion hop) | `ssh -i "mykey.pem" -J ubuntu@<WEB_PUBLIC_IP> ubuntu@<APP_PRIVATE_IP>` |

For the bastion hop, your key must be on the Web EC2:

```bash
scp -i "mykey.pem" mykey.pem ubuntu@<WEB_PUBLIC_IP>:/tmp/
```

---

## ❗ Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Access denied (using password: NO)" | `.env` has `DB_PASSWORD` instead of `DB_PASS` | Change to `DB_PASS` in `.env` |
| "connect ETIMEDOUT" to RDS | SSL `dialectOptions` in `db.js` | Remove the `dialectOptions` block |
| "CORS policy: Not allowed" | Backend doesn't allow Public ALB domain | Add Public ALB to `ALLOWED_ORIGINS` in backend `.env` |
| "ERR_NAME_NOT_RESOLVED" in browser | `NEXT_PUBLIC_API_URL` points to Internal ALB | Change to Public ALB DNS |
| Frontend shows old API URL | `NEXT_PUBLIC_` vars are build-time | `rm -rf .next && npm run build` |
| 502 Bad Gateway | Next.js not running | `nohup npm start > /tmp/web.log 2>&1 &` |
| `/api/api/` double path | `NEXT_PUBLIC_API_URL` includes `/api` | Remove `/api` from the URL |
| Backend runs on wrong EC2 | You're on Web EC2 not App EC2 | Check prompt: should be `ip-10-0-11-XXX` |

---

## 💰 Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| EC2 t2.micro × 2 | ~$17 |
| RDS db.t3.micro Multi-AZ | ~$25 |
| RDS Read Replica | ~$12 |
| NAT Gateway | ~$32 |
| ALB × 2 | ~$32 |
| **Total** | **~$118/month** |

---

## 🧹 Cleanup — IMPORTANT!

When you're done, destroy everything to stop charges:

```bash
terraform destroy
```

Type `yes` when prompted. This removes ALL resources.

⚠️ **Don't forget!** A running NAT Gateway alone costs ~$32/month.

---

## 📝 What You'll Learn

By deploying this project, you'll gain hands-on experience with:

- Designing multi-tier VPC architectures with public and private subnets
- Configuring security group chaining for strict tier isolation
- Setting up Application Load Balancers (internet-facing and internal)
- Deploying RDS MySQL with Multi-AZ failover and Read Replicas
- Configuring Nginx as a reverse proxy for Next.js and API routing
- Using the bastion host pattern for accessing private instances
- Debugging real-world issues: CORS, environment variables, DNS resolution, database connectivity
- Understanding how browser-based apps interact with multi-tier backends

---

## 📄 License

This project is for educational purposes as part of the TOVADEL Academy Senior DevOps Engineer Program.

---

## 🤝 Connect

**Olusola** — Senior DevOps Engineer | Founder, TOVADEL Academy

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)]([https://linkedin.com/in/your-profile](https://www.linkedin.com/in/osenat-alonge-84379124b?lipi=urn%3Ali%3Apage%3Ad_flagship3_profile_view_base_contact_details%3BnPYNF8gfStqAR%2BzzmyOavQ%3D%3D
))
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black)](https://github.com/etaoko333)
