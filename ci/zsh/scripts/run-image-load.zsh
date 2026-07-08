#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"

#[why] only the worker runs session pods; skip loading the image onto the control-plane
kind load docker-image sandbox:local --name sandbox --nodes sandbox-worker
##[<] 🤖🤖
