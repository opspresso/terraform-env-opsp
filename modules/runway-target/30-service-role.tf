# The Elastic Beanstalk service role of the Target's environments (eb-stack.yaml ServiceRoleArn): enhanced health and
# managed platform updates.
resource "aws_iam_role" "service" {
  name               = "agent-runway-eb-service"
  assume_role_policy = file("${path.module}/policies/trust/service.json")
}

resource "aws_iam_role_policy_attachment" "service" {
  # Keyed by policy name; the value is its path under arn:aws:iam::aws:policy/.
  for_each = {
    AWSElasticBeanstalkEnhancedHealth                   = "service-role/AWSElasticBeanstalkEnhancedHealth"
    AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy = "AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
  }
  role       = aws_iam_role.service.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}
