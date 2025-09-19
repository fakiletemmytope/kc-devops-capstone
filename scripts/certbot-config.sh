#!/bin/bash
set -xe

# Update packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Certbot (Apache might already be installed from user data)
sudo apt-get install -y certbot python3-certbot-apache

# Function to retry Certbot with exponential backoff
install_ssl_certificate() {
    local max_attempts=12
    local attempt=1
    local wait_time=10
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt: Trying to obtain SSL certificate..."
        
        # Stop Apache temporarily for standalone mode
        sudo systemctl stop apache2
        
        # Use standalone mode - more reliable
        if sudo certbot certonly --standalone --non-interactive --agree-tos --email admin@temmytope.online \
            -d dream.temmytope.online \
            -d www.dream.temmytope.online; then
            echo "SSL certificate obtained successfully!"
            sudo systemctl start apache2
            return 0
        fi
        
        echo "Attempt $attempt failed. Retrying in $wait_time seconds..."
        sleep $wait_time
        wait_time=$((wait_time * 2))
        attempt=$((attempt + 1))
    done
    
    echo "Failed to obtain SSL certificate after $max_attempts attempts"
    echo "Run manually: sudo certbot certonly --standalone -d dream.temmytope.online -d www.dream.temmytope.online"
    return 1
}

# Wait for DNS propagation and try Certbot
echo "Waiting for DNS propagation (30 seconds)..."
sleep 30

# Install SSL certificate with retries
if install_ssl_certificate; then
    echo "✅ SSL certificate setup completed successfully!"
    
    # Now configure Apache with the obtained certificates
    sudo cat > /etc/apache2/sites-available/dream-site.conf << 'EOL'
<VirtualHost *:80>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    Redirect permanent / https://dream.temmytope.online/
</VirtualHost>

<VirtualHost *:443>
    ServerName dream.temmytope.online
    ServerAlias www.dream.temmytope.online
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/dream.temmytope.online/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/dream.temmytope.online/privkey.pem
    
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    <Proxy *>
        Require all granted
    </Proxy>
</VirtualHost>
EOL

    # Enable site and restart Apache
    sudo a2enmod ssl proxy proxy_http rewrite
    sudo a2dissite 000-default.conf 2>/dev/null || true
    sudo a2ensite dream-site.conf
    sudo systemctl restart apache2
    
    echo "🎉 Apache configured with SSL successfully!"
else
    echo "⚠️ SSL setup failed, but continuing..."
    sudo systemctl start apache2  # Ensure Apache is running
fi