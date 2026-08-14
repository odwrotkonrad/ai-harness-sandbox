#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
CILIUM_VERSION=1.19.5

(( $+commands[cilium] )) || fn-exit-with 1 "${0:t}: cilium CLI not found; install it and add to PATH: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli"

if ! cilium status --context kind-sandbox --wait=false >/dev/null 2>&1; then
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
