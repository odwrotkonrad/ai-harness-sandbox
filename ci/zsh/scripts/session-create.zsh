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

#[why] create only: refuse to clobber an existing session (attach to it instead)
if $kc get pod $SESSION >/dev/null 2>&1; then
  fn-exit-with 1 "${0:t}: session $SESSION already exists; use session-attach"
fi

yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml | $kc apply -f -
$kc wait --for=condition=Ready pod/$SESSION --timeout=300s

#[why] ONLY the GCP identity is injected: the restricted SA key (JSON) from 1password becomes the pod's ADC. every other sandbox secret (ssh keys, gitlab token) is fetched at runtime IN the pod from GCP Secrets Manager via this ADC, never read on the host and passed in
typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://ProgrammaticAccess/sandbox_restricted/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://ProgrammaticAccess/sandbox_restricted/sa_key empty); the pod's ADC identity is required"

#[why] on create only: pull the baked ~/configs checkout to configs main tip, then run the sandbox-runtime profile against the baked ~/che.yml wrapper (filesystem sources into ~/configs): gcp/auth fails fast on a broken ADC, ssh/virt renders the keypair from GCP Secrets Manager (gcp:// via the injected ADC), gitlab/projects clones + indexes the workspace. the baked image is secret-free, so a fresh pod has no keys until this runs
#[why] GCP_SA_KEY=1 restores the op://<->gcp:// discriminator, which 30-adc unsets after materializing ADC in the same login shell; GITLAB_TOKEN (gitlab/projects runIf + clone auth) is fetched in-pod from $GITLAB_TOKEN_SECRET_PATH via that ADC, never read on the host
#[why] whitelist CHE_OTEL_ENDPOINT (set on the pod by session.yml -> sandbox-otelcol:4317) so che's exporter flushes the run's telemetry to the in-cluster collector, not che's baked localhost:4317 default (unreachable -> connection-refused). su - resets the env, so it must be named in -w to survive
$kc exec $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,CHE_OTEL_ENDPOINT - ko -c \
  'cd ~ && git -C ~/configs fetch --quiet --depth 1 && git -C ~/configs reset --hard --quiet FETCH_HEAD && GCP_SA_KEY=1 GITLAB_TOKEN="$(print -r -- "{{ secret (getenv \"GITLAB_TOKEN_SECRET_PATH\") }}" | render-tpl -f /dev/stdin)" che run --profiles sandbox-runtime'

#[why] ONLY GCP_SA_KEY rides the exec: the SA key JSON becomes the pod's ADC (40-gcp-adc writes it to a file, points GOOGLE_APPLICATION_CREDENTIALS at it). the pod resolves every other secret at runtime from GCP Secrets Manager: ssh keys via the create-render above, the gitlab token via fn_auth_glab on first glab call. no op token, no gitlab token injected
#[why] container runs as root (overlay mount); su drops into ko's login zsh
#[why] su - resets the env; whitelist the pod's OTEL_* overrides too so claude (shell env > settings.json) and codex (otel SDK reads env) target the in-cluster collector, not the baked localhost default
exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,CHE_OTEL_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
