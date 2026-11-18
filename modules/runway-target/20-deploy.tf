# The deploy role of this Target. The app-deploy-eb and app-remove-eb steps (ServiceAccount delivery-target) assume it
# with the session tags delivery-project and delivery-env, and the policy lets that session change only the stack
# runway-<project>-<environment>, the roles and instance profiles named runway-* with the app boundary, the source
# bundles of that environment and the app records of the Target zone. A Target in another account sends Agent Runway's
# external ID (argocd-env-projects charts/delivery files/target.sh assume_target).
resource "aws_iam_role" "deploy" {
  name                 = "agent-runway-target-deploy"
  max_session_duration = 3600
  # EKS Pod Identity session tags are transitive, so sts:TagSession allows them next to delivery-project and delivery-env.
  # A Target in another account trusts the management account's roles only with Agent Runway's external ID, so another
  # installation that uses the same role names cannot reach this account.
  assume_role_policy = templatefile("${path.module}/policies/trust/deploy.json", {
    target_step_role_arn = var.target_step_role_arn
    external_id          = var.external_id
  })
}

# Elastic Beanstalk creates the environment's Auto Scaling group, load balancer, security groups and alarms with the
# caller's permissions, so the deploy role needs its administrator policy.
resource "aws_iam_role_policy_attachment" "deploy_beanstalk" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
}

resource "aws_iam_role_policy" "deploy" {
  name = "runway-stack"
  role = aws_iam_role.deploy.id
  # LoadBalancerSecurityGroups: in some accounts Elastic Load Balancing checks, with the caller's permissions, that the
  # security groups given to CreateLoadBalancer belong to the VPC. The Elastic Beanstalk administrator policy does not
  # grant this read.
  policy = templatefile("${path.module}/policies/deploy.json", {
    partition           = local.partition
    region              = local.region
    account_id          = local.account_id
    stack_name          = local.stack_name
    app_boundary_arn    = aws_iam_policy.app_boundary.arn
    service_role_arn    = aws_iam_role.service.arn
    artifact_bucket_arn = aws_s3_bucket.artifacts.arn
    hosted_zone_id      = var.hosted_zone_id
    domain              = var.domain
  })
}

# The Elastic Beanstalk administrator policy reaches every application and lets a session pass any role. These denies
# win over it and keep one session to its own Project environment: Elastic Beanstalk changes only to the application
# runway-<project>-<environment>, roles passed only from its own stack (with the app boundary) or the service role,
# and no change to EC2, Auto Scaling, load balancing, CloudWatch or CloudFormation resources tagged for another
# Project environment (the stack tags its environment, and Elastic Beanstalk copies the tags to its resources).
resource "aws_iam_role_policy" "deploy_isolation" {
  name = "runway-isolation"
  role = aws_iam_role.deploy.id
  policy = templatefile("${path.module}/policies/deploy-isolation.json", {
    partition        = local.partition
    region           = local.region
    account_id       = local.account_id
    stack_name       = local.stack_name
    service_role_arn = aws_iam_role.service.arn
  })
}
