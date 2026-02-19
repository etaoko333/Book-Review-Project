#!/bin/bash
set -e
exec > /var/log/userdata.log 2>&1

echo "=== App Tier Setup Starting ==="

apt update -y && apt upgrade -y

# Install Node.js 18.x LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs mysql-client git

echo "Node.js: $(node -v) | npm: $(npm -v)"

# Clone the Book Review App
cd /home/ubuntu
git clone https://github.com/pravinmishraaws/book-review-app.git
cd book-review-app/backend

# Install backend dependencies
npm install

# Create .env for backend
cat > .env << 'ENVFILE'
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_PORT=3306
PORT=3001
JWT_SECRET=tovadel-secret-key-2025
NODE_ENV=development
ENVFILE

# Wait for RDS to be available
echo "=== Waiting for RDS ==="
for i in $(seq 1 30); do
  if mysql -h ${db_host} -u ${db_user} -p'${db_password}' -e "SELECT 1;" 2>/dev/null; then
    echo "=== RDS is ready ==="
    break
  fi
  echo "Waiting for RDS... attempt $i"
  sleep 10
done

# Create database
mysql -h ${db_host} -u ${db_user} -p'${db_password}' -e "CREATE DATABASE IF NOT EXISTS ${db_name};"

# Import any SQL files if present
cd /home/ubuntu/book-review-app
for sql_file in $(find . -name "*.sql" 2>/dev/null | head -10); do
  echo "=== Importing $sql_file ==="
  mysql -h ${db_host} -u ${db_user} -p'${db_password}' ${db_name} < "$sql_file" || true
done

# Start backend on port 3001
cd /home/ubuntu/book-review-app/backend
export PORT=3001
export DB_HOST=${db_host}
export DB_USER=${db_user}
export DB_PASS='${db_password}'
export DB_NAME=${db_name}
export JWT_SECRET=tovadel-secret-key-2025

# Backend entry point is src/server.js
if [ -f "src/server.js" ]; then
  nohup node src/server.js > /home/ubuntu/app.log 2>&1 &
elif [ -f "server.js" ]; then
  nohup node server.js > /home/ubuntu/app.log 2>&1 &
elif [ -f "index.js" ]; then
  nohup node index.js > /home/ubuntu/app.log 2>&1 &
fi

echo "=== App Tier Setup Complete — Backend on port 3001 ==="