#!/usr/bin/env bash
# setup-posix.sh — resolve, install, and assert a pinned .NET SDK.
# (resolve + finalize also run on Windows in Git Bash.)
#
# Usage:
#   setup-posix.sh resolve    # env: INPUT_VERSION, INPUT_CACHE_KEY
#                             # emits resolved-version, archive-url, sha512,
#                             # install-root, cache-key via $GITHUB_OUTPUT
#   setup-posix.sh install    # env: INSTALL_ROOT, ARCHIVE_URL, SHA512, CACHE_HIT
#                             # downloads + verifies + extracts, appends
#                             # <root> to $GITHUB_PATH
#   setup-posix.sh finalize   # env: INPUT_VERSION, RESOLVED_VERSION, INSTALL_ROOT
#                             # runs dotnet --version, asserts the resolved
#                             # version, exports DOTNET_ROOT, and emits
#                             # dotnet-version/dotnet-root
#
# Version semantics (mirroring setup-node's tiering):
#   lts                 -> newest supported LTS channel (default)
#   sts                 -> newest supported STS channel
#   latest              -> newest non-preview channel
#   9.0                 -> channel line: latest SDK on that channel
#   9.0.317             -> exact SDK version (searched across channels,
#                          newest channel first)
#
# Sources are the official dotnetcli release metadata and archives; every
# download is verified against the manifest's SHA-512.

set -euo pipefail

BASE="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata"

TMP_DIR=""
trap '[ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"' EXIT

emit() { # name value
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "$1=$2" >> "$GITHUB_OUTPUT"
    else
        echo "$1=$2"
    fi
}

forward_slashes() { printf '%s' "$1" | sed 's|\\|/|g'; }

fail() {
    echo "error: $*" >&2
    exit 1
}

fetch_manifest() { # url -> path (mktemp file, echoed)
    local url="$1" out
    out="$(mktemp)"
    curl -fsSL --retry 3 -o "$out" "$url" || {
        rm -f "$out"
        fail "unable to fetch manifest: $url"
    }
    echo "$out"
}

resolve() {
    local uname_os="${OSTYPE:-$(uname -s)}"
    local platform
    case "$uname_os" in
        darwin*) platform="macos" ;;
        linux*)  platform="linux" ;;
        msys*|mingw*|cygwin*) platform="windows" ;;
        *) fail "unsupported OS: $uname_os" ;;
    esac

    local runner_arch="${RUNNER_ARCH:-}"
    [ -z "$runner_arch" ] && runner_arch="$(uname -m)"
    case "$runner_arch" in
        [Aa][Rr][Mm]64|[Aa][Aa][Rr][Cc][Hh]64) runner_arch="arm64" ;;
        *) runner_arch="x64" ;;
    esac

    local index_file
    index_file="$(fetch_manifest "${BASE}/releases-index.json")"

    local out
    out=$(INPUT_VERSION="${INPUT_VERSION:-lts}" PLATFORM="$platform" ARCH="$runner_arch" INDEX="$index_file" python3 - 2>&1 <<'PYEOF'
import json, os, subprocess, sys

ver = os.environ["INPUT_VERSION"]
plat = os.environ["PLATFORM"]
arch = os.environ["ARCH"]
idx = json.load(open(os.environ["INDEX"]))

def fetch(url):
    p = subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", "-", url],
                       capture_output=True)
    if p.returncode != 0:
        sys.exit(f"unable to fetch manifest: {url}")
    return p.stdout

def load_rels(url):
    return json.loads(fetch(url))

channels = idx["releases-index"]
supported = [c for c in channels if c.get("support-phase") != "eol"]

def chan_key(c):
    try:
        return tuple(int(x) for x in c["channel-version"].split("."))
    except ValueError:
        return (0, 0)

supported.sort(key=chan_key, reverse=True)

def pick_sdk(rels, want):
    for r in rels["releases"]:
        for s in r.get("sdks", []):
            if s["version"] == want:
                return s
    return None

sel = None
if ver in ("lts", "sts", "latest"):
    for c in supported:
        if ver == "latest" and c.get("support-phase") == "preview":
            continue
        if ver == "lts" and c.get("release-type") != "lts":
            continue
        if ver == "sts" and c.get("release-type") != "sts":
            continue
        sel = c
        break
    if not sel:
        sys.exit(f"no supported channel found for '{ver}'")
elif ver.count(".") == 1:
    sel = next((c for c in supported if c["channel-version"] == ver), None)
    if not sel:
        sys.exit(f"no channel '{ver}' in release metadata")
else:
    q = ver[1:] if ver.startswith("v") else ver
    # Exact SDK version: search channels newest-first for a release entry
    # whose sdks list contains it (older SDKs live in older releases.json
    # entries of the same channel).
    for c in supported:
        if pick_sdk(load_rels(c["releases.json"]), q):
            sel = {"channel-version": c["channel-version"],
                   "latest-sdk": q,
                   "releases.json": c["releases.json"]}
            break
    if not sel:
        sys.exit(f"no SDK with version '{q}' in release metadata")

rels = load_rels(sel["releases.json"])
if sel.get("latest-sdk"):
    sdk_ver = sel["latest-sdk"]
    sdk = pick_sdk(rels, sdk_ver)
    if not sdk:
        sys.exit(f"no SDK '{sdk_ver}' found in channel '{sel['channel-version']}'")
else:
    sdk_ver = rels["latest-sdk"]
    sdk = pick_sdk(rels, sdk_ver)
    if not sdk:
        sys.exit(f"no SDK '{sdk_ver}' found in channel '{sel['channel-version']}'")

rid = {"macos": f"osx-{arch}", "linux": f"linux-{arch}", "windows": f"win-{arch}"}[plat]
# Only portable archives: skip installer formats (.pkg/.msi/.exe/.7z) that
# share the same rid.
entry = next((f for f in sdk["files"]
              if f["rid"] == rid and f.get("url", "").endswith((".tar.gz", ".zip"))), None)
if not entry:
    sys.exit(f"no {rid} archive for SDK {sdk_ver} (available: {', '.join(f['rid'] for f in sdk['files'])})")

print(sdk_ver)
print(entry["url"])
print(entry["hash"])
PYEOF
) || { [ -n "$out" ] && fail "$out" || fail "version resolution failed"; }
    rm -f "$index_file"
    local resolved archive sha
    { read -r resolved; read -r archive; read -r sha; } <<< "$out"

    local install_root
    install_root="$(forward_slashes "${RUNNER_TOOL_CACHE:-$HOME/hostedtoolcache}/setup-dotnet/${resolved}")"

    emit "resolved-version" "$resolved"
    emit "archive-url" "$archive"
    emit "sha512" "$sha"
    emit "install-root" "$install_root"
    emit "cache-key" "${resolved}${INPUT_CACHE_KEY:+__${INPUT_CACHE_KEY}}"
}

install() {
    local node_bin="${INSTALL_ROOT}"

    if [ "${CACHE_HIT:-false}" = "true" ] && [ -x "$INSTALL_ROOT/dotnet" ]; then
        echo ".NET SDK restored from cache at ${INSTALL_ROOT}"
    else
        mkdir -p "$INSTALL_ROOT"
        TMP_DIR="$(mktemp -d)"

        local archive="$TMP_DIR/dotnet.archive"
        echo "Downloading $ARCHIVE_URL"
        curl -fL --retry 3 --retry-delay 5 -o "$archive" "$ARCHIVE_URL"

        local got
        got="$(shasum -a 512 "$archive" | awk '{print $1}')"
        if [ "$(printf '%s' "$got" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$SHA512" | tr '[:upper:]' '[:lower:]')" ]; then
            fail "SHA-512 mismatch for $(basename "$ARCHIVE_URL"): got $got, expected $SHA512"
        fi
        echo "SHA-512 verified"

        # The SDK archive contains a top-level dotnet-sdk-X.Y.Z-<rid>/ dir;
        # strip it so the SDK lands directly in INSTALL_ROOT.
        case "$ARCHIVE_URL" in
            *.tar.gz) tar -xzf "$archive" -C "$INSTALL_ROOT" --strip-components=1 ;;
            *)        fail "unsupported archive format: $ARCHIVE_URL" ;;
        esac

        [ -x "$INSTALL_ROOT/dotnet" ] || fail "archive did not contain the dotnet binary at $INSTALL_ROOT"

        echo ".NET SDK installed at ${INSTALL_ROOT}"
    fi

    # Make dotnet available to subsequent steps
    echo "$node_bin" >> "$GITHUB_PATH"
    echo "Added $node_bin to PATH"
}

finalize() {
    local dotnet_exe="dotnet"
    case "$(uname -s)" in
        *MINGW*|*MSYS*|*CYGWIN*) dotnet_exe="dotnet.exe" ;;
    esac
    [ -x "${INSTALL_ROOT}/${dotnet_exe}" ] || fail "dotnet binary not found at ${INSTALL_ROOT}/${dotnet_exe}"

    # Run from the install root: dotnet --version follows SDK resolution, and
    # a global.json in the repo root could pin a different SDK.
    local reported
    reported="$(cd "$INSTALL_ROOT" && "./${dotnet_exe}" --version 2>&1 | tr -d '\r')"
    echo "dotnet --version: $reported"
    case "$reported" in
        "$RESOLVED_VERSION")
            echo "version assertion passed: ${RESOLVED_VERSION}" ;;
        *)
            echo "error: dotnet --version reported: $reported" >&2
            echo "       expected ${RESOLVED_VERSION}" >&2
            exit 1
            ;;
    esac

    # Export for the rest of the job
    if [ -n "${GITHUB_ENV:-}" ]; then
        echo "DOTNET_ROOT=${INSTALL_ROOT}" >> "$GITHUB_ENV"
    fi
    echo "$INSTALL_ROOT" >> "$GITHUB_PATH"

    emit "dotnet-version" "$RESOLVED_VERSION"
    emit "dotnet-root" "$INSTALL_ROOT"
}

case "${1:-}" in
    resolve)  resolve ;;
    install)  install ;;
    finalize) finalize ;;
    *) fail "usage: $0 {resolve|install|finalize}" ;;
esac