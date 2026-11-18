locals {
  account_id = data.aws_caller_identity.current.account_id
  # 4-role이 만든 Delivery registry 단계의 Pod Identity 역할. 이름 규칙은 4-role의 `pod-role--<policy>`입니다.
  registry_role_arn = "arn:aws:iam::${local.account_id}:role/pod-role--app-delivery"

  tags = {
    Environment = "demo"
    ManagedBy   = "Terraform"
    Project     = "terraform-env-demo/demo/8-app-delivery"
  }
}
