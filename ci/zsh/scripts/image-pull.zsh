#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset tag=${SANDBOX_TAG:-latest}
#[why] per-arch tags: arm64 images publish with an -arm64 suffix, amd64 owns the bare tag
[[ $(uname -m) == (arm64|aarch64) ]] && tag+=-arm64
#[why] this project's own registry is private: the host needs a prior `docker login registry.gitlab.com` (user creds)
typeset image=registry.gitlab.com/konradodwrot/restricted/sandbox/sandbox:$tag

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

docker pull $image
#[why] retag to the fixed local name session pods reference (imagePullPolicy: Never)
docker tag $image sandbox:local
##[<] 🤖🤖
