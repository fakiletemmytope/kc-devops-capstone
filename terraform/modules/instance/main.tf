resource "aws_instance" "ec2" {
  ami           = var.ami
  instance_type = var.instance_type
  tags = {
    Name = var.ec2_name
  }

  subnet_id = var.subnet_id
  key_name = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  user_data = <<-EOF
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

              EOF


}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "ec2-sg"
  }
}
