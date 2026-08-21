#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
typeset tmp=$repo_root/.user/claude/tmp
mkdir -p $tmp
typeset context=$(mktemp -d $tmp/image-build-config.XXXXXX)
typeset claude_creds=$context/claude-credentials.json
typeset claude_onboarding=$context/claude-onboarding.json
typeset gcp_key=$context/gcp-sa-key.json
typeset gitlab_token=$context/gitlab-token

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

${0:A:h}/machine-up.zsh

trap 'rm -rf $context 2>/dev/null' EXIT
mkdir -p $context/ci/docker
cp $repo_root/ci/docker/Dockerfile.config $repo_root/ci/docker/merge-claude-onboarding.py $context/ci/docker/

${0:A:h}/claude-auth-capture.zsh $claude_creds
${0:A:h}/claude-onboarding-capture.zsh $claude_onboarding

#[why] the iac auth module writes this item on apply; the vault is the sandbox-scoped one, so a
#   1Password session limited to ProgrammaticAccess cannot read it. GCP_SA_KEY_OP_REF overrides
typeset gcp_key_ref=${GCP_SA_KEY_OP_REF:-op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key}

if (( $+commands[op] )) {
  op read $gcp_key_ref >$gcp_key 2>/dev/null || :>$gcp_key
} else {
  :>$gcp_key
}
[[ -s $gcp_key ]] \
  || fn-exit-with 1 "${0:t}: no GCP SA key ($gcp_key_ref); a session would authenticate to gcp not at all. set GCP_SA_KEY_OP_REF, or use a 1Password session that can read the sandbox vault"

:>$gitlab_token
chmod 600 $gitlab_token

#[why] the image is a virt context, so its gitlab token comes from secret manager under the SA
#   identity fetched just above, matching what the glab profile reads at runtime. no op:// fallback:
#   the only 1Password gitlab token is the operator's own, far broader than the group token the
#   sandbox is scoped to, and baking it in would hand every session a credential it must not hold
print -r -- '{{ secret "gcp://konradodwrot-sandbox-auth/sandbox-gitlab-group-token" }}' \
  | GOOGLE_APPLICATION_CREDENTIALS=$gcp_key che render tpl -f /dev/stdin >$gitlab_token 2>/dev/null \
  || :>$gitlab_token

[[ -s $gitlab_token ]] \
  || fn-exit-with 1 "${0:t}: no GitLab token (gcp://konradodwrot-sandbox-auth/sandbox-gitlab-group-token); the sandbox SA could not read it, so the workspace clone would bake an empty workspace"

typeset configs_ref="$(curl --connect-timeout 30 --retry 10 --retry-delay 30 --retry-all-errors -fsS 'https://gitlab.com/api/v4/projects/konradodwrot%2Fconfigs/repository/commits?path=profiles&per_page=1' | sed -n 's/.*"id":"\([0-9a-f]*\)".*/\1/p')"

typeset secrets_digest=$(cat $claude_creds $claude_onboarding $gcp_key $gitlab_token | shasum -a 256 | cut -d' ' -f1)

podman build \
  --file $context/ci/docker/Dockerfile.config \
  --build-arg INSTALLS_IMAGE=localhost:5001/sandbox-installs:local \
  --build-arg CONFIGS_REF=${configs_ref:-main} \
  --build-arg SECRETS_DIGEST=$secrets_digest \
  --secret id=claude_credentials,src=$claude_creds \
  --secret id=claude_onboarding,src=$claude_onboarding \
  --secret id=gcp_sa_key,src=$gcp_key \
  --secret id=gitlab_token,src=$gitlab_token \
  --tag localhost:5001/sandbox:local \
  $context

podman push --tls-verify=false localhost:5001/sandbox:local
##[<] 🤖🤖
