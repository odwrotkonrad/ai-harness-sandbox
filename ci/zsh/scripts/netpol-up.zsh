#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"
(( $+commands[cilium] )) || fn-exit-with 1 "${0:t}: cilium CLI not found"

cilium status --context kind-sandbox --wait >/dev/null \
  || fn-exit-with 1 "${0:t}: cilium is not ready; egress would be unenforced"

$kc apply -f $repo_root/ci/k8s/netpol.yml
##[<] 🤖🤖
