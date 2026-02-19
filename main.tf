# =============================================================================
# Three-Tier Book Review App — HA & Secure Architecture
# TOVADEL Academy | Senior DevOps Engineer Program
# Author: Olusola (etaoko333)
# =============================================================================
# Tier 1 — Web (Next.js + Nginx)   → Public subnets  → Public ALB
# Tier 2 — App (Node.js/Express)   → Private subnets → Internal ALB
# Tier 3 — DB  (MySQL RDS Multi-AZ + Read Replica) → Private subnets
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

# =============================================================================
# NETWORKING — VPC + 6 Subnets + IGW + NAT + Route Tables
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "bookreview-vpc" }
}

# --- Web Tier Subnets (Public) ---
resource "aws_subnet" "web_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az_a
  map_public_ip_on_launch = true
  tags = { Name = "bookreview-web-public-a" }
}

resource "aws_subnet" "web_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.az_b
  map_public_ip_on_launch = true
  tags = { Name = "bookreview-web-public-b" }
}

# --- App Tier Subnets (Private) ---
resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = local.az_a
  tags = { Name = "bookreview-app-private-a" }
}

resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = local.az_b
  tags = { Name = "bookreview-app-private-b" }
}

# --- DB Tier Subnets (Private) ---
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = local.az_a
  tags = { Name = "bookreview-db-private-a" }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = local.az_b
  tags = { Name = "bookreview-db-private-b" }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "bookreview-igw" }
}

# --- NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "bookreview-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.web_a.id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "bookreview-nat-gw" }
}

# --- Public Route Table (Web Tier) ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "bookreview-public-rt" }
}

resource "aws_route_table_association" "web_a" {
  subnet_id      = aws_subnet.web_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "web_b" {
  subnet_id      = aws_subnet.web_b.id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table (App + DB Tiers) ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "bookreview-private-rt" }
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_b" {
  subnet_id      = aws_subnet.app_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# SECURITY GROUPS — 5 SGs with strict chaining
# =============================================================================

# Public ALB SG
resource "aws_security_group" "public_alb" {
  name        = "bookreview-public-alb-sg"
  description = "Allow HTTP from internet to public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-public-alb-sg" }
}

# Web Tier EC2 SG
resource "aws_security_group" "web" {
  name        = "bookreview-web-sg"
  description = "Allow HTTP from Public ALB + SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from Public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-web-sg" }
}

# Internal ALB SG
resource "aws_security_group" "internal_alb" {
  name        = "bookreview-internal-alb-sg"
  description = "Allow traffic from Web Tier to Internal ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from Web Tier"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-internal-alb-sg" }
}

# App Tier EC2 SG
resource "aws_security_group" "app" {
  name        = "bookreview-app-sg"
  description = "Allow traffic from Internal ALB + SSH from Web Tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from Internal ALB"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  ingress {
    description     = "SSH from Web Tier (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-app-sg" }
}

# DB Tier SG
resource "aws_security_group" "db" {
  name        = "bookreview-db-sg"
  description = "Allow MySQL from App Tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from App Tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-db-sg" }
}

# =============================================================================
# RDS — Multi-AZ Primary + Read Replica
# =============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "bookreview-db-subnet-group"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
  tags       = { Name = "bookreview-db-subnet-group" }
}

resource "aws_db_instance" "primary" {
  identifier     = "bookreview-db-primary"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az            = true
  publicly_accessible = false
  skip_final_snapshot = true
  backup_retention_period = 7

  tags = { Name = "bookreview-db-primary" }
}

resource "aws_db_instance" "replica" {
  identifier          = "bookreview-db-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.rds_instance_class

  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = { Name = "bookreview-db-replica" }
}

# =============================================================================
# INTERNAL ALB — App Tier (private)
# =============================================================================

resource "aws_lb" "internal" {
  name               = "bookreview-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = [aws_subnet.app_a.id, aws_subnet.app_b.id]
  tags               = { Name = "bookreview-internal-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "bookreview-app-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "3001"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,404"
  }

  tags = { Name = "bookreview-app-tg" }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# =============================================================================
# PUBLIC ALB — Web Tier (internet-facing)
# =============================================================================

resource "aws_lb" "public" {
  name               = "bookreview-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb.id]
  subnets            = [aws_subnet.web_a.id, aws_subnet.web_b.id]
  tags               = { Name = "bookreview-public-alb" }
}

resource "aws_lb_target_group" "web" {
  name     = "bookreview-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,301,302"
  }

  tags = { Name = "bookreview-web-tg" }
}

resource "aws_lb_listener" "public" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# =============================================================================
# APP TIER EC2 — Node.js/Express backend in private subnet
# =============================================================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.app_a.id
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/userdata-app.sh", {
    db_host     = aws_db_instance.primary.address
    db_user     = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  }))

  tags = { Name = "bookreview-app-ec2" }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 3001
}
# =============================================================================
# WEB TIER EC2 — Next.js + Nginx in public subnet
# =============================================================================

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.web_a.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/userdata-web.sh", {
    internal_alb_dns = aws_lb.internal.dns_name
  }))

  tags = { Name = "bookreview-web-ec2" }
  depends_on = [aws_lb.internal]
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}