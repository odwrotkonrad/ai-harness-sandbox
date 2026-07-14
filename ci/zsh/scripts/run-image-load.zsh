#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

#[why] push to the host registry instead of streaming the whole image tar: docker uploads only layers the registry lacks ("Layer already exists" for the rest), so iterative builds transfer just the changed top layer
docker tag sandbox:local localhost:5001/sandbox:local
docker push localhost:5001/sandbox:local
##[<] 🤖🤖
