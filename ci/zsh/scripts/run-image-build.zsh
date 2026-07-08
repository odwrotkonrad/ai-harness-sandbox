#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
typeset oci_dir=${OCI_IMAGES_DIR:-${repo_root:h}/infra/oci-images}

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"
[[ -f $oci_dir/Makefile ]] || fn-exit-with 1 "${0:t}: $oci_dir is not the oci-images checkout (set OCI_IMAGES_DIR)"

make -C $oci_dir run-image-build-all
docker tag dev-sandbox:local sandbox:local
##[<] 🤖🤖
