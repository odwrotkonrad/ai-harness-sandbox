#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

${0:A:h}/machine-up.zsh

typeset che_ref=$(curl --connect-timeout 30 --retry 10 --retry-delay 30 -fsSI "https://gitlab.com/api/v4/projects/konradodwrot%2Fgo-modules/packages/generic/che/latest/che_latest_linux_$(uname -m | sed 's/aarch64\|arm64/arm64/;s/x86_64/amd64/').tar.gz" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')

podman build \
  --file $repo_root/ci/docker/Dockerfile.base \
  --build-arg CHE_REF=${che_ref:-latest} \
  --tag localhost:5001/sandbox-base:local \
  $repo_root

podman push --tls-verify=false localhost:5001/sandbox-base:local
##[<] 🤖🤖
