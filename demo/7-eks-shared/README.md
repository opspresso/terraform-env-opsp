# 7-eks-shared

여러 opspresso 서비스가 함께 쓰는 `eks-demo`(terraform-env-demo `demo/5-eks`)의 전용 리소스를 둔다.

| 파일 | 내용 |
| --- | --- |
| `20-pod-roles.tf`, `policies/<key>.json`, `policies/trust/pod-identity.json` | Pod Identity 역할 `pod-role--<key>`와 정책. 키 목록은 `03-locals.tf`의 `pod_identities` |
| `30-pod-identity.tf` | 위 역할과 ServiceAccount를 잇는 `eks-demo` association |
| `40-github-roles.tf`, `policies/github-*.json`, `policies/trust/github-*.json` | opspresso 저장소 CI가 assume하는 GitHub Actions 역할 |
| `50-workspaces.tf`, `51-rovr-sandboxes.tf`, `52-delivery-build.tf` | 워크로드별 NodeClass·NodePool. 공통 값은 `03-locals.tf`의 `node_class_spec`·`node_requirements` |

역할 이름은 다른 root와 서비스가 이름으로 참조한다(예: `pod-role--agent-runway`, `pod-role--delivery-target`). 이름을 바꾸지 않는다.
이 root는 AWS와 Kubernetes provider를 함께 쓰므로 plan에도 `eks-demo` API 접근 권한이 필요하다.

## Node pool

opspresso 서비스 전용 NodeClass·NodePool을 둔다.
기본 노드(`general`, `general-amd64`, `core-*`)와 GitHub Actions runner pool은 terraform-env-demo `demo/6-eks-node`가 관리한다.
두 root는 같은 구조를 쓴다. 파일은 워크로드마다 `NN-<워크로드>.tf` 하나이고, NodeClass(`<워크로드>_node_class`)와 NodePool(`<워크로드>_node_pool`)을 이 순서로 둔다.
NodePool은 NodeClass·taint·구매 방식·architecture가 다르거나 다른 저장소가 pool 이름을 쓸 때만 나눈다.

| NodePool | 사용처 |
| --- | --- |
| `workspaces` | Agent Forge Sandbox Job(Workspace) |
| `rovr-sandboxes` | rovr sub-agent run |
| `delivery-amd64`, `delivery-arm64` | Agent Runway Release의 컨테이너 build(`linux/amd64`, `linux/arm64`) |

Workspace pool은 기존 Auto Mode node 역할과 private subnet·EKS primary security group을 재사용한다.
`workspaces` NodeClass는 암호화된 160Gi ephemeral disk, `DefaultDeny`와 network policy event log를 사용한다.
전용 taint와 `karpenter.sh/nodepool=workspaces`로 앱·DB와 실행 Pod를 분리하고, pool의 총 한도는
`workspace_max_pods=32`에서는 CPU 48개·메모리 384Gi다. 4-CPU 노드당 1-CPU/2Gi 실행 Pod
3개와 kubelet·DaemonSet 여유를 계산하고 교체용 노드 1개를 허용한다. 노드는 수요가 있을 때만
생성한다. namespace quota와 worker 동시성은 `argocd-env-apps`가 소유하며 같은 용량으로 맞춘다.
노드의 이미지 캐시는 kubelet이 관리하며 Workspace마다 DinD 이미지 사본을 저장하지 않는다.
`argocd-env-addons`의 EKS network policy controller를 먼저 준비한다.

rovr sandbox pool(`rovr-sandboxes`)은 `workspaces` NodeClass를 재사용하고 taint `rovr.dev/sandbox`로
rovr 실행 Pod만 받는다. 실행 Pod는 2 CPU·4Gi를 요청하므로 8-CPU m·r 노드(32Gi 이상)에 3개씩 배치한다.
한도는 `rovr_sandbox_max_pods=6`에서 노드 3대(CPU 24개·메모리 192Gi)이며 교체용 노드 1대를 포함한다.
이 값은 `argocd-env-apps`의 `env/eks-demo.yaml` `rovr.sandbox.max_runs`와 같게 유지한다.
실행 Pod는 `karpenter.sh/do-not-disrupt`를 달고, 노드 drain은 rovr sandbox 마감(90분)까지 기다린다. Spot 회수는 2분 예고 뒤 실행 중인 run을 중단시킨다.

`delivery-amd64`·`delivery-arm64` pool은 Agent Runway Release의 컨테이너 image를 그 architecture에서 native로 build한다(argocd-env-projects `charts/delivery`
`files/app-build-v2.yaml`). `build` step은 nodeSelector `karpenter.sh/nodepool: delivery-<arch>`로 이 pool만 쓴다.
taint `agentops.clush.net/delivery-build`는 `app-build-v2`의 step만 허용하고, build가 없으면 pool은 비어 있다(`WhenEmpty` 10분).
두 pool은 NodeClass `delivery-build`를 쓴다. 기본 NodeClass와 같은 node 역할·subnet·security group을 쓰고, ephemeral disk만 200Gi(`delivery_build_ephemeral_storage_gib`)다.
kaniko가 Dockerfile의 `RUN`을 build 컨테이너 안에서 실행하므로 build 파일과 layer snapshot이 노드 디스크에 쌓인다. 큰 build(예: Elasticsearch)는 30~60Gi를 쓰고, step의 디스크 요청은 20Gi, 한도는 150Gi다.
`delivery-arm64`는 8-CPU m·r 노드(32Gi 이상)이고 한도는 노드 4대(CPU 32개·메모리 256Gi)다. `delivery-amd64`는 4·8-CPU m·c·r 노드이고 한도는 CPU 16개·메모리 128Gi다.
build Pod는 `karpenter.sh/do-not-disrupt`를 달고, 노드 drain은 build step 마감(2시간)과 정리 시간을 더한 130분까지 기다린다.
Spot만 쓰므로 Spot 회수는 실행 중인 build를 중단시키고, step은 다른 노드에서 처음부터 다시 실행한다.

공유 Agent PostgreSQL과 다른 중요 서비스는 terraform-env-demo `demo/6-eks-node`의 on-demand `core-2a`·`core-2c` NodePool에서 실행한다.
