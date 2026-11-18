# GitHub Actions runner image for the ARC scale set eks-arm64
# (argocd-env-addons charts/arc-runners). agent-platform builds it from
# runner/Dockerfile on main; EKS nodes pull it with the node role.
resource "aws_ecr_repository" "actions_runner" {
  name = "actions-runner"
  # Tags carry the commit (<runner version>-<sha>); a pinned tag never changes.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "actions-runner"
  }
}

# docker push stores an image index whose platform manifest has no tag, so a
# rule on untagged images would break pushed tags. Count tagged images only;
# the chart pins the newest build, and older tags remain for rollback.
resource "aws_ecr_lifecycle_policy" "actions_runner" {
  repository = aws_ecr_repository.actions_runner.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 20 most recent tagged images"
      selection = {
        tagStatus      = "tagged"
        tagPatternList = ["*"]
        countType      = "imageCountMoreThan"
        countNumber    = 20
      }
      action = { type = "expire" }
    }]
  })
}

# Only agent-platform main-branch runs can publish the runner image.
resource "aws_iam_role" "github_actions_runner_ecr" {
  name                 = "github--agent-platform-runner-ecr"
  description          = "agent-platform publishes the ARC runner image from main"
  max_session_duration = 3600
  assume_role_policy = templatefile("${path.module}/policies/trust/github-agent-platform-runner.json", {
    oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  })

  tags = {
    Name      = "github--agent-platform-runner-ecr"
    ManagedBy = "Terraform"
    Project   = "agent-platform"
  }
}

resource "aws_iam_role_policy" "github_actions_runner_ecr" {
  name = "ecr-push-actions-runner"
  role = aws_iam_role.github_actions_runner_ecr.name
  policy = templatefile("${path.module}/policies/github-ecr-push-pull.json", {
    repository_arn = aws_ecr_repository.actions_runner.arn
  })
}
