# workspaces: Agent Forge Sandbox Pods.
# Separate because the NodeClass denies all traffic until the policy agent programs a new Pod's
# NetworkPolicy (DefaultDeny), and the taint keeps other Pods off the Sandbox nodes.

locals {
  # A 4-CPU node has room for three 1-CPU/2Gi Pods after kubelet and DaemonSets.
  # One extra node permits replacement; the memory ceiling matches 32Gi r nodes.
  workspaces_node_limit = ceil(var.workspace_max_pods / 3) + 1
}

resource "kubernetes_manifest" "workspaces_node_class" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata   = { name = "workspaces" }
    spec = merge(local.node_class_spec, {
      networkPolicy          = "DefaultDeny"
      networkPolicyEventLogs = "Enabled"
      ephemeralStorage       = { size = "${var.workspace_ephemeral_storage_gib}Gi", iops = 3000, throughput = 125 }
    })
  }
}

resource "kubernetes_manifest" "workspaces_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "workspaces" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = kubernetes_manifest.workspaces_node_class.manifest.metadata.name }
          taints       = [{ key = "agent-forge/workspace", value = "true", effect = "NoSchedule" }]
          requirements = concat(local.node_requirements, [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["m", "r"] },
            { key = "eks.amazonaws.com/instance-cpu", operator = "In", values = ["4"] },
          ])
          expireAfter            = "336h"
          terminationGracePeriod = "10m"
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "5m"
        budgets             = [{ nodes = "1" }]
      }
      limits = { cpu = tostring(local.workspaces_node_limit * 4), memory = "${local.workspaces_node_limit * 32}Gi" }
    }
  }
}
