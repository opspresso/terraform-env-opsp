# k3s 노드가 공통 애플리케이션을 실행할 때 사용하는 정책

resource "aws_iam_policy" "k3s_ecr_pull" {
  name        = "agent-studio-k3s-ecr-pull"
  description = "ECR pull for the k3s node"
  # 8-agent-studio 가 관리하는 Agent 저장소만 허용한다.
  policy = templatefile("${path.module}/policies/k3s-ecr-pull.json", {
    repository_arns = [for repo in data.aws_ecr_repository.agent : repo.arn]
  })

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "agent-studio-k3s-ecr-pull"
  }
}

resource "aws_iam_policy" "k3s_ssm_read" {
  name        = "agent-studio-k3s-ssm-read"
  description = "Deployment parameters for the k3s node"
  policy = templatefile("${path.module}/policies/k3s-ssm-read.json", {
    region     = local.region
    account_id = local.account_id
  })

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "agent-studio-k3s-ssm-read"
  }
}
