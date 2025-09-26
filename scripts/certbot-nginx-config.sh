#!/bin/bash
set -xe

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Nginx for Certbot validation
sudo apt-get install -y nginx

# Remove default nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# Create TEMPORARY Nginx config for initial setup
sudo tee /etc/nginx/sites-available/dream-site > /dev/null << 'EOL'
server {
    listen 80;
    server_name dream.temmytope.online;

    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOL

# Enable site and restart Nginx
sudo ln -sf /etc/nginx/sites-available/dream-site /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Install Certbot for Nginx
sudo apt-get install -y certbot python3-certbot-nginx

# Function to retry Certbot
install_ssl_certificate() {
    local max_attempts=12
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: Trying to obtain SSL certificate..."

        if sudo certbot --nginx --non-interactive --agree-tos --email admin@temmytope.online \
            -d dream.temmytope.online \
            --redirect; then
            echo "SSL certificate obtained successfully!"
            return 0
        fi

        echo "Attempt $attempt failed. Retrying in $wait_time seconds..."
        sleep $wait_time
        wait_time=$((wait_time * 2))
        attempt=$((attempt + 1))
    done

    echo "Failed to obtain SSL certificate after $max_attempts attempts"
    return 1
}

# Wait for DNS propagation
echo "Waiting for DNS propagation (30 seconds)..."
sleep 30

# Install SSL certificate
if install_ssl_certificate; then
    echo "✅ SSL certificate installed successfully!"

    # NOW MODIFY THE CERTBOT-GENERATED CONFIG
    # Update the nginx config to include Docker proxy
    sudo tee /etc/nginx/sites-available/dream-site > /dev/null << 'EOL'
server {
    listen 80;
    server_name dream.temmytope.online;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name dream.temmytope.online;

    # SSL configuration (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/dream.temmytope.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dream.temmytope.online/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Docker proxy configuration
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
    }
}
EOL

    # Test configuration and restart
    sudo nginx -t
    sudo systemctl restart nginx
    echo "🎉 Nginx configured with SSL and Docker proxy successfully!"
else
    echo "⚠️ SSL setup failed, but Nginx is running with basic config"
fi

# Enable automatic certificate renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

echo "✅ Certbot auto-renewal timer enabled"
echo "🔄 You can test renewal with: sudo certbot renew --dry-run"
