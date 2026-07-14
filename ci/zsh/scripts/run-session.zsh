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

#[why] resolved from 1password at session start when not already in the host env
typeset gitlab_token=${GITLAB_TOKEN-}
if { [[ -z $gitlab_token ]] && (( $+commands[op] )) } {
  gitlab_token=$(op read 'op://ProgrammaticAccess/gitlab/access_token' 2>/dev/null) || gitlab_token=''
}

#[why] restricted GCP SA key (JSON) from 1password: the pod's ADC credential, all che's gcp:// secret source needs to resolve the sandbox gitlab token + ssh key from Secrets Manager
typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://ProgrammaticAccess/sandbox_restricted/sa_key' 2>/dev/null) || gcp_sa_key=''
}

#[why] runtime secret pass, mirrors the macos vm SendEnv flow: host tokens ride the exec into ko's login shell (su -w whitelists them), never baked or stored
#[why] GCP_SA_KEY carries the SA key JSON; the pod login writes it to a file and points GOOGLE_APPLICATION_CREDENTIALS at it (see configs 00-local.zsh)
#[why] container runs as root (overlay mount); su drops into ko's login zsh
#[why] su - resets the env; whitelist the pod's OTEL_* overrides too so claude (shell env > settings.json) and codex (otel SDK reads env) target the in-cluster collector, not the baked localhost default
exec $kc exec -it $SESSION -- env "OP_SERVICE_ACCOUNT_TOKEN=${OP_SERVICE_ACCOUNT_TOKEN-}" "GITLAB_TOKEN=$gitlab_token" "GCP_SA_KEY=$gcp_sa_key" su -w OP_SERVICE_ACCOUNT_TOKEN,GITLAB_TOKEN,GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
