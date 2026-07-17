#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
#[why] pin the dataplane version (mirrors cluster-up hardcoding the cluster name `sandbox`): bare `cilium install` takes whatever the local CLI defaults to, so two hosts or the same host months apart get different Cilium; this keeps the CNI reproducible / offline-parity. cluster-level, so it lives here, not in oci-images tool-versions.env (pod-image tools)
CILIUM_VERSION=1.19.5

(( $+commands[cilium] )) || fn-exit-with 1 "${0:t}: cilium CLI not found; install it and add to PATH: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli"

#[why] idempotent: skip install when cilium already reports ok (mirrors cluster-up's kind get clusters guard); images pull from quay.io at install time (bootstrap already needs network)
if ! cilium status --context kind-sandbox --wait=false >/dev/null 2>&1; then
  #[why] hubble + openmetrics on: exposes the hubble-metrics endpoint (:9965) the egress dashboard scrapes; kubeProxyReplacement off keeps kube-proxy (simplest kind path); pod egress NATs out via the node docker network (ipv4 masquerade, default); toFQDNs policies enable the dns proxy implicitly
  #[why] ipam.mode=kubernetes + image.pullPolicy=IfNotPresent are the cilium kind-install recommendations: kubernetes ipam is the documented kind default-mode, IfNotPresent skips re-pulling the pinned image on every agent restart (offline goal)
  #[why] destinationContext=dns stamps the resolved FQDN as a `destination` label on flow/drop series (the top-denied-FQDN panel), sourceContext=pod keeps the source pod identity; the flow metric carries `verdict` (FORWARDED/DROPPED) for the allowed-vs-denied split
  cilium install --context kind-sandbox --version $CILIUM_VERSION \
    --set ipam.mode=kubernetes \
    --set image.pullPolicy=IfNotPresent \
    --set kubeProxyReplacement=false \
    --set hubble.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.metrics.enableOpenMetrics=true \
    --set hubble.metrics.enabled="{flow:sourceContext=pod;destinationContext=dns,drop:sourceContext=pod;destinationContext=dns,dns:query;ignoreAAAA}"
fi

cilium status --context kind-sandbox --wait
##[<] 🤖🤖🤖
