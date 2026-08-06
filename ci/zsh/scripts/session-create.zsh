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

#[why] always create from the newest published image: compare sandbox:local's registry digest against the published tag's; pull + load when sandbox:local is missing or a stale pull. a sandbox:local without a registry RepoDigest is a local dev build (image-build): kept, noted. remote unreachable (no docker login / offline) -> note and use what is loaded
typeset tag=${SANDBOX_TAG:-latest}
[[ $(uname -m) == (arm64|aarch64) ]] && tag+=-arm64
typeset image=registry.gitlab.com/konradodwrot/restricted/sandbox/sandbox:$tag
typeset remote_digest=''
if (( $+commands[docker] )) {
  remote_digest=$(docker manifest inspect -v $image 2>/dev/null | yq -p json '.Descriptor.digest' 2>/dev/null) || remote_digest=''
}
typeset local_registry_digest=$(docker image inspect sandbox:local --format '{{join .RepoDigests "\n"}}' 2>/dev/null | sed -n 's#^registry.gitlab.com/konradodwrot/restricted/sandbox/sandbox@##p' | head -1)
if [[ -z $remote_digest || $remote_digest == null ]] {
  print -r -- "${0:t}: could not check the newest published $image; using the loaded sandbox:local"
} elif { ! docker image inspect sandbox:local >/dev/null 2>&1 } {
  ${0:A:h}/image-pull.zsh && ${0:A:h}/image-load.zsh
} elif [[ -n $local_registry_digest && $local_registry_digest != $remote_digest ]] {
  print -r -- "${0:t}: sandbox:local is stale; pulling the newest published $image"
  ${0:A:h}/image-pull.zsh && ${0:A:h}/image-load.zsh
} elif [[ -z $local_registry_digest ]] {
  print -r -- "${0:t}: sandbox:local is a local dev build; keeping it (make image-pull image-load to switch to the published image)"
}

yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml | $kc apply -f -
$kc wait --for=condition=Ready pod/$SESSION --timeout=300s

#[why] ONLY the GCP identity is injected: the restricted SA key (JSON) from 1password becomes the pod's ADC. every other sandbox secret (ssh keys, gitlab token) is fetched at runtime IN the pod from GCP Secrets Manager via this ADC, never read on the host and passed in
typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://ProgrammaticAccess/sandbox_restricted/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://ProgrammaticAccess/sandbox_restricted/sa_key empty); the pod's ADC identity is required"

#[why] on create only: refresh the baked workspace configs checkout to main tip (skipped when dirty: a reused session's local edits are never clobbered; gitlab/projects syncs the rest of the workspace), then run the sandbox-runtime profile against the baked ~/.sandbox-che/che.yml wrapper (filesystem sources into that checkout): gcp/auth fails fast on a broken ADC, ssh/virt renders the keypair from GCP Secrets Manager (gcp:// via the injected ADC), gitlab/projects clones + indexes the workspace. the baked image is secret-free, so a fresh pod has no keys until this runs
#[why] GOOGLE_APPLICATION_CREDENTIALS (exported by 30-adc after materializing ADC in the same login shell) is the op://<->gcp:// template discriminator; GITLAB_TOKEN (gitlab/projects runIf + clone auth) is fetched in-pod from $GITLAB_TOKEN_SECRET_PATH via that ADC, never read on the host
#[why] whitelist CHE_OTEL_ENDPOINT (set on the pod by session.yml -> sandbox-otelcol:4317) so che's exporter flushes the run's telemetry to the in-cluster collector, not che's baked localhost:4317 default (unreachable -> connection-refused). su - resets the env, so it must be named in -w to survive
$kc exec $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,CHE_OTEL_ENDPOINT - ko -c \
  'cd ~/.sandbox-che && cfg=~/projects/gitlab/konradodwrot/configs && { { [[ -z $(git -C $cfg status --porcelain) ]] && git -C $cfg fetch --quiet --depth 1 && git -C $cfg reset --hard --quiet FETCH_HEAD } || print -r -- "session-create: configs refresh skipped (dirty checkout or fetch failed); using the checked-out state" } && GITLAB_TOKEN="$(print -r -- "{{ secret (getenv \"GITLAB_TOKEN_SECRET_PATH\") }}" | render-tpl -f /dev/stdin)" che run --profiles sandbox-runtime'

#[why] ONLY GCP_SA_KEY rides the exec: the SA key JSON becomes the pod's ADC (40-gcp-adc writes it to a file, points GOOGLE_APPLICATION_CREDENTIALS at it). the pod resolves every other secret at runtime from GCP Secrets Manager: ssh keys via the create-render above, the gitlab token via fn_auth_glab on first glab call. no op token, no gitlab token injected
#[why] container runs as root (overlay mount); su drops into ko's login zsh
#[why] su - resets the env; whitelist the pod's OTEL_* overrides too so claude (shell env > settings.json) and codex (otel SDK reads env) target the in-cluster collector, not the baked localhost default
exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,CHE_OTEL_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
