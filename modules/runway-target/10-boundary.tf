# The permissions boundary of every role a Runway stack creates (argocd-env-projects charts/delivery
# files/eb-stack.yaml InstanceRole). The deploy role may create roles only with this boundary, so a stack can never
# grant an instance more than this: the Elastic Beanstalk web tier, Agent Runway Variables and Project images.
# The stack's own policy narrows it to one environment's Secrets Manager path and one Project repository. The repositories are in
# the management account; a Target in another account also needs the management registry's policy to allow the pull
# (demo/8-app-delivery).
resource "aws_iam_policy" "app_boundary" {
  name        = "agent-runway-app-boundary"
  description = "Upper limit of the instance roles of Agent Runway Target stacks"
  policy = templatefile("${path.module}/policies/app-boundary.json", {
    partition       = local.partition
    region          = local.region
    account_id      = local.account_id
    target_names    = var.target_names
    secrets_key_arn = var.secrets_key_arn
  })
}
