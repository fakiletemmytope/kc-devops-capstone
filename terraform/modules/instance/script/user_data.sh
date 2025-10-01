#!/bin/bash
set -xe

# Log everything to a file for debugging
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script execution at $(date)"

# Update packages
apt-get update -y
apt-get upgrade -y

# Install prerequisites
apt-get install -y \
apt-transport-https \
ca-certificates \
curl \
software-properties-common \
gnupg-agent

# Install cron
apt-get install -y cron

# Install python modules
apt-get install -y python3-pip
pip install boto3 python-dotenv

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repo
echo \
"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
apt-get update -y

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Verify Docker installation
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker installation failed"
    exit 1
else
    echo "Docker installed successfully"
    docker --version
fi

# Test Docker service
if ! systemctl is-active --quiet docker; then
    echo "ERROR: Docker service is not running"
    exit 1
else
    echo "Docker service is running"
fi

# Install Docker Compose v2 plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
-o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create system-wide symlink for docker-compose command
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Verify Docker Compose installation
if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose installation failed"
    exit 1
else
    echo "Docker Compose installed successfully"
    docker compose version
fi

# Test docker group membership for ubuntu user
if ! groups ubuntu | grep -q docker; then
    echo "ERROR: ubuntu user not added to docker group"
    exit 1
else
    echo "ubuntu user added to docker group"
fi


# Install CloudWatch Agent
apt-get install -y amazon-cloudwatch-agent

# Write CloudWatch Agent config (collects CPU metrics)
cat <<EOC > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
"agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
},
"metrics": {
    "append_dimensions": {
    "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
    "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
    }
    }
}
}
EOC

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "User data script completed successfully at $(date)"
echo "All installations verified and services started"
