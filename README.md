# Laptop setup

An installer for **Ubuntu 24.04 / 26.04 on Intel/AMD laptops**. Run it as your
normal user. It asks for sudo when installing system packages.

## 1. Export the current machine

Close applications whose settings you want to capture. From this checkout:

```bash
python3 scripts/migrate.py export "$HOME/fea-settings.tar.gz.gpg" --include-secrets --vault "$HOME/git/my-second-brain/Zettelkasten"
```

GPG asks you for a passphrase and encrypts the archive. Transfer it privately to
the new laptop (USB, SSH, or your private storage), for example into `$HOME`.
Keep the passphrase separately. Do not upload this archive to GitHub.

- Captures your current Bash, Git, Vim/Neovim, Byobu, i3, Alacritty, Rofi,
  fonts, OpenCode agents/configuration/skills, and external Claude/agent skills.
- `--include-secrets` includes `~/.secrets`, used by your OpenCode MCP servers.
  The OpenCode configuration itself can also contain embedded credentials.
- `--vault` includes the named vault, including `.obsidian` plugins/settings.
  Omit it to transfer notes separately. Repeat it for additional vaults inside HOME.
- Records manually installed apt packages for reference, rather than replaying
  old kernel versions and company-managed packages.
- Excludes Git metadata, `node_modules`, editor swap files, and Python caches.
  Skill symlinks are copied as actual files.
- Provider/MCP login tokens, SSH/GPG keys, browser sessions, VM disks, system
  services, and project repositories are not exported. Sign in or transfer those
  separately. The included vault is the explicit exception for project data.

## 2. Install on the new laptop

For the local checkout, which works before publishing these new files:

```bash
bash install.sh --restore "$HOME/fea-settings.tar.gz.gpg"
```

After committing and pushing the installer to `dev_time_keeper_improve`, this is
the remote one-liner. It installs curl if necessary, downloads a bootstrap file,
clones the repository, and runs the installer with your private settings:

```bash
sudo apt-get update && sudo apt-get install -y curl ca-certificates && (bootstrap=$(mktemp) && trap 'rm -f "$bootstrap"' EXIT && curl -fsSL https://raw.githubusercontent.com/ibreschi/fea_config/dev_time_keeper_improve/bootstrap.sh -o "$bootstrap" && bash "$bootstrap" --restore "$HOME/fea-settings.tar.gz.gpg")
```

The repository must be accessible over HTTPS. If it is private, transfer the
checkout and use the local command. Set `FEA_REF` to use another published branch
and update the raw URL accordingly. Existing checkouts are not automatically
updated, so reruns use the files already present in `$HOME/git/fea_config`.

## Applications

The default `development` profile installs:

- Desktop: i3, i3status-rust 0.34.0, Rofi, Alacritty, wallpaper tools, fonts,
  audio/Bluetooth/network controls, KDE Connect, Obsidian.
- Terminal: Vim with Vundle plugins, Neovim, Byobu/tmux, Git/delta, GitHub CLI,
  fzf, ripgrep/ag, translation tools, Python/pipx/uv, i3-resurrect, Watson.
- Virtual machines: virt-manager, libvirt, QEMU/KVM, virtiofs, and SPICE.
- Development: Docker Engine with Compose/buildx, Node 22 through nvm, Google
  Cloud CLI and GKE auth, kubectl, VS Code, Microsoft Edge, Slack, Tailscale,
  Snyk, Claude Code, Codex, and Headroom with MCP support.
- Supporting tools: Python formatters, Java, Ansible, database clients,
  HTTP/network utilities, Graphviz, Pandoc, and OpenFortiVPN.

Package lists live in `packages/desktop.txt` and `packages/development.txt`.
Add Ubuntu package names there as your needs change. External application
installers live in `install.sh`. OpenCode uses its official install script.

```bash
bash install.sh --dry-run                                  # Print actions; change nothing
bash install.sh --profile desktop                          # Smaller desktop profile
bash install.sh --config-only --restore ~/fea-settings.tar.gz.gpg
```

The desktop profile also installs OpenCode, but its development/MCP tools need
the full development profile. Third-party repositories must support your Ubuntu
release; failures stop the installer so you can fix them and rerun. Ubuntu 26.04
is a supported target by design, not yet verified on a fresh laptop here.

## After installation

- Log out and back in, then choose i3 from the login screen. Group membership
  enables Docker and libvirt access. Firmware must enable hardware virtualization.
- Quit and restart OpenCode. Reconnect providers and OAuth MCP servers.
  OpenCode plugins install when OpenCode starts.
- Sign in to GitHub (`gh auth login`), Google Cloud (`gcloud auth login`),
  Slack, Snyk, and Tailscale (`sudo tailscale up`) as needed.
- Open your Obsidian vault. Home-directory references are rewritten when your
  Linux username changes. External paths, synced-skill resource paths, monitor
  names, Bluetooth devices, and audio devices may still need adjustment.
- The older `kx`/`kn` aliases use built-in kubectl context/namespace commands;
  no krew installation is required.
- Your local Headroom/Anthropic proxy configuration is preserved. Start the
  corresponding proxy services separately if your provider uses localhost.
- Company-managed Intune, Qualys, SenseOn, proprietary FortiClient, Cursor,
  Claude Desktop, Android Studio, Pulumi, and custom dmake tooling need separate
  installation if still required. The old apt inventory is restored to
  `~/.local/state/fea_config/old-apt-manual.txt` for that review.
- Your i3 time-keeper service is documented in `time_keeper/README.md`; install
  it separately if you still use it.

## Backups and reruns

Installation copies files, preserving existing changed files under
`~/.local/state/fea_config/backups/<timestamp>/`. Restoring a private archive
overrides the repository defaults and creates another backup. Identical files
are skipped. Restore desired backup files to their original paths to roll back.

Package managers can safely be rerun. Existing Obsidian/OpenCode installations
are kept; apt installs may update packages. The installer does not replace the
Ubuntu desktop, import running VM images, or recreate remote account access.

`station_config.txt` and `work_config.md` remain historical references.
