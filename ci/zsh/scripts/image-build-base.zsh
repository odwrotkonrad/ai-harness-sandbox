#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

${0:A:h}/machine-up.zsh

#[why] the Dockerfile pins CHE_REF to a released version: "latest" is a stale package nothing
#   republishes, so it holds a build predating schema features the configs profiles use. leaving
#   CHE_REF unset here keeps that pin as the single place the version is declared
podman build \
  --file $repo_root/ci/docker/Dockerfile.base \
  --tag localhost:5001/sandbox-base:local \
  $repo_root

podman push --tls-verify=false localhost:5001/sandbox-base:local
##[<] 🤖🤖
