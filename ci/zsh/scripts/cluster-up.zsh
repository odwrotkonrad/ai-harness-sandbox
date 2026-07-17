#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"
(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

kind get clusters 2>/dev/null | grep -qx sandbox \
  || kind create cluster --name sandbox --config $repo_root/ci/k8s/kind.yml

#[why] connect the registry now that the kind network exists: registry-up runs before cluster-up, so its own connect no-ops when the network is absent; nodes need kind-registry on the network to resolve the mirror endpoint. tolerate already-connected and a missing registry
docker network connect kind kind-registry 2>/dev/null || true
##[<] 🤖🤖
