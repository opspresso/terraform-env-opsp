# rovr-sandboxes: rovr sub-agent runs (argocd-env-apps charts/rovr).
# Separate because only rovr tolerates its taint. It reuses the workspaces NodeClass: same node role,
# subnets, default-deny network policy and encrypted ephemeral disk.

locals {
  # An 8-CPU m node (32Gi; r 64Gi) holds three 2-CPU/4Gi rovr sandboxes after kubelet
  # and DaemonSets. One extra node permits replacement.
  rovr_sandboxes_node_limit = ceil(var.rovr_sandbox_max_pods / 3) + 1
}

resource "kubernetes_manifest" "rovr_sandboxes_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "rovr-sandboxes" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = kubernetes_manifest.workspaces_node_class.manifest.metadata.name }
          taints       = [{ key = "rovr.dev/sandbox", value = "true", effect = "NoSchedule" }]
          requirements = concat(local.node_requirements, [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["m", "r"] },
            { key = "eks.amazonaws.com/instance-cpu", operator = "In", values = ["8"] },
          ])
          expireAfter = "336h"
          # Sandbox Pods are karpenter.sh/do-not-disrupt; a drain waits for a run up to rovr's 90-minute
          # sandbox deadline. A Spot reclaim still interrupts a run after its two-minute notice.
          terminationGracePeriod = "90m"
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "5m"
        budgets             = [{ nodes = "1" }]
      }
      limits = { cpu = tostring(local.rovr_sandboxes_node_limit * 8), memory = "${local.rovr_sandboxes_node_limit * 64}Gi" }
    }
  }
}
