#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

if [[ -z ${SESSION-} ]] {
  SESSION=$($kc get pods -l app=claude-sandbox --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1 | cut -d/ -f2)
  [[ -n $SESSION ]] || fn-exit-with 1 "${0:t}: no running session to attach to; use session-create"
}

$kc get pod $SESSION >/dev/null 2>&1 || fn-exit-with 1 "${0:t}: session $SESSION not running; use session-create"

typeset tag=${SANDBOX_TAG:-latest}
[[ $(uname -m) == (arm64|aarch64) ]] && tag+=-arm64
typeset image=registry.gitlab.com/konradodwrot/infra/sandbox/sandbox:$tag
typeset pod_digest=$($kc get pod $SESSION -o jsonpath='{.status.containerStatuses[0].imageID}' 2>/dev/null)
pod_digest=${pod_digest##*@}
typeset remote_digest=''
if { (( $+commands[docker] )) && (( $+commands[yq] )) } {
  remote_digest=$(docker manifest inspect -v $image 2>/dev/null | yq -p json '.Descriptor.digest' 2>/dev/null) || remote_digest=''
}
if [[ -z $remote_digest || $remote_digest == null ]] {
  print -r -- "${0:t}: could not verify image freshness against $image"
} elif [[ $pod_digest != $remote_digest ]] {
  print -r -- "${0:t}: pod image is not the newest published $image; update: make session-stop session-create SESSION=$SESSION (home diff survives)"
}

typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key empty); the pod's ADC identity is required"

exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,CHE_OTEL_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
