#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
typeset configs_dir=${CONFIGS_DIR:-${repo_root:h}/configs}

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"
[[ -f $configs_dir/che.yml ]] || fn-exit-with 1 "${0:t}: $configs_dir is not a configs checkout (set CONFIGS_DIR)"

docker build -f $repo_root/ci/Dockerfile -t sandbox:local $configs_dir
##[<] 🤖🤖
