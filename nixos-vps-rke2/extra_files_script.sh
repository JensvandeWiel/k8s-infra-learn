#!/usr/bin/env bash
set -euo pipefail

mkdir -p ./var/lib/rancher/rke2/server/manifests
cat > ./var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: "localhost"
    k8sServicePort: "6443"
    operator:
      replicas: 1
EOF