##[>] 🤖🤖
FROM debian:bookworm-slim

#[why] only what the profile run itself needs: git (che remote clone), curl + ca-certificates (che tarball, profile install scripts), sudo (root-owned dests + apt installs as the sandbox user), perl (shasum in the rg install script), procps (homebrew installer requirement); zsh, rg and brew are NOT preinstalled, the zsh/base profile's own scripts install them
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates sudo perl procps \
 && rm -rf /var/lib/apt/lists/*

#[why] prebuilt che tarball, not go install: skip che's slow CGO build (tree-sitter + 1Password sdk); CHE_REF busts this layer only when the latest che tarball changed (CI passes its etag)
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
    curl -fsSL --connect-timeout 30 --retry 5 --retry-delay 2 --retry-all-errors -o /tmp/che.tar.gz "${che_base}/che_latest_${plat}.tar.gz"; \
    tar -xz -C /usr/local/bin -f /tmp/che.tar.gz che render-tpl; \
    rm /tmp/che.tar.gz

ARG SANDBOX_USER=ko
RUN useradd -m -s /bin/zsh -G root "$SANDBOX_USER" \
 && echo "$SANDBOX_USER ALL=(ALL) NOPASSWD: ALL" >"/etc/sudoers.d/$SANDBOX_USER"

USER $SANDBOX_USER
WORKDIR /home/$SANDBOX_USER

COPY --chown=$SANDBOX_USER ci/docker/che.yml /home/$SANDBOX_USER/che.yml

#[why] shallow configs clone baked at ~/configs: the che.yml wrapper composes configs tool profiles from it via filesystem sources (che remote refs resolve only repo-root specs); session-create pulls it fresh before the runtime run. CONFIGS_REF busts this layer only when configs tools/ moved, so an unchanged configs keeps the cached layer
#[why] CHE_OTEL_ENABLED=false: no otel collector exists during the image build, so che's exporter would spew "connect: connection refused" on every op
#[why] CHE_RENDER_TEMPLATES_SKIP_SECRETS=true: the bake must stay secret-free by construction; the sandbox-build set carries no secret templates today, this guards future additions from failing the build or baking a secret. sandbox-runtime re-renders at pod creation
ARG CONFIGS_REF=main
RUN set -eux; \
    : "${CONFIGS_REF}"; \
    git clone --quiet --depth 1 --single-branch https://gitlab.com/konradodwrot/configs.git /home/$SANDBOX_USER/configs; \
    CI=1 container=docker CHE_OTEL_ENABLED=false CHE_VALIDATE_SPEC=error CHE_RENDER_TEMPLATES_SKIP_SECRETS=true \
    che run --profiles sandbox-build

CMD ["zsh", "-l"]
##[<] 🤖🤖
