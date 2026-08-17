##[>] 🤖🤖
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates sudo perl procps python3 jq gcc libc6-dev make \
 && rm -rf /var/lib/apt/lists/*

ARG CHE_REF=latest
RUN set -eux; \
    : "${CHE_REF}"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) plat=linux_amd64 ;; \
      arm64) plat=linux_arm64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    che_base="https://gitlab.com/api/v4/projects/konradodwrot%2Fgo-modules/packages/generic/che/latest"; \
    curl -fsSL --connect-timeout 30 --retry 10 --retry-delay 30 --retry-all-errors -o /tmp/che.tar.gz "${che_base}/che_latest_${plat}.tar.gz"; \
    tar -xz -C /usr/local/bin -f /tmp/che.tar.gz che render-tpl render-repo-group-index; \
    rm /tmp/che.tar.gz

ARG SANDBOX_USER=ko
RUN useradd -m -s /bin/zsh -G root "$SANDBOX_USER" \
 && echo "$SANDBOX_USER ALL=(ALL) NOPASSWD: ALL" >"/etc/sudoers.d/$SANDBOX_USER"

USER $SANDBOX_USER
WORKDIR /home/$SANDBOX_USER

COPY --chown=$SANDBOX_USER ci/docker/che.yml /home/$SANDBOX_USER/.sandbox-che/che.yml

#[why] two che runs, not one: the prose-authored payloads (agent docs, the AGENTS.md host template)
#   are gitignored in configs and exist only once ontoRepo renders them, so a bare clone is missing
#   files the llm/base profile then tries to load. checkout of CONFIGS_REF pins the tree the image
#   is built from, which the clone alone did not do
#
#[why] ~/.local/bin on PATH: che symlinks the nvm-installed node there, then invokes npm by its
#   absolute nvm path. npm's shebang is `env node`, so with that dir off PATH node was unresolvable
#   and every global npm install (claude, codex) died with 127. a login shell has it, this RUN shell
#   did not. it is also the dir che reports as "not on path" when picking a binaries destination
ENV PATH=/home/$SANDBOX_USER/.local/bin:$PATH
RUN mkdir -p /home/$SANDBOX_USER/.local/bin

ARG CONFIGS_REF=main
RUN set -eux; \
    : "${CONFIGS_REF}"; \
    configs=/home/$SANDBOX_USER/projects/gitlab/konradodwrot/configs; \
    git clone --quiet https://gitlab.com/konradodwrot/configs.git "$configs"; \
    git -C "$configs" checkout --quiet "$CONFIGS_REF"; \
    git -C /home/$SANDBOX_USER/.sandbox-che init --quiet; \
    git -C /home/$SANDBOX_USER/.sandbox-che add che.yml; \
    export CI=1 container=docker CHE_OTEL_ENABLED=false CHE_VALIDATE_SPEC=error CHE_RENDER_TEMPLATES_SKIP_SECRETS=true CHE_ERREXIT=true; \
    (cd "$configs"; che run --profiles ontoRepo); \
    (cd /home/$SANDBOX_USER/.sandbox-che; che run --profiles sandbox-build)

CMD ["zsh", "-l"]
##[<] 🤖🤖
