#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
#[why] a session that cannot reach something fails in ways that look like anything but a policy: the
#   first question is always "what did the allowlist refuse". cilium already knows, this puts the
#   answer one target away rather than behind a hand-built agent exec
typeset -a kc=( kubectl --context kind-sandbox )
typeset -i last=${EGRESS_LAST:-200}

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

typeset agent=$($kc -n kube-system get pods -l k8s-app=cilium \
  --field-selector spec.nodeName=sandbox-worker -o name 2>/dev/null | head -1)
[[ -n $agent ]] || fn-exit-with 1 "${0:t}: no cilium agent on the session node; is the cluster up?"

typeset -a observe=( $kc -n kube-system exec ${agent#pod/} -c cilium-agent -- hubble observe )

#[why] the search-domain expansions (<name>.default.svc.cluster.local) are the resolver walking its
#   list, not a rule anyone meant to hit: they drown the real names, so they are filtered out
print -r -- 'DENIED NAMES (bare, search-domain noise filtered)'
$observe --verdict DROPPED --last $last 2>/dev/null \
  | rg -o 'DNS Query [a-z0-9.-]+' \
  | rg -v 'cluster\.local' \
  | sed 's/^DNS Query //' \
  | sort | uniq -c | sort -rn \
  || print -r -- '  none'

print -r -- ''
print -r -- 'DENIED CONNECTIONS (non-DNS)'
$observe --verdict DROPPED --last $last 2>/dev/null \
  | rg -v 'DNS Query|Unsupported L3' \
  | tail -15 \
  || print -r -- '  none'
##[<] 🤖🤖
