# Delivery build 단계가 이미지를 push할 때 쓰는 역할입니다.
# registry 단계가 session tag `delivery-project`를 붙여 assume하고, 이 정책은 그 Project의 repository만 허용합니다.
# 그래서 build 단계의 앱 코드가 push credential을 읽어도 다른 Project의 이미지는 바꿀 수 없습니다.
resource "aws_iam_role" "push" {
  name                 = "app-delivery-push"
  max_session_duration = 3600
  # EKS Pod Identity session tags are transitive, so a chained session carries them as well: sts:TagSession allows
  # them next to delivery-project.
  assume_role_policy = templatefile("${path.module}/policies/trust/push.json", {
    registry_role_arn = local.registry_role_arn
  })
}

resource "aws_iam_role_policy" "push" {
  name = "project-repository"
  role = aws_iam_role.push.id
  policy = templatefile("${path.module}/policies/push.json", {
    account_id = local.account_id
    region     = var.region
  })
}
