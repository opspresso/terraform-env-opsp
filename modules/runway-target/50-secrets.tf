# The access role of an account other than Agent Runway's own (agent-platform docs/APP_DELIVERY.md "계정"): Agent
# Runway assumes it with the account's external ID to list the account's choices for an environment (clusters, VPCs,
# subnets, certificates, zones, Elastic Beanstalk platforms) and to write the Variables of this account's machine
# environments to Secrets Manager /agent-runway/<environment>/<slug>/<environment>/ with the account's key. Its access check
# writes and deletes /agent-runway/_runway/access-check. The instances read their own environment's path with their
# stack role.
resource "aws_iam_role" "secrets" {
  count = var.external_id == null ? 0 : 1

  name                 = "agent-runway-target-secrets"
  max_session_duration = 3600
  # EKS Pod Identity session tags are transitive, so the chained session carries them.
  assume_role_policy = templatefile("${path.module}/policies/trust/secrets.json", {
    runway_role_arn = var.runway_role_arn
    external_id     = var.external_id
  })
}

resource "aws_iam_role_policy" "secrets" {
  count = var.external_id == null ? 0 : 1

  name = "variables"
  role = aws_iam_role.secrets[0].id
  # AccountChoices are read-only listings; none of these actions supports resource-level permissions.
  policy = templatefile("${path.module}/policies/secrets.json", {
    partition       = local.partition
    region          = local.region
    account_id      = local.account_id
    target_names    = var.target_names
    secrets_key_arn = var.secrets_key_arn
  })
}
