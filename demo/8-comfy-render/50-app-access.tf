# IAM — 앱과 워커가 사용하는 공유 정책

resource "aws_iam_policy" "app_access" {
  name = "comfy-render-dev-app-access"
  policy = templatefile("${path.module}/policies/app-access.json", {
    table_arn  = aws_dynamodb_table.this.arn
    bucket_arn = aws_s3_bucket.static.arn
    queue_arn  = aws_sqs_queue.render.arn
  })
}
