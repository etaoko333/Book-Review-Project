#!/bin/bash
set -e
exec > /var/log/userdata.log 2>&1

echo "=== Web Tier Setup Starting ==="

apt update -y && apt upgrade -y

# Install Node.js 18.x LTS + Nginx
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs nginx git

systemctl enable nginx

echo "Node.js: $(node -v) | npm: $(npm -v)"

# Clone the Book Review App
cd /home/ubuntu
git clone https://github.com/pravinmishraaws/book-review-app.git
cd book-review-app/frontend

# Install frontend dependencies
npm install

# Create .env for Next.js frontend
cat > .env << 'ENVFILE'
NEXT_PUBLIC_API_URL=http://${internal_alb_dns}:3001
PORT=3000
ENVFILE

# Also create .env.local (Next.js reads this too)
cat > .env.local << 'ENVFILE'
NEXT_PUBLIC_API_URL=http://${internal_alb_dns}:3001
ENVFILE

# Build Next.js for production
npm run build 2>/dev/null || true

# Start Next.js
nohup npm start > /home/ubuntu/web.log 2>&1 &

# Fallback: try dev mode if start fails
sleep 8
if ! curl -s http://localhost:3000 > /dev/null 2>&1; then
  echo "npm start failed, trying dev mode..."
  nohup npm run dev > /home/ubuntu/web.log 2>&1 &
  sleep 8
fi

# Configure Nginx reverse proxy
cat > /etc/nginx/sites-available/bookreview << 'NGINXCONF'
server {
    listen 80;
    server_name _;

    # Frontend → Next.js on port 3000
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # API calls → Internal ALB (App Tier)
    location /api/ {
        proxy_pass http://${internal_alb_dns}:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINXCONF

ln -sf /etc/nginx/sites-available/bookreview /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "=== Web Tier Setup Complete ==="
echo "=== Nginx :80 → Next.js :3000 ==="
echo "=== /api/ → Internal ALB :3001 ==="