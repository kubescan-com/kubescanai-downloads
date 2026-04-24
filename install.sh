#!/usr/bin/env bash
#
# KUBESCAN AI CLI installer.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/kubescan-com/kubescanai-downloads/main/install.sh | bash
#
# Override version:
#   curl -sSL https://raw.githubusercontent.com/kubescan-com/kubescanai-downloads/main/install.sh | VERSION=v0.1.0 bash
#
# Override install dir:
#   curl -sSL https://raw.githubusercontent.com/kubescan-com/kubescanai-downloads/main/install.sh | INSTALL_DIR=$HOME/.local/bin bash

set -euo pipefail

# This value is replaced at release time by the release workflow.
VERSION="v0.1.18"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
REPO="kubescan-com/kubescanai-downloads"
BINARY_NAME="kubescanai"

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

err() {
    echo "error: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

# ─────────────────────────────────────────────
# Detect OS and architecture
# ─────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux" ;;
        Darwin) echo "darwin" ;;
        *)      err "unsupported OS: $(uname -s) (supported: Linux, Darwin)" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)             err "unsupported architecture: $(uname -m) (supported: amd64, arm64)" ;;
    esac
}

# ─────────────────────────────────────────────
# Resolve version
# ─────────────────────────────────────────────

resolve_version() {
    if [ "$VERSION" = "latest" ]; then
        info "Resolving latest version..."
        local resolved
        resolved=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name":' \
            | head -n 1 \
            | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
        if [ -z "$resolved" ]; then
            err "could not resolve latest version from GitHub API"
        fi
        echo "$resolved"
    else
        echo "$VERSION"
    fi
}

# ─────────────────────────────────────────────
# Download and install
# ─────────────────────────────────────────────

TMPDIR=""
cleanup() {
    if [ -n "${TMPDIR}" ] && [ -d "${TMPDIR}" ]; then
        rm -rf "${TMPDIR}"
    fi
}
trap cleanup EXIT

main() {
    local os arch version url

    os=$(detect_os)
    arch=$(detect_arch)
    version=$(resolve_version)

    url="https://github.com/${REPO}/releases/download/${version}/${BINARY_NAME}-${os}-${arch}"

    info "Installing ${BINARY_NAME} ${version} for ${os}/${arch}"
    info "URL: ${url}"

    TMPDIR=$(mktemp -d)
    local tmp="${TMPDIR}"

    if ! curl -fsSL -o "${tmp}/${BINARY_NAME}" "${url}"; then
        err "failed to download ${url}"
    fi

    chmod +x "${tmp}/${BINARY_NAME}"

    # Verify the binary actually runs.
    if ! "${tmp}/${BINARY_NAME}" version >/dev/null 2>&1; then
        err "downloaded binary failed to execute"
    fi

    # Move to install dir, asking for sudo only if needed.
    if [ -w "$INSTALL_DIR" ]; then
        mv "${tmp}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        info "Elevated permissions required to write to ${INSTALL_DIR}"
        sudo mv "${tmp}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    fi

    info "Installed ${BINARY_NAME} to ${INSTALL_DIR}/${BINARY_NAME}"
    info "Run '${BINARY_NAME} version' to verify"
}

main "$@"
