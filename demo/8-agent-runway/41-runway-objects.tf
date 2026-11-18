# 테넌트 bucket 리소스가 공유하는 bucket입니다. 리소스마다 `<cluster>/app-<project>-<env>/<name>/` prefix를 씁니다.
resource "aws_s3_bucket" "runway_objects" {
  bucket = "agent-runway-objects"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "runway_objects" {
  bucket                  = aws_s3_bucket.runway_objects.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "runway_objects" {
  bucket = aws_s3_bucket.runway_objects.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    blocked_encryption_types = ["SSE-C"]
  }
}

resource "aws_s3_bucket_policy" "runway_objects" {
  bucket = aws_s3_bucket.runway_objects.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.runway_objects.arn, "${aws_s3_bucket.runway_objects.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.runway_objects]
}

# Agent Runway가 배포 요청 때 올리는 소스 아카이브(`<cluster>/_sources/<Project ID>/<commit SHA>.tar.gz`)는 빌드가 끝나면 필요 없습니다.
# 빌드는 승인 대기(최대 24시간) 뒤에 시작할 수 있으므로 2일 뒤에 지웁니다.
# namespace 이름은 `_`로 시작할 수 없으므로 이 prefix는 테넌트 prefix(`<cluster>/<namespace>/`)와 겹치지 않습니다.
resource "aws_s3_bucket_lifecycle_configuration" "runway_objects" {
  bucket = aws_s3_bucket.runway_objects.id

  rule {
    id     = "expire-source-archives"
    status = "Enabled"

    filter {
      prefix = "${var.cluster_name}/_sources/"
    }

    expiration {
      days = 2
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Sandbox용 1시간 credential. Agent Runway가 AssumeRole하면서 session policy로 리소스 prefix 하나로 좁힙니다.
resource "aws_iam_role" "runway_sandbox_objects" {
  name                 = "agent-runway-sandbox-objects"
  max_session_duration = 3600
  # EKS Pod Identity session tags are transitive, so the chained session needs sts:TagSession.
  assume_role_policy = templatefile("${path.module}/policies/trust/runway-sandbox-objects.json", {
    runway_role_arn = local.runway_role_arn
  })
}

resource "aws_iam_role_policy" "runway_sandbox_objects" {
  name = "objects"
  role = aws_iam_role.runway_sandbox_objects.id
  policy = templatefile("${path.module}/policies/runway-sandbox-objects.json", {
    bucket_arn = aws_s3_bucket.runway_objects.arn
  })
}

# 배포된 테넌트 앱(namespace `app-<project>-<env>`, SA `app`)의 Pod Identity 역할입니다.
# Agent Runway가 bucket 리소스가 있는 namespace에만 association을 만듭니다.
# Pod Identity session tag로 자기 namespace prefix만 허용하므로 역할 하나를 모든 테넌트가 공유합니다.
resource "aws_iam_role" "runway_tenant_objects" {
  name = "agent-runway-tenant-objects"
  assume_role_policy = templatefile("${path.module}/policies/trust/runway-tenant-objects.json", {
    account_id   = local.account_id
    region       = var.region
    cluster_name = var.cluster_name
  })
}

resource "aws_iam_role_policy" "runway_tenant_objects" {
  name = "objects"
  role = aws_iam_role.runway_tenant_objects.id
  # Dedicated buckets of kro S3Bucket (argocd-env-addons charts/kro) are <cluster>-<hash>, tagged with the cluster and the
  # instance namespace, with ABAC on. The name alone does not identify the namespace, so the bucket tags decide, and
  # aws:ResourceAccount keeps a bucket of the same name in another account (bucket names are global) from matching.
  # Dedicated tables of kro DynamoTable are app-<hash>, tagged like the buckets. Only kro and the ACK S3 and DynamoDB
  # controllers set those tags; tenants cannot create Bucket or Table objects or tag the resources.
  policy = templatefile("${path.module}/policies/runway-tenant-objects.json", {
    bucket_arn = aws_s3_bucket.runway_objects.arn
    account_id = local.account_id
    region     = var.region
  })
}
