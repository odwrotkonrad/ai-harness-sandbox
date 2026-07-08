#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
typeset configs_dir=${CONFIGS_DIR:-${repo_root:h}/configs}
#[why] default mirrors the host layout: ~/projects/gitlab/<group dir>/configs, group dir taken from the checkout's parent
typeset bake_dir=${CONFIGS_BAKE_DIR:-/home/ko/projects/gitlab/${${configs_dir:A:h}:t}/configs}

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"
[[ -f $configs_dir/che.yml ]] || fn-exit-with 1 "${0:t}: $configs_dir is not a configs checkout (set CONFIGS_DIR)"

docker build -f $repo_root/ci/Dockerfile --build-arg CONFIGS_BAKE_DIR=$bake_dir -t sandbox:local $configs_dir
##[<] 🤖🤖
