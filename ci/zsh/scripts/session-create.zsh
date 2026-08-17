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

if $kc get pod $SESSION >/dev/null 2>&1; then
  fn-exit-with 1 "${0:t}: session $SESSION already exists; use session-attach"
fi

typeset tag=${SANDBOX_TAG:-latest}
[[ $(uname -m) == (arm64|aarch64) ]] && tag+=-arm64
typeset image=registry.gitlab.com/konradodwrot/infra/sandbox/sandbox:$tag
typeset remote_digest=''
if (( $+commands[docker] )) {
  remote_digest=$(docker manifest inspect -v $image 2>/dev/null | yq -p json '.Descriptor.digest' 2>/dev/null) || remote_digest=''
}
typeset local_registry_digest=$(docker image inspect sandbox:local --format '{{join .RepoDigests "\n"}}' 2>/dev/null | sed -n 's#^registry.gitlab.com/konradodwrot/infra/sandbox/sandbox@##p' | head -1)
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

typeset gcp_sa_key=${GCP_SA_KEY-}
if { [[ -z $gcp_sa_key ]] && (( $+commands[op] )) } {
  gcp_sa_key=$(op read 'op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key' 2>/dev/null) || gcp_sa_key=''
}
[[ -n $gcp_sa_key ]] || fn-exit-with 1 "${0:t}: no GCP SA key (op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key empty); the pod's ADC identity is required"


$kc exec $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,CHE_OTEL_ENDPOINT - ko -c \
  'cd ~/.sandbox-che && cfg=~/projects/gitlab/konradodwrot/configs && { { [[ -z $(git -C $cfg status --porcelain) ]] && git -C $cfg fetch --quiet --depth 1 && git -C $cfg reset --hard --quiet FETCH_HEAD } || print -r -- "session-create: configs refresh skipped (dirty checkout or fetch failed); using the checked-out state" } && GITLAB_TOKEN="$(print -r -- "{{ secret (getenv \"GITLAB_TOKEN_SECRET_PATH\") }}" | che render tpl -f /dev/stdin)" che run --profiles sandbox-runtime'

exec $kc exec -it $SESSION -- env "GCP_SA_KEY=$gcp_sa_key" su -w GCP_SA_KEY,OTEL_EXPORTER_OTLP_ENDPOINT,CHE_OTEL_ENDPOINT,OTEL_RESOURCE_ATTRIBUTES - ko
##[<] 🤖🤖🤖
