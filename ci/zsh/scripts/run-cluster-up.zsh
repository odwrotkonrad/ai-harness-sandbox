#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"

kind get clusters 2>/dev/null | grep -qx sandbox \
  || kind create cluster --name sandbox --config $repo_root/ci/k8s/kind.yml
##[<] 🤖🤖
