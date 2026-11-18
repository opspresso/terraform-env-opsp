# Release identities are separate from runtime Pod Identity and node pull access.
locals {
  github_ecr_publishers = {
    agent-studio = {
      repository_id = "1307383317"
      description   = "github--agent-studio-ecr role"
      legacy_trust  = true
    }
    agent-memory = {
      repository_id = "1345706960"
      description   = "agent-memory ECR push from GitHub Actions OIDC"
      legacy_trust  = true
    }
    agent-knowledge = {
      repository_id = "1363501685"
      description   = "agent-knowledge release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
    agent-forge = {
      repository_id = "1379377605"
      description   = "agent-forge release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
    agent-runway = {
      repository_id = "1434015347"
      description   = "agent-runway release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
    agent-models = {
      repository_id = "1339315923"
      description   = "agent-models release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
    agentops = {
      repository_id = "1462895516"
      description   = "agentops release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
    rovr = {
      repository_id = "1438204517"
      description   = "rovr release ECR push from GitHub Actions OIDC"
      legacy_trust  = false
    }
  }
  github_ecr_subject_prefixes = {
    for repository, publisher in local.github_ecr_publishers : repository =>
    "repo:opspresso@38965494/${repository}@${publisher.repository_id}"
  }
}

data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_ecr" {
  for_each = local.github_ecr_publishers

  name                 = "github--${each.key}-ecr"
  description          = each.value.description
  max_session_duration = 3600
  # The two imported roles keep their existing trust. New publishers only accept immutable repository subjects and v*
  # release tags.
  assume_role_policy = templatefile(
    "${path.module}/policies/trust/${each.value.legacy_trust ? "github-ecr-release-legacy" : "github-ecr-release"}.json",
    {
      oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
      subject_prefix    = local.github_ecr_subject_prefixes[each.key]
      repository        = each.key
    },
  )

  tags = {
    Name      = "github--${each.key}-ecr"
    ManagedBy = "Terraform"
    Project   = each.key
  }
}

resource "aws_iam_policy" "github_ecr" {
  for_each = { for repository, publisher in local.github_ecr_publishers : repository => publisher if repository != "agent-memory" }

  name = "github--${each.key}-ecr"
  # Forge verifies its published Sandbox by pulling and running that image.
  policy = templatefile("${path.module}/policies/${each.key == "agent-forge" ? "github-ecr-push-pull" : "github-ecr-push"}.json", {
    repository_arn = aws_ecr_repository.this[each.key].arn
  })

  tags = {
    Name      = "github--${each.key}-ecr"
    ManagedBy = "Terraform"
    Project   = each.key
  }
}

resource "aws_iam_role_policy_attachment" "github_ecr" {
  for_each = aws_iam_policy.github_ecr

  role       = aws_iam_role.github_ecr[each.key].name
  policy_arn = each.value.arn
}

# Memory already has an inline policy. Import it without a detach/reattach or
# changing its existing image-layer read permission during adoption.
resource "aws_iam_role_policy" "github_ecr_memory" {
  name = "ecr-push-agent-memory"
  role = aws_iam_role.github_ecr["agent-memory"].name
  policy = templatefile("${path.module}/policies/github-ecr-push-pull.json", {
    repository_arn = aws_ecr_repository.this["agent-memory"].arn
  })
}

import {
  for_each = toset(["agent-studio", "agent-memory"])
  to       = aws_iam_role.github_ecr[each.key]
  id       = "github--${each.key}-ecr"
}

import {
  to = aws_iam_policy.github_ecr["agent-studio"]
  id = "arn:aws:iam::396608815058:policy/github--agent-studio-ecr"
}

import {
  to = aws_iam_role_policy_attachment.github_ecr["agent-studio"]
  id = "github--agent-studio-ecr/arn:aws:iam::396608815058:policy/github--agent-studio-ecr"
}

import {
  to = aws_iam_role_policy.github_ecr_memory
  id = "github--agent-memory-ecr:ecr-push-agent-memory"
}
