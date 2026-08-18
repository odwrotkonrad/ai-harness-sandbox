#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

${0:A:h}/machine-up.zsh

typeset configs_ref="$(curl --connect-timeout 30 --retry 10 --retry-delay 30 --retry-all-errors -fsS 'https://gitlab.com/api/v4/projects/konradodwrot%2Fconfigs/repository/commits?path=profiles&per_page=1' | sed -n 's/.*"id":"\([0-9a-f]*\)".*/\1/p')"

podman build \
  --file $repo_root/ci/docker/Dockerfile.installs \
  --build-arg BASE_IMAGE=localhost:5001/sandbox-base:local \
  --build-arg CONFIGS_REF=${configs_ref:-main} \
  --tag localhost:5001/sandbox-installs:local \
  $repo_root

podman push --tls-verify=false localhost:5001/sandbox-installs:local
##[<] 🤖🤖
