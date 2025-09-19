#!/bin/bash
set -xe

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Apache for Certbot validation
sudo apt-get install -y apache2

# Configure Apache for your domain
sudo cat > /etc/apache2/sites-available/dream-site.conf << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    
    # Redirect all HTTP traffic to HTTPS
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    
    SSLEngine on
    SSLCertificateFile      /etc/letsencrypt/live/dream.temmytope.online/fullchain.pem
    SSLCertificateKeyFile   /etc/letsencrypt/live/dream.temmytope.online/privkey.pem
    
    # Proxy all requests to Docker application
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Additional proxy settings
    <Proxy *>
        Require all granted
    </Proxy>
    
    # Error documents (optional)
    ErrorLog ${APACHE_LOG_DIR}/dream.temmytope.online_error.log
    CustomLog ${APACHE_LOG_DIR}/dream.temmytope.online_access.log combined
</VirtualHost>
EOL

# Enable site and restart Apache
sudo a2dissite 000-default.conf 2>/dev/null || true
sudo a2ensite dream-site.conf
sudo systemctl restart apache2
sudo systemctl enable apache2

# Install Certbot
sudo apt-get install -y certbot python3-certbot-apache

# Function to retry Certbot with exponential backoff
install_ssl_certificate() {
    local max_attempts=12
    local attempt=1
    local wait_time=10
    
    while [ \$attempt -le \$max_attempts ]; do
        echo "Attempt \$attempt: Trying to obtain SSL certificate..."
        
        if certbot --apache --non-interactive --agree-tos --email admin@temmytope.online \
            -d dream.temmytope.online \
            -d www.dream.temmytope.online \
            --redirect; then
            echo "SSL certificate obtained successfully!"
            return 0
        fi
        
        echo "Attempt \$attempt failed. Retrying in \$wait_time seconds..."
        sleep \$wait_time
        wait_time=\$((wait_time * 2))
        attempt=\$((attempt + 1))
    done
    
    echo "Failed to obtain SSL certificate after \$max_attempts attempts"
    echo "Run manually: sudo certbot --apache -d dream.temmytope.online -d dream.temmytope.online"
    return 1
}

# Wait for DNS propagation and try Certbot
echo "Waiting for DNS propagation (30 seconds)..."
sleep 30

# Install SSL certificate with retries
install_ssl_certificate