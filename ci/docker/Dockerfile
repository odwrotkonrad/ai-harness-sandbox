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

ARG CONFIGS_REF=main
ARG CHE_PACKAGES_SILENCE_INSTALL_STDOUT=true
RUN set -eux; \
    : "${CONFIGS_REF}"; \
    git clone --quiet --depth 1 --single-branch https://gitlab.com/konradodwrot/configs.git /home/$SANDBOX_USER/projects/gitlab/konradodwrot/configs; \
    git -C /home/$SANDBOX_USER/.sandbox-che init --quiet; \
    git -C /home/$SANDBOX_USER/.sandbox-che add che.yml; \
    cd /home/$SANDBOX_USER/.sandbox-che; \
    CI=1 container=docker CHE_OTEL_ENABLED=false CHE_VALIDATE_SPEC=error CHE_RENDER_TEMPLATES_SKIP_SECRETS=true CHE_ERREXIT=true \
    CHE_PACKAGES_SILENCE_INSTALL_STDOUT="${CHE_PACKAGES_SILENCE_INSTALL_STDOUT}" \
    che run --profiles sandbox-build

CMD ["zsh", "-l"]
##[<] 🤖🤖
