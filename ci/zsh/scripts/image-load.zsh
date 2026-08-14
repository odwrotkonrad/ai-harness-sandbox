#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

docker tag sandbox:local localhost:5001/sandbox:local
docker push localhost:5001/sandbox:local
##[<] 🤖🤖
