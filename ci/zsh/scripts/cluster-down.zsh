#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
export KIND_EXPERIMENTAL_PROVIDER=podman

(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"

kind delete cluster --name sandbox
##[<] 🤖🤖
