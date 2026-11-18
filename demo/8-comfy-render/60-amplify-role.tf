# IAM — Amplify SSR compute role

resource "aws_iam_role" "amplify_compute" {
  name        = "comfy-render-dev-amplify-compute"
  description = "SSR compute role assumed by the Amplify-hosted app for DynamoDB/S3/SQS access."
  assume_role_policy = templatefile("${path.module}/policies/trust/amplify-compute.json", {
    region         = var.region
    account_id     = local.account_id
    amplify_app_id = local.amplify_app_id
  })

  tags = {
    Name = "comfy-render-dev-amplify-compute"
  }
}

resource "aws_iam_role_policy_attachment" "amplify_app_access" {
  role       = aws_iam_role.amplify_compute.name
  policy_arn = aws_iam_policy.app_access.arn
}
