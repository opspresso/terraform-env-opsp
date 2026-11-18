# 테넌트 namespace의 SecretStore가 External Secrets 역할에서 assume하는 읽기 역할입니다.
# SecretStore가 session tag `delivery-project`·`delivery-env`를 붙이고, 이 정책은 그 tag의 경로만 허용합니다.
# 따라서 다른 Project의 경로를 참조한 ExternalSecret은 AWS에서 거부됩니다.
# 환경은 Agent Runway 관리자가 콘솔에서 추가하므로 `delivery-env`는 비어 있지 않은 모든 값을 받습니다.
# 값 목록으로 제한하면 새 환경의 SecretStore가 AssumeRole 403으로 실패하고 배포가 verify 단계에서 끝납니다.
resource "aws_iam_role" "runway_tenant_secrets" {
  name = "agent-runway-tenant-secrets"
  # EKS Pod Identity session tags are transitive, so a chained session carries them as well: sts:TagSession allows
  # them next to delivery-project and delivery-env.
  assume_role_policy = templatefile("${path.module}/policies/trust/runway-tenant-secrets.json", {
    external_secrets_role_arn = local.external_secrets_role_arn
  })
}

resource "aws_iam_role_policy" "runway_tenant_secrets" {
  name = "variables"
  role = aws_iam_role.runway_tenant_secrets.id
  policy = templatefile("${path.module}/policies/runway-tenant-secrets.json", {
    account_id   = local.account_id
    region       = var.region
    cluster_name = var.cluster_name
    kms_key_arn  = aws_kms_key.variables.arn
  })
}
