# Address changes from the per-workload file layout. Remove after every installation has applied them.

moved {
  from = kubernetes_manifest.workspace_node_class
  to   = kubernetes_manifest.workspaces_node_class
}

moved {
  from = kubernetes_manifest.workspace_node_pool
  to   = kubernetes_manifest.workspaces_node_pool
}

moved {
  from = kubernetes_manifest.rovr_sandbox_node_pool
  to   = kubernetes_manifest.rovr_sandboxes_node_pool
}

moved {
  from = kubernetes_manifest.delivery_arm64_node_pool
  to   = kubernetes_manifest.delivery_build_node_pool["arm64"]
}

moved {
  from = kubernetes_manifest.delivery_amd64_node_pool
  to   = kubernetes_manifest.delivery_build_node_pool["amd64"]
}
