#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
export SESSION=${SESSION:-s-$(date +%Y%m%d-%H%M%S)}
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"
(( $+commands[yq] )) || fn-exit-with 1 "${0:t}: yq not found"

#[why] pod + pvc applied only when the pod is absent: reattach hits the running pod untouched
if ! $kc get pod $SESSION >/dev/null 2>&1; then
  yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml | $kc apply -f -
fi

$kc wait --for=condition=Ready pod/$SESSION --timeout=300s
#[why] container runs as root (overlay mount); su drops into ko's login zsh
exec $kc exec -it $SESSION -- su - ko
##[<] 🤖🤖🤖
