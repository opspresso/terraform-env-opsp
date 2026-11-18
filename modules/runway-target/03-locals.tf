locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region
  # Every stack of this Target is runway-<project>-<environment>; the session tags name the one a session may change.
  stack_name = "runway-$${aws:PrincipalTag/delivery-project}-$${aws:PrincipalTag/delivery-env}"
}
