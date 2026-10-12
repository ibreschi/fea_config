#!/usr/bin/env bash
set -euo pipefail
# Download this file to disk before executing, so stdin remains a terminal.
repo=${FEA_REPO_URL:-https://github.com/ibreschi/fea_config.git}
ref=${FEA_REF:-dev_time_keeper_improve}
destination=${FEA_DIR:-$HOME/git/fea_config}
if [[ $EUID == 0 ]]; then
    printf 'Run as your normal user; sudo is requested when needed.\n' >&2
    exit 1
fi
if ! command -v git >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y git ca-certificates
fi
if [[ ! -e $destination ]]; then
    mkdir -p "$(dirname "$destination")"
    git clone --branch "$ref" --single-branch "$repo" "$destination"
elif [[ ! -f $destination/install.sh ]]; then
    printf 'Existing destination has no installer: %s\n' "$destination" >&2
    exit 1
fi
exec bash "$destination/install.sh" "$@"
