# syntax=docker/dockerfile:1

ARG GO_VERSION="1.22"
ARG ALPINE_VERSION="3.20"

# --------------------------------------------------------
# Builder
# --------------------------------------------------------

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS release

# Always set by buildkit
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS

# Install dependencies
RUN set -eux; \
    apk add --no-cache \
    build-base \
    ca-certificates \
    linux-headers \
    binutils-gold \
    git

# Set the workdir
WORKDIR /go/src/cosmossdk.io/tools/cosmovisor

# install cosmovisor
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/pkg/mod \
    set -eux; \
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0; 

# Cosmwasm - Download correct libwasmvm version
RUN set -eux; \
    WASMVM_REPO="github.com/CosmWasm/wasmvm"; \
    WASMVM_MOD_VERSION="$(grep ${WASMVM_REPO} go.mod | cut -d ' ' -f 1)"; \
    WASMVM_VERSION="$(go list -m ${WASMVM_MOD_VERSION} | cut -d ' ' -f 2)"; \
    for LIBWASM in "libwasmvm_muslc.x86_64.a" "libwasmvm_muslc.aarch64.a" "libwasmvmstatic_darwin.a"; \
        wget "https://${WASMVM_REPO}/releases/download/${WASMVM_VERSION}/${LIBWASM}" -O "/lib/${LIBWASM}"; \
        # verify checksum
        EXPECTED=$(wget -q "https://${WASMVM_REPO}/releases/download/${WASMVM_VERSION}/checksums.txt" -O- | grep "${LIBWASM}" | awk '{print $1}'); \
        sha256sum "/lib/${LIBWASM}" | grep "${EXPECTED}"; \
    done;
