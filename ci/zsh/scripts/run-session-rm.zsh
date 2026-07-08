#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"
[[ -n ${SESSION-} ]] || fn-exit-with 1 "${0:t}: SESSION required"

$kc delete pod $SESSION --ignore-not-found
$kc delete pvc ${SESSION}-home --ignore-not-found
##[<] 🤖🤖
