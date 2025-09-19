#!/bin/bash
set -xe

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Apache for Certbot validation
sudo apt-get install -y apache2

# ENABLE REQUIRED APACHE MODULES FIRST - IN THE CORRECT ORDER
sudo a2enmod rewrite
sudo a2enmod ssl
sudo a2enmod proxy
sudo a2enmod proxy_http

# Create TEMPORARY Apache config without SSL (for initial Certbot setup)
sudo tee /etc/apache2/sites-available/dream-site.conf > /dev/null << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    DocumentRoot /var/www/html
    
    # For Certbot validation - use simple redirect without rewrite module
    Redirect permanent / https://dream.temmytope.online/
    
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# Enable site and restart Apache
sudo a2dissite 000-default.conf 2>/dev/null || true
sudo a2ensite dream-site.conf

# Test Apache configuration first
sudo apache2ctl configtest

# Start Apache (should work now with simple config)
sudo systemctl restart apache2
sudo systemctl enable apache2

# Install Certbot
sudo apt-get install -y certbot python3-certbot-apache

# Function to retry Certbot with exponential backoff
install_ssl_certificate() {
    local max_attempts=12
    local attempt=1
    local wait_time=10
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: Trying to obtain SSL certificate..."
        
        if sudo certbot --apache --non-interactive --agree-tos --email admin@temmytope.online \
            -d dream.temmytope.online \
            -d www.dream.temmytope.online \
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
    echo "Run manually: sudo certbot --apache -d dream.temmytope.online"
    return 1
}

# Wait for DNS propagation and try Certbot
echo "Waiting for DNS propagation (30 seconds)..."
sleep 30

# Install SSL certificate with retries
if install_ssl_certificate; then
    echo "✅ SSL certificate installed successfully!"
    
    # NOW create the final Apache config with SSL and rewrite rules
    sudo tee /etc/apache2/sites-available/dream-site.conf > /dev/null << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    
    # Use Redirect instead of RewriteRule (doesn't require rewrite module)
    Redirect permanent / https://dream.temmytope.online/
</VirtualHost>

<VirtualHost *:443>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/dream.temmytope.online/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/dream.temmytope.online/privkey.pem
    
    # Proxy all requests to Docker application
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Additional proxy settings
    <Proxy *>
        Require all granted
    </Proxy>
</VirtualHost>
EOL

    # Test configuration again
    sudo apache2ctl configtest
    
    # Restart Apache with final config
    sudo systemctl restart apache2
    echo "🎉 Apache configured with SSL successfully!"
else
    echo "⚠️ SSL setup failed, but Apache is running with basic config"
fi