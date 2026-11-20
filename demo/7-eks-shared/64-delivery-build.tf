# Container builds of Agent Runway Releases (argocd-env-projects charts/delivery
# files/app-build-v2.yaml). The `build` step selects karpenter.sh/nodepool
# delivery-<arch> and builds the image natively there; no platform is emulated.
# kaniko runs the Dockerfile in the step's container, so the node disk holds
# the build files and layer snapshots: a large build (for example
# Elasticsearch) uses 30 to 60Gi. The step requests 20Gi and is limited to
# 150Gi. The class uses the role, subnets and security group of the
# EKS-managed default NodeClass, which stays unchanged.
resource "kubernetes_manifest" "delivery_build_node_class" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata   = { name = "delivery-build" }
    spec = {
      role                       = data.terraform_remote_state.eks.outputs.workspace_node_role_name
      subnetSelectorTerms        = [for id in data.terraform_remote_state.eks.outputs.workspace_subnet_ids : { id = id }]
      securityGroupSelectorTerms = [{ id = data.terraform_remote_state.eks.outputs.workspace_security_group_id }]
      networkPolicy              = "DefaultAllow"
      ephemeralStorage = {
        size       = "${var.delivery_build_ephemeral_storage_gib}Gi"
        iops       = 3000
        throughput = 125
      }
    }
  }
}

# Both pools are empty between builds and use Spot only: a Spot reclaim stops
# the running build, and the step runs again. The taint keeps other Pods off;
# only the app-build-v2 steps tolerate it. Build Pods are
# karpenter.sh/do-not-disrupt, so a drain waits up to the build step's
# two-hour deadline.
resource "kubernetes_manifest" "delivery_amd64_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "delivery-amd64" }
    spec = {
      limits = { cpu = "16", memory = "128Gi" }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "10m"
        budgets             = [{ nodes = "1" }]
      }
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = "delivery-build" }
          taints       = [{ key = "opspresso.com/delivery-build", value = "true", effect = "NoSchedule" }]
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["m", "c", "r"] },
            { key = "eks.amazonaws.com/instance-generation", operator = "Gt", values = ["6"] },
            { key = "eks.amazonaws.com/instance-cpu", operator = "In", values = ["4", "8"] },
          ]
          terminationGracePeriod = "130m"
        }
      }
    }
  }
  depends_on = [kubernetes_manifest.delivery_build_node_class]
}

# arm64 is the default build architecture. Before this pool, arm64 builds ran
# on the 2-CPU general and baseline nodes (8 or 16Gi, 80Gi disk). An 8-CPU
# m node has 32Gi (r 64Gi) for a large build's 12Gi; one node holds about
# seven small builds (1 CPU, 2Gi). The limit allows four nodes.
resource "kubernetes_manifest" "delivery_arm64_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "delivery-arm64" }
    spec = {
      limits = { cpu = "32", memory = "256Gi" }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "10m"
        budgets             = [{ nodes = "1" }]
      }
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = "delivery-build" }
          taints       = [{ key = "opspresso.com/delivery-build", value = "true", effect = "NoSchedule" }]
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["m", "r"] },
            { key = "eks.amazonaws.com/instance-generation", operator = "Gt", values = ["6"] },
            { key = "eks.amazonaws.com/instance-cpu", operator = "In", values = ["8"] },
          ]
          expireAfter            = "336h"
          terminationGracePeriod = "130m"
        }
      }
    }
  }
  depends_on = [kubernetes_manifest.delivery_build_node_class]
}
