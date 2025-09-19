#!/bin/bash
set -xe

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
              
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repo
add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable"

# Update package index again
apt-get update -y

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install latest Docker Compose v2
DOCKER_CONFIG=/usr/local/lib/docker
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
-o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

ln -s $DOCKER_CONFIG/cli-plugins/docker-compose /usr/bin/docker-compose


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
