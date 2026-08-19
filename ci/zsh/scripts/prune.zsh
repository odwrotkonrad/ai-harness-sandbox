#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
export KIND_EXPERIMENTAL_PROVIDER=podman

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"
(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"

source $repo_root/ci/zsh/lib/cluster-lib.zsh

${0:A:h}/machine-up.zsh

fn-sandbox-cluster-exists && kind delete cluster --name sandbox

fn-sandbox-cluster-exists \
  && fn-exit-with 1 "${0:t}: the cluster's nodes are still present after delete"

podman rmi -f localhost:5001/sandbox:local localhost:5001/sandbox-installs:local localhost:5001/sandbox-base:local 2>/dev/null || true
podman image prune -f
##[<] 🤖🤖
