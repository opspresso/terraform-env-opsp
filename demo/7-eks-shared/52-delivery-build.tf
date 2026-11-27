# delivery-build: container builds of Agent Runway Releases (argocd-env-projects charts/delivery
# files/app-build-v2.yaml). The `build` step selects karpenter.sh/nodepool delivery-<arch> and builds
# the image natively there; no platform is emulated.
# Separate because kaniko keeps the build files and layer snapshots on the node disk (a large build,
# for example Elasticsearch, uses 30 to 60Gi; the step requests 20Gi and is limited to 150Gi), and the
# taint keeps other Pods off. Only the app-build-v2 steps tolerate it. One pool per architecture,
# because the build step selects the pool by name.
# Both pools are empty between builds and use Spot only: a Spot reclaim stops the running build, and
# the step runs again. Build Pods are karpenter.sh/do-not-disrupt, so a drain waits up to the build
# step's two-hour deadline.

locals {
  delivery_build_architectures = {
    # arm64 is the default build architecture. An 8-CPU m node has 32Gi (r 64Gi) for a large build's
    # 12Gi; one node holds about seven small builds (1 CPU, 2Gi). The limit allows four nodes.
    arm64 = { categories = ["m", "r"], cpus = ["8"], max_cpu = 32 }
    amd64 = { categories = ["c", "m", "r"], cpus = ["4", "8"], max_cpu = 16 }
  }
}

resource "kubernetes_manifest" "delivery_build_node_class" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata   = { name = "delivery-build" }
    spec = merge(local.node_class_spec, {
      networkPolicy    = "DefaultAllow"
      ephemeralStorage = { size = "${var.delivery_build_ephemeral_storage_gib}Gi", iops = 3000, throughput = 125 }
    })
  }
}

resource "kubernetes_manifest" "delivery_build_node_pool" {
  for_each = local.delivery_build_architectures

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "delivery-${each.key}" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = kubernetes_manifest.delivery_build_node_class.manifest.metadata.name }
          taints       = [{ key = "opspresso.com/delivery-build", value = "true", effect = "NoSchedule" }]
          requirements = concat(local.node_requirements, [
            { key = "kubernetes.io/arch", operator = "In", values = [each.key] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot"] },
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = each.value.categories },
            { key = "eks.amazonaws.com/instance-cpu", operator = "In", values = each.value.cpus },
          ])
          expireAfter            = "336h"
          terminationGracePeriod = "130m"
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "10m"
        budgets             = [{ nodes = "1" }]
      }
      # m instances have 4Gi and r 8Gi per vCPU.
      limits = { cpu = tostring(each.value.max_cpu), memory = "${each.value.max_cpu * 8}Gi" }
    }
  }
}
