output "fqdn" {
  description = "The DNS name of the Route 53 record"
  value       = aws_route53_record.web_record.fqdn
}


output "dns_name" {
  description = "The DNS name of the Route 53 record"
  value       = aws_route53_record.web_record.name
}