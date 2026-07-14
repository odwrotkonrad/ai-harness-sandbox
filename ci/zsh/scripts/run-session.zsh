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
typeset session_created=''
if ! $kc get pod $SESSION >/dev/null 2>&1; then
  yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml | $kc apply -f -
  session_created=1
fi

$kc wait --for=condition=Ready pod/$SESSION --timeout=300s

#[why] ONLY the GCP identity is injected: the restricted SA key (JSON) from 1password becomes the pod's ADC. every other sandbox secret (ssh keys, gitlab token) is fetched at runtime IN the pod from GCP Secrets Manager via this ADC, never read on the host and passed in
typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://ProgrammaticAccess/sandbox_restricted/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://ProgrammaticAccess/sandbox_restricted/sa_key empty); the pod's ADC identity is required"

#[why] on create only: re-render *.tpl secrets in the live overlay home so the sandbox's ssh keys resolve from GCP Secrets Manager (gcp:// via the injected ADC). the baked image skips secret renders (MK_DRY_RUN_RENDER_SECRETS), so a fresh pod has no keys until this runs. reattach skips it (keys already on the overlay diff)
#[why] --skip-remote-refs keeps it to the local configs specs (no workspace clone/pull); GCP_SA_KEY=1 restores the op://<->gcp:// discriminator, which 40-gcp-adc unsets after materializing ADC in the same login shell
#[why] whitelist CHE_OTEL_ENDPOINT (set on the pod by session.yml -> sandbox-otelcol:4317) so che's exporter flushes the render's telemetry to the in-cluster collector, not che's baked localhost:4317 default (unreachable -> connection-refused). su - resets the env, so it must be named in -w to survive
if [[ -n $session_created ]] {
  $kc exec $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,CHE_OTEL_ENDPOINT - ko -c \
    'cd ~/projects/gitlab/konradodwrot/configs && GCP_SA_KEY=1 che render-templates --profiles cli/linux --skip-remote-refs'
}

#[why] ONLY GCP_SA_KEY rides the exec: the SA key JSON becomes the pod's ADC (40-gcp-adc writes it to a file, points GOOGLE_APPLICATION_CREDENTIALS at it). the pod resolves every other secret at runtime from GCP Secrets Manager: ssh keys via the create-render above, the gitlab token via fn_auth_glab on first glab call. no op token, no gitlab token injected
#[why] container runs as root (overlay mount); su drops into ko's login zsh
#[why] su - resets the env; whitelist the pod's OTEL_* overrides too so claude (shell env > settings.json) and codex (otel SDK reads env) target the in-cluster collector, not the baked localhost default
exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
