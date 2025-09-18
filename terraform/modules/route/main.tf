
resource "aws_route53_record" "web_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"
  ttl     = "300"
  records = [var.ec2_public_ip]
}