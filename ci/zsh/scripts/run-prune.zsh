#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"
(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"

#[why] cluster first: its node containers hold the loaded image copies
kind get clusters 2>/dev/null | grep -qx sandbox && kind delete cluster --name sandbox

docker rmi -f sandbox:local dev-sandbox:local ci-linux:local 2>/dev/null || true
docker image prune -f
docker builder prune -f
##[<] 🤖🤖
