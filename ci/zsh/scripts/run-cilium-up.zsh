#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
(( $+commands[cilium] )) || fn-exit-with 1 "${0:t}: cilium CLI not found; install it and add to PATH: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli"

#[why] idempotent: skip install when cilium already reports ok (mirrors run-cluster-up's kind get clusters guard); images pull from quay.io at install time (bootstrap already needs network)
if ! cilium status --context kind-sandbox --wait=false >/dev/null 2>&1; then
  #[why] hubble + openmetrics on: exposes the hubble-metrics endpoint (:9965) the egress dashboard scrapes; kubeProxyReplacement off keeps kube-proxy (simplest kind path); ipv4 masquerade on so pod egress NATs out via the node docker network; toFQDNs policies enable the dns proxy implicitly
  #[why] destinationContext=dns stamps the resolved FQDN as a `destination` label on flow/drop series (the top-denied-FQDN panel), sourceContext=pod keeps the source pod identity; the flow metric carries `verdict` (FORWARDED/DROPPED) for the allowed-vs-denied split
  cilium install --context kind-sandbox \
    --set kubeProxyReplacement=false \
    --set enableIPv4Masquerade=true \
    --set hubble.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.metrics.enableOpenMetrics=true \
    --set hubble.metrics.enabled="{flow:sourceContext=pod;destinationContext=dns,drop:sourceContext=pod;destinationContext=dns,dns:query;ignoreAAAA}"
fi

cilium status --context kind-sandbox --wait
##[<] 🤖🤖🤖
