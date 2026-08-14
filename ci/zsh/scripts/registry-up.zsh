#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

docker inspect -f '{{.State.Running}}' kind-registry 2>/dev/null | grep -qx true \
  || docker run -d --restart=always --name kind-registry -p 127.0.0.1:5001:5000 registry:2

docker network connect kind kind-registry 2>/dev/null || true
##[<] 🤖🤖
