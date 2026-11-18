resource "aws_iam_role" "this" {
  for_each = local.pod_identities

  name = format("%s--%s", local.prefix_name, each.key)
  # Only EKS Pod Identity of this account can assume the roles.
  assume_role_policy = templatefile("${path.module}/policies/trust/pod-identity.json", { account_id = local.account_id })

  tags = {
    Name = format("%s--%s", local.prefix_name, each.key)
  }
}

resource "aws_iam_policy" "this" {
  for_each = local.pod_identities

  name        = format("%s--%s", local.prefix_name, each.key)
  description = format("%s--%s -- pod identity", local.prefix_name, each.key)
  policy      = file(format("%s/policies/%s.json", path.module, each.key))

  tags = {
    Name = format("%s--%s", local.prefix_name, each.key)
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.pod_identities

  role       = aws_iam_role.this[each.key].name
  policy_arn = aws_iam_policy.this[each.key].arn
}
