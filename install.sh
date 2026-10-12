#!/usr/bin/env bash
set -euo pipefail
ROOT=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROFILE=development
DRY_RUN=false
CONFIG_ONLY=false
ARCHIVE=
usage() {
    printf '%s\n' 'Usage: bash install.sh [--profile desktop|development] [--restore FILE] [--dry-run] [--config-only]' \
        'Default: desktop + development applications. Existing configuration files are backed up.'
}
while (($#)); do
    case "$1" in
        --profile|--restore)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            if [[ $1 == --profile ]]; then PROFILE=$2; else ARCHIVE=$2; fi
            shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --config-only) CONFIG_ONLY=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done
[[ $PROFILE == desktop || $PROFILE == development ]] || { usage; exit 2; }
run() {
    printf '+'; printf ' %q' "$@"; printf '\n'
    if ! $DRY_RUN; then "$@"; fi
}
fetch_script() {
    local name=$1 url=$2
    shift 2
    run curl -fsSL --retry 3 "$url" -o "$TEMP/$name"
    run bash "$TEMP/$name" "$@"
}
add_repo() {
    local name=$1 key_url=$2 entry=$3
    run curl -fsSL --retry 3 "$key_url" -o "$TEMP/$name.asc"
    run gpg --batch --yes --dearmor -o "$TEMP/$name.gpg" "$TEMP/$name.asc"
    run sudo install -m 0644 "$TEMP/$name.gpg" "/etc/apt/keyrings/fea-$name.gpg"
    if $DRY_RUN; then
        printf '+ write /etc/apt/sources.list.d/fea-%s.list: %s\n' "$name" "$entry"
    else
        printf '%s\n' "$entry" | sudo tee "/etc/apt/sources.list.d/fea-$name.list" >/dev/null
    fi
}
install_deb() {
    local name=$1 url=$2
    run curl -fL --retry 3 "$url" -o "$TEMP/$name.deb"
    # apt's sandbox user must be able to traverse the download directory.
    run chmod 0755 "$TEMP"
    run chmod 0644 "$TEMP/$name.deb"
    run sudo apt-get install -y "$TEMP/$name.deb"
}
install_packages() {
    local file=$1 line
    local packages=()
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line == \#* ]] || packages+=("$line")
    done < "$file"
    run sudo apt-get install -y "${packages[@]}"
}
clone_once() {
    local url=$1 destination=$2
    [[ -d $destination ]] || run git clone --depth 1 "$url" "$destination"
}
if $DRY_RUN; then
    TEMP=/tmp/fea-install-preview
else
    [[ $EUID != 0 ]] || { printf 'Run as your normal user, not root.\n' >&2; exit 1; }
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ $ID == ubuntu && ( $VERSION_ID == 24.04 || $VERSION_ID == 26.04 ) ]] || {
        printf 'Supported targets: Ubuntu 24.04 and 26.04. Found %s.\n' "$PRETTY_NAME" >&2
        exit 1
    }
    [[ $(dpkg --print-architecture) == amd64 ]] || {
        printf 'This desktop profile currently supports amd64 (Intel/AMD) laptops.\n' >&2
        exit 1
    }
    [[ -z $ARCHIVE || -f $ARCHIVE ]] || { printf 'Archive not found: %s\n' "$ARCHIVE" >&2; exit 1; }
    TEMP=$(mktemp -d /tmp/fea-install.XXXXXXXX)
    trap 'rm -rf -- "$TEMP"' EXIT
    trap 'printf "Installation failed at line %s. Fix the error and rerun the same command.\n" "$LINENO" >&2' ERR
fi
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.opencode/bin:$HOME/.cargo/bin:$PATH"
if ! $CONFIG_ONLY; then
    run sudo -v
    run sudo apt-get update
    run sudo apt-get install -y software-properties-common
    run sudo add-apt-repository -y universe
    run sudo apt-get update
    install_packages "$ROOT/packages/desktop.txt"
    if [[ $PROFILE == development ]]; then install_packages "$ROOT/packages/development.txt"; fi
    run pipx ensurepath
    for package in i3-resurrect td-watson black isort; do run pipx install "$package"; done
    if ! command -v uv >/dev/null; then fetch_script uv.sh https://astral.sh/uv/install.sh; fi
    if ! command -v i3status-rs >/dev/null; then
        if ! command -v cargo >/dev/null; then
            fetch_script rustup.sh https://sh.rustup.rs -y --profile minimal
        fi
        run cargo install --locked i3status-rs --version 0.34.0
    fi
    run mkdir -p "$HOME/.local/bin"
    if $DRY_RUN; then
        run ln -sfn '<i3status-rs executable>' "$HOME/.local/bin/i3status-rs"
    elif [[ $(command -v i3status-rs) != "$HOME/.local/bin/i3status-rs" ]]; then
        run ln -sfn "$(command -v i3status-rs)" "$HOME/.local/bin/i3status-rs"
    fi
    if ! command -v opencode >/dev/null; then fetch_script opencode.sh https://opencode.ai/install; fi
    run mkdir -p "$HOME/git" "$HOME/.vim/bundle" "$HOME/.vim/autoload"
    clone_once https://github.com/cykerway/complete-alias.git "$HOME/git/complete-alias"
    clone_once https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
    run curl -fsSL --retry 3 https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim -o "$HOME/.vim/autoload/plug.vim"
    if ! dpkg-query -W -f='${Status}' obsidian 2>/dev/null | grep -q 'install ok installed'; then
        if $DRY_RUN; then
            install_deb obsidian '<latest amd64 .deb from obsidianmd/obsidian-releases>'
        else
            curl -fsSL --retry 3 https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest -o "$TEMP/obsidian.json"
            url=$(jq -er '[.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url][0]' "$TEMP/obsidian.json")
            install_deb obsidian "$url"
        fi
    fi
    run sudo systemctl enable --now libvirtd
    run sudo usermod -aG libvirt,kvm "$(id -un)"
    if [[ $PROFILE == development ]]; then
        run sudo install -d -m 0755 /etc/apt/keyrings
        codename=${VERSION_CODENAME:-noble}
        add_repo docker https://download.docker.com/linux/ubuntu/gpg \
            "deb [arch=amd64 signed-by=/etc/apt/keyrings/fea-docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"
        add_repo google-cloud https://packages.cloud.google.com/apt/doc/apt-key.gpg \
            'deb [signed-by=/etc/apt/keyrings/fea-google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main'
        add_repo microsoft https://packages.microsoft.com/keys/microsoft.asc \
            'deb [arch=amd64 signed-by=/etc/apt/keyrings/fea-microsoft.gpg] https://packages.microsoft.com/repos/code stable main'
        add_repo edge https://packages.microsoft.com/keys/microsoft.asc \
            'deb [arch=amd64 signed-by=/etc/apt/keyrings/fea-edge.gpg] https://packages.microsoft.com/repos/edge stable main'
        run sudo apt-get update
        run sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin code microsoft-edge-stable
        run sudo systemctl enable --now docker
        run sudo usermod -aG docker "$(id -un)"
        run sudo snap install slack
        if ! command -v tailscale >/dev/null; then fetch_script tailscale.sh https://tailscale.com/install.sh; fi
        run mkdir -p "$HOME/.local/npm"
        # Keep global npm tools owned by the user, including MCP executables.
        if [[ ! -s $HOME/.nvm/nvm.sh ]]; then fetch_script nvm.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh; fi
        if ! $DRY_RUN; then
            export NVM_DIR="$HOME/.nvm"
            # shellcheck disable=SC1091
            source "$NVM_DIR/nvm.sh"
        fi
        run nvm install 22
        run nvm alias default 22
        if $DRY_RUN; then
            run ln -sfn '<nvm Node 22 executable>' "$HOME/.local/bin/node"
            run ln -sfn '<nvm npx executable>' "$HOME/.local/bin/npx"
        else
            run ln -sfn "$(command -v node)" "$HOME/.local/bin/node"
            run ln -sfn "$(command -v npx)" "$HOME/.local/bin/npx"
        fi
        run npm install --global --prefix "$HOME/.local/npm" snyk @anthropic-ai/claude-code @openai/codex
        if ! command -v kubectl >/dev/null; then
            if $DRY_RUN; then
                run curl -fL 'https://dl.k8s.io/release/<stable>/bin/linux/amd64/kubectl' -o "$TEMP/kubectl"
            else
                curl -fsSL --retry 3 https://dl.k8s.io/release/stable.txt -o "$TEMP/kubernetes-version"
                version=$(<"$TEMP/kubernetes-version")
                [[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid Kubernetes version.\n' >&2; exit 1; }
                run curl -fL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl" -o "$TEMP/kubectl"
                run curl -fL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl.sha256" -o "$TEMP/kubectl.sha256"
                printf '%s  %s\n' "$(<"$TEMP/kubectl.sha256")" "$TEMP/kubectl" | sha256sum --check
            fi
            run install -m 0755 "$TEMP/kubectl" "$HOME/.local/bin/kubectl"
        fi
        run pipx install 'headroom-ai[mcp]'
    fi
fi
run python3 "$ROOT/scripts/migrate.py" install --repo "$ROOT"
if [[ -n $ARCHIVE ]]; then run python3 "$ROOT/scripts/migrate.py" restore "$ARCHIVE"; fi
if ! $CONFIG_ONLY; then
    run fc-cache -f
    run vim -E -s -c 'PluginInstall' -c 'qa!'
fi
if $DRY_RUN; then
    printf '\nPreview complete; no changes made.\n'
    exit 0
fi
printf '\nSetup finished. Log out and back in for group membership and PATH changes.\n'
printf 'Select i3 at login. Sign in to OpenCode/MCP, gcloud, GitHub, Slack, and Tailscale.\n'
printf 'See README.md for vaults, VM disks, optional tools, and rollback.\n'
