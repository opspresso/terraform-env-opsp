locals {
  # The backend and remote state blocks cannot read locals and repeat this region.
  region     = "ap-northeast-2"
  account_id = data.aws_caller_identity.current.account_id

  # Role names are <prefix_name>--<key>. Other roots and services refer to these names
  # (e.g. pod-role--agent-runway, pod-role--delivery-target); changing the prefix replaces every role.
  prefix_name = "pod-role"

  # One role per key, with the inline policy policies/<key>.json, bound to the ServiceAccount below.
  pod_identities = {
    "agent-studio" = {
      namespace       = "agent-studio"
      service_account = "agent-studio"
    }
    # Agent Runway manages tenant variables (Secrets Manager), object credentials and tenant Pod Identity.
    "agent-runway" = {
      namespace       = "agent-runway"
      service_account = "agent-runway"
    }
    # Memory and Forge need no AWS data-plane identity. Agent Knowledge stores sources in its own bucket.
    "agent-knowledge" = {
      namespace       = "agent-knowledge"
      service_account = "agent-knowledge"
    }
    "mcp-cloudwatch" = {
      namespace       = "agent-mcps"
      service_account = "mcp-cloudwatch"
    }
    # The Delivery registry step creates projects/* repositories and assumes the per-Project push role.
    "app-delivery" = {
      namespace       = "app-delivery"
      service_account = "delivery-registry"
    }
    # The steps of the VM Target Workflows (argocd-env-projects app-deploy-eb, app-remove-eb) assume the role
    # agent-runway-target-deploy of the environment's account (8-runway-target).
    "delivery-target" = {
      namespace       = "app-delivery"
      service_account = "delivery-target"
    }
    # The checkout step of app-build-v2 reads the source archive that Agent Runway uploaded for a deployment request
    # (agent-runway-objects/<cluster>/_sources/). It holds no Git credential.
    "delivery-source" = {
      namespace       = "app-delivery"
      service_account = "delivery-source"
    }
    # GitLab (argocd-env-addons charts/gitlab) keeps its objects in the opspresso-gitlab-* buckets (8-gitlab).
    # Every GitLab Pod uses the one ServiceAccount gitlab.
    "gitlab" = {
      namespace       = "addon-gitlab"
      service_account = "gitlab"
    }
  }

  # NodeClass and NodePool values shared by the NN-<workload>.tf files. Each file holds one workload:
  # its NodeClass, then its NodePool. A workload gets its own pool only when it needs a different
  # NodeClass, a taint, another capacity type, another architecture or a pool name another repository uses.
  # Auto Mode node role, private subnets and cluster security group from terraform-env-demo 5-eks.
  node_class_spec = {
    role                       = data.terraform_remote_state.eks.outputs.workspace_node_role_name
    subnetSelectorTerms        = [for id in data.terraform_remote_state.eks.outputs.workspace_subnet_ids : { id = id }]
    securityGroupSelectorTerms = [{ id = data.terraform_remote_state.eks.outputs.workspace_security_group_id }]
  }

  # Generation 7 or later. Graviton5 (generation 9) nodes fail eBPF network policy map writes with ENOMEM
  # on the EKS Auto Mode kernel (6.18.62), which blocks Pod traffic.
  node_requirements = [
    { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
    { key = "eks.amazonaws.com/instance-generation", operator = "Gt", values = ["6"] },
    { key = "eks.amazonaws.com/instance-generation", operator = "NotIn", values = ["9"] },
  ]

  tags = {
    Environment = "demo"
    ManagedBy   = "Terraform"
    Project     = "terraform-env-opsp/demo/7-eks-shared"
  }
}
