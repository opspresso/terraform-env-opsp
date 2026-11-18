# argocd-env-addons CI pulls the ACK charts from oci://public.ecr.aws. Anonymous pulls share a per-IP data limit
# with every other GitHub-hosted runner and fail with 429; an authenticated pull does not have that limit.
# The role can only get the ECR Public pull token. Only main-branch runs (push and manual validate) can assume it.
resource "aws_iam_role" "github_ecr_public_pull" {
  name                 = "github--argocd-env-addons-ecr-public"
  description          = "argocd-env-addons CI pulls public.ecr.aws charts with an authenticated token"
  max_session_duration = 3600
  # The repository uses the default subject format (immutable subjects are off).
  assume_role_policy = templatefile("${path.module}/policies/trust/github-argocd-env-addons.json", {
    oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  })

  tags = {
    Name = "github--argocd-env-addons-ecr-public"
  }
}

resource "aws_iam_role_policy" "github_ecr_public_pull" {
  name   = "ecr-public-pull-token"
  role   = aws_iam_role.github_ecr_public_pull.name
  policy = file("${path.module}/policies/github-ecr-public-pull.json")
}
