#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"

#[why] latest commit touching tools -> CONFIGS_REF: busts the clone + che run layer only when the sourced configs tool profiles themselves changed, not on every configs push
typeset configs_ref="$(curl --connect-timeout 30 --retry 5 --retry-delay 2 --retry-all-errors -fsS 'https://gitlab.com/api/v4/projects/konradodwrot%2Fconfigs/repository/commits?path=tools&per_page=1' | sed -n 's/.*"id":"\([0-9a-f]*\)".*/\1/p')"

#[why] etag of the latest che tarball -> CHE_REF: busts the che layer only when che re-published (mirrors the CI jobs)
typeset che_ref=$(curl --connect-timeout 30 --retry 5 --retry-delay 2 -fsSI "https://gitlab.com/api/v4/projects/konradodwrot%2Fgo-modules/packages/generic/che/latest/che_latest_linux_$(uname -m | sed 's/aarch64\|arm64/arm64/;s/x86_64/amd64/').tar.gz" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')

docker build \
  --file $repo_root/ci/docker/Dockerfile \
  --build-arg CHE_REF=${che_ref:-latest} \
  --build-arg CONFIGS_REF=$configs_ref \
  --tag sandbox:local \
  $repo_root
##[<] 🤖🤖
