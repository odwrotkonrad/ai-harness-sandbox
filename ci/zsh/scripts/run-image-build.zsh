#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
#[why] oci-images lives in the konradodwrot group tree, not a restricted-group sibling: try the sibling first, then the workspace-root konradodwrot path; OCI_IMAGES_DIR overrides both
typeset -a oci_candidates=(
  ${repo_root:h}/infra/oci-images
  ${repo_root:h:h}/konradodwrot/infra/oci-images
)
typeset oci_dir=$OCI_IMAGES_DIR
#[why] the Makefile exports OCI_IMAGES_DIR unconditionally, so it exists but is empty when unset: test emptiness, not existence
if [[ -z $oci_dir ]] {
  for c in $oci_candidates; { [[ -f $c/Makefile ]] && { oci_dir=$c; break } }
}

(( $+commands[docker] )) || fn-exit-with 1 "${0:t}: docker not found"
[[ -f $oci_dir/Makefile ]] || fn-exit-with 1 "${0:t}: ${oci_dir:-oci-images checkout} not found (set OCI_IMAGES_DIR)"

make -C $oci_dir run-image-build-all
docker tag dev-sandbox:local sandbox:local
##[<] 🤖🤖
