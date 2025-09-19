#!/bin/bash
set -xe

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Apache for Certbot validation
sudo apt-get install -y apache2

# ENABLE REQUIRED APACHE MODULES FIRST
sudo a2enmod rewrite ssl proxy proxy_http

# Create TEMPORARY Apache config for initial setup
sudo tee /etc/apache2/sites-available/dream-site.conf > /dev/null << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    DocumentRoot /var/www/html
    
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
sudo apache2ctl configtest
sudo systemctl restart apache2
sudo systemctl enable apache2

# Install Certbot
sudo apt-get install -y certbot python3-certbot-apache

# Function to retry Certbot
install_ssl_certificate() {
    local max_attempts=12
    local attempt=1
    local wait_time=10
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: Trying to obtain SSL certificate..."
        
        if sudo certbot --apache --non-interactive --agree-tos --email admin@temmytope.online \
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
    
    # NOW MODIFY THE CERTBOT-GENERATED CONFIG (don't overwrite it!)
    # Add Docker proxy to the existing Certbot SSL config
    sudo tee -a /etc/apache2/sites-available/dream-site-le-ssl.conf > /dev/null << 'EOL'

    # Docker proxy configuration (added by script)
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    <Proxy *>
        Require all granted
    </Proxy>
EOL

    # Also update the non-SSL config to redirect properly
    sudo tee /etc/apache2/sites-available/dream-site.conf > /dev/null << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    Redirect permanent / https://dream.temmytope.online/
</VirtualHost>
EOL

    # Test configuration and restart
    sudo apache2ctl configtest
    sudo systemctl restart apache2
    echo "🎉 Apache configured with SSL and Docker proxy successfully!"
else
    echo "⚠️ SSL setup failed, but Apache is running with basic config"
fi