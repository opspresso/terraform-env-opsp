resource "aws_iam_user" "smtp" {
  name = "${local.name}-smtp"
}

resource "aws_iam_user_policy" "smtp" {
  name = "send-admin-mail-only"
  user = aws_iam_user.smtp.name
  policy = templatefile("${path.module}/policies/smtp.json", {
    identity_arn = aws_sesv2_email_identity.mail.arn
    from_address = local.address
  })
}
