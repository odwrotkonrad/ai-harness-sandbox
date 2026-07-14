#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

#[why] no SESSION -> attach to the most recent running session (newest pod by creation time); with SESSION, attach to that one
if [[ -z ${SESSION-} ]] {
  SESSION=$($kc get pods -l app=claude-sandbox --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1 | cut -d/ -f2)
  [[ -n $SESSION ]] || fn-exit-with 1 "${0:t}: no running session to attach to; use session-create"
}

$kc get pod $SESSION >/dev/null 2>&1 || fn-exit-with 1 "${0:t}: session $SESSION not running; use session-create"

#[why] ONLY the GCP identity is injected: the restricted SA key (JSON) from 1password becomes the pod's ADC; the pod resolves every other secret at runtime from GCP Secrets Manager. attach skips the create-render (keys already on the overlay diff)
typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://ProgrammaticAccess/sandbox_restricted/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://ProgrammaticAccess/sandbox_restricted/sa_key empty); the pod's ADC identity is required"

#[why] su - resets the env; whitelist the pod's OTEL_* overrides so claude (shell env > settings.json) and codex (otel SDK reads env) target the in-cluster collector, not the baked localhost default
exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,CHE_OTEL_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
