module "my_networking" {
  source      = "./modules/network"
  vpc_cidr    = "10.0.0.0/16"
  vpc_name    = "dream-vpc"
  subnet_cidr = "10.0.1.0/24"
  subnet_name = "dream-subnet"
  az          = "us-east-1a"
  igw_name    = "dream-igw"
  rt_name     = "dream-rt"
}


module "my_instance" {
  source        = "./modules/instance"
  ami           = "ami-0360c520857e3138f"
  instance_type = "t2.micro"
  ec2_name      = "dream-instance"
  subnet_id     = module.my_networking.subnet_id
  key_name      = "CN-class"
  vpc_id        = module.my_networking.vpc_id
  domain_name   = "temmytope.online"
}


module "my_cloudwatch" {
  source           = "./modules/cloudwatch"
  cw_name          = "dream_instance_cw"
  cw_agent_profile = "dream_cw_agent"
  instance_id      = module.my_instance.instance_id
}

module "my_route53" {
  source        = "./modules/route"
  subdomain     = "dream"
  domain_name   = "temmytope.online"
  ec2_public_ip = module.my_instance.public_ip
}



# Outputs for deployment workflow
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.my_instance.public_ip
}

output "ec2_public_dns" {
  description = "Public IP address of the EC2 dns"
  value       = module.my_instance.public_dns
}
output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = module.my_instance.instance_id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.my_networking.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.my_networking.subnet_id
}


output "fqdn" {
  description = "Route53 record fqdn"
  value       = module.my_route53.fqdn
}

output "dns_name" {
  description = "Route53 record dns name"
  value       = module.my_route53.dns_name
}
