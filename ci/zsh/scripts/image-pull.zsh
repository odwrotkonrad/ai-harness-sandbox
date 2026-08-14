#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset tag=${SANDBOX_TAG:-latest}
[[ $(uname -m) == (arm64|aarch64) ]] && tag+=-arm64
typeset image=registry.gitlab.com/konradodwrot/infra/sandbox/sandbox:$tag

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

docker pull $image
docker tag $image sandbox:local
##[<] 🤖🤖
