##[>] 🤖🤖
FROM debian:bookworm-slim

COPY ci/tool-versions.env /tmp/tool-versions.env

ENV GOPATH=/usr/local/go-tools
ENV GOROOT=/usr/local/go
ENV PATH=/usr/local/go/bin:/usr/local/go-tools/bin:/usr/local/bin:$PATH
ENV CLICOLOR=0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      make git zsh curl ca-certificates sudo unzip xz-utils file procps perl vim less \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh ko \
 && echo 'ko ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/ko

RUN set -eux; \
    . /tmp/tool-versions.env; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) goplat=linux-amd64; gosha="$GO_SHA256_LINUX_AMD64" ;; \
      arm64) goplat=linux-arm64; gosha="$GO_SHA256_LINUX_ARM64" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.${goplat}.tar.gz"; \
    echo "${gosha}  /tmp/go.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/go.tar.gz -C /usr/local; \
    rm /tmp/go.tar.gz; \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go; \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

#[why] prebuilt bins, not go install: skip compiling their dep trees
RUN set -eux; \
    . /tmp/tool-versions.env; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) lhplat=Linux_x86_64; lhsha="$LEFTHOOK_SHA256_LINUX_AMD64"; yqplat=linux_amd64; yqsha="$YQ_SHA256_LINUX_AMD64" ;; \
      arm64) lhplat=Linux_arm64; lhsha="$LEFTHOOK_SHA256_LINUX_ARM64"; yqplat=linux_arm64; yqsha="$YQ_SHA256_LINUX_ARM64" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/lefthook "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_${lhplat}"; \
    echo "${lhsha}  /usr/local/bin/lefthook" | sha256sum -c -; \
    chmod +x /usr/local/bin/lefthook; \
    curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${yqplat}"; \
    echo "${yqsha}  /usr/local/bin/yq" | sha256sum -c -; \
    chmod +x /usr/local/bin/yq

#[why] prebuilt tarballs from the package registry, not go install: skip che's slow CGO build (tree-sitter + 1Password sdk)
RUN set -eux; \
    . /tmp/tool-versions.env; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) plat=linux_amd64; chesha="$CHE_SHA256_LINUX_AMD64"; rtsha="$RENDER_TPL_SHA256_LINUX_AMD64" ;; \
      arm64) plat=linux_arm64; chesha="$CHE_SHA256_LINUX_ARM64"; rtsha="$RENDER_TPL_SHA256_LINUX_ARM64" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    che_base="https://gitlab.com/api/v4/projects/konradodwrot%2Fgo%2Fche/packages/generic/che/${CHE_VERSION}"; \
    curl -fsSL -o /tmp/che.tar.gz "${che_base}/che_${CHE_VERSION}_${plat}.tar.gz"; \
    echo "${chesha}  /tmp/che.tar.gz" | sha256sum -c -; \
    tar -xz -C /usr/local/bin -f /tmp/che.tar.gz che; \
    rm /tmp/che.tar.gz; \
    rt_base="https://gitlab.com/api/v4/projects/konradodwrot%2Fgo%2Frender-files/packages/generic/render-files/${RENDER_TPL_VERSION}"; \
    curl -fsSL -o /tmp/render-tpl.tar.gz "${rt_base}/render-tpl_${RENDER_TPL_VERSION}_${plat}.tar.gz"; \
    echo "${rtsha}  /tmp/render-tpl.tar.gz" | sha256sum -c -; \
    tar -xz -C /usr/local/bin -f /tmp/render-tpl.tar.gz render-tpl; \
    rm /tmp/render-tpl.tar.gz
##[<] 🤖🤖
