#!/usr/bin/env sh

# Prepare mitmproxy environment for the current shell.
# Usage (must be sourced):
#   . ./scripts/prepare-mitmproxy-env.sh [PORT]
#   source ./scripts/prepare-mitmproxy-env.sh [PORT]
#
# - PORT defaults to 13370

# Default port
DEFAULT_PORT=13370
PORT="${1:-$DEFAULT_PORT}"

# Validate port; fall back to default if invalid
case "$PORT" in
  '' | *[!0-9]*)
    echo "Warning: invalid port '$PORT'; using $DEFAULT_PORT" >&2
    PORT="$DEFAULT_PORT"
    ;;
esac

PROXY_URL="http://127.0.0.1:${PORT}"

# mitmproxy creates this Linux CA bundle on first start.
CA_BUNDLE="${HOME}/.mitmproxy/mitmproxy-ca-cert.pem"

# Export proxy variables (both cases for broad compatibility)
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export ALL_PROXY="$PROXY_URL"
export all_proxy="$PROXY_URL"
export FTP_PROXY="$PROXY_URL"
export ftp_proxy="$PROXY_URL"

# Ensure local addresses bypass the proxy (append without clobbering existing values)
BASE_NO_PROXY="localhost,127.0.0.1,::1"
export NO_PROXY="${NO_PROXY:+${NO_PROXY},}${BASE_NO_PROXY}"
export no_proxy="${no_proxy:+${no_proxy},}${BASE_NO_PROXY}"

# Export certificate bundle variables for common tools and runtimes
export REQUESTS_CA_BUNDLE="$CA_BUNDLE"
export NODE_EXTRA_CA_CERTS="$CA_BUNDLE"
export SSL_CERT_FILE="$CA_BUNDLE"
export CURL_CA_BUNDLE="$CA_BUNDLE"
export GIT_SSL_CAINFO="$CA_BUNDLE"

# Helpful summary
echo "mitmproxy environment prepared:"
echo "  Proxy URL:  $PROXY_URL"
echo "  CA bundle:  $CA_BUNDLE"
if [ ! -f "$CA_BUNDLE" ]; then
  echo "  Note: CA bundle not found yet. Start mitmproxy and install its CA, then re-run this." >&2
fi
