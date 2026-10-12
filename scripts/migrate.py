#!/usr/bin/env python3
"""Copy dotfiles and transport current settings in an encrypted private archive."""
import argparse
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile


SETTINGS = [
    '.bashrc', '.bash_aliases', '.bash_completion', '.bash_deepo_aliases',
    '.gitconfig', '.gitignore_global', '.vimrc', '.pythonrc', '.tmux.conf',
    '.byobu', '.i3', '.config/byobu', '.config/i3', '.config/i3status-rust',
    '.config/i3-resurrect', '.config/i3-layout-manager', '.config/alacritty',
    '.config/rofi', '.config/nvim', '.config/flake8', '.config/pep8',
    '.config/opencode', '.claude/skills', '.agents/skills',
    '.local/share/fonts', '.local/share/rofi', '.local/share/i3status-rust',
]
SKIP = {'.git', '.serena', '__pycache__', 'node_modules', 'tags', '.DS_Store'}
SUFFIXES = {'.swp', '.swo', '.pyc', '.headroom-backup'}


def copy_settings(source, destination, ancestors=()):
    """Dereference skill symlinks, but never recursively follow a cycle."""
    real = source.resolve()
    if real in ancestors:
        raise ValueError(f'Symlink cycle in {source}')
    if source.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        for child in sorted(source.iterdir()):
            if child.name in SKIP or child.suffix in SUFFIXES:
                continue
            if child.is_symlink() and not child.exists():
                print(f'Skipping broken symlink: {child}')
                continue
            copy_settings(child, destination / child.name, (*ancestors, real))
    elif source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def normalize(relative, content, old_home, home, repo):
    content = content.replace(old_home, str(home))
    if relative.name == '.gitconfig':
        content = re.sub(r'(excludesfile\s*=\s*).*', r'\1~/.gitignore_global', content)
    if relative.as_posix() == '.config/i3/config':
        content = content.replace(
            f'{home}/git/fea_config/minimalistic-shapes-dark-neon-puzzle.jpg',
            str(repo / 'imgs/minimalistic-shapes-dark-neon-puzzle.jpg'))
        content = content.replace(f'{home}/.cargo/bin/i3status-rs', 'i3status-rs')
        content = content.replace('status_command i3status-rs ',
                                  f'status_command "{home}/.local/bin/i3status-rs" ')
        content = content.replace(f'{home}/.config/i3status-rust/config.toml',
                                  f'"{home}/.config/i3status-rust/config.toml"')
        content = content.replace('exec i3-sensible-terminal', 'exec alacritty')
        content = content.replace('set $i3_resurrect i3-resurrect',
                                  f'set $i3_resurrect "{home}/.local/bin/i3-resurrect"')
    if relative.name == '.bashrc':
        content = content.replace('/usr/bin/python3.8', '/usr/bin/python3')
        # Old configurations source tools unconditionally; guard missing tools.
        lines = []
        for line in content.splitlines():
            match = re.fullmatch(r'(?:source|\.)\s+(.+)', line)
            if match and '<(' not in line:
                path = match[1]
                lines.append(f'[ -f {path} ] && source {path}')
            elif line.startswith('source <(kubectl completion bash)'):
                lines.append('command -v kubectl >/dev/null && source <(kubectl completion bash)')
            elif line.startswith('eval "$(uv'):
                command = 'uvx' if 'uvx ' in line else 'uv'
                lines.append(f'command -v {command} >/dev/null && {line}')
            else:
                lines.append(line)
        content = '\n'.join(lines) + '\n'
        marker = '# fea_config portable paths'
        if marker not in content:
            # PATH must be set before completions and aliases are evaluated.
            content = (f'{marker}\n'
                       'export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.opencode/bin:$HOME/.cargo/bin:$PATH"\n'
                       'export NVM_DIR="$HOME/.nvm"\n'
                       '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"\n'
                       + content)
    if relative.name == '.bash_aliases':
        content = content.replace("alias dc='docker-compose'", "alias dc='docker compose'")
        content = re.sub(r'^source (.+)$', r'[ -f \1 ] && source \1', content, flags=re.M)
        # Source complete-alias before registering its completion function.
        source = '[ -f "$HOME/git/complete-alias/complete_alias" ] && source "$HOME/git/complete-alias/complete_alias"\n'
        content = source + content
        content = re.sub(r'^(\s*)complete -F _complete_alias (.+)$',
                         r'\1declare -F _complete_alias >/dev/null && complete -F _complete_alias \2', content, flags=re.M)
        for name, plugin in [('kx', 'ctx'), ('kn', 'ns')]:
            content = re.sub(rf'^alias {name}=.*$',
                             f"alias {name}='kubectl config {'use-context' if plugin == 'ctx' else 'set-context --current --namespace'}'",
                             content, flags=re.M)
    if relative.as_posix() in {'.config/opencode/opencode.json', '.config/opencode/opencode.jsonc'}:
        # JSONC is retained verbatim except for home and executable paths.
        content = re.sub(re.escape(str(home)) + r'/\.nvm/versions/node/[^/]+/bin/(npx|snyk)', r'\1', content)
        if relative.suffix == '.json':
            data = json.loads(content)
            for server in data.get('mcp', {}).values():
                environment = server.get('environment', {})
                if 'PATH' in environment and '/.nvm/versions/node/' in environment['PATH']:
                    environment['PATH'] = f'{home}/.local/npm/bin:{home}/.local/bin:/usr/local/bin:/usr/bin:/bin'
            content = json.dumps(data, indent=2) + '\n'
    return content


def apply_tree(tree, home, old_home, repo):
    timestamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = home / '.local/state/fea_config/backups' / timestamp
    count = 0
    for source in sorted(tree.rglob('*')):
        if not source.is_file():
            continue
        relative = source.relative_to(tree)
        destination = home / relative
        # Never write through an existing configuration-directory symlink.
        for parent in relative.parents:
            if parent == Path('.'):
                continue
            target = home / parent
            if target.is_symlink():
                saved = backup / parent
                saved.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(target), str(saved))
        raw = source.read_bytes()
        # Rewrite configurations, not arbitrary text in exported vaults/secrets.
        if relative.parts[0].startswith('.') and relative.parts[0] != '.secrets':
            try:
                text = raw.decode('utf-8')
            except UnicodeDecodeError:
                pass
            else:
                raw = normalize(relative, text, old_home, home, repo).encode('utf-8')
        if destination.is_file() and not destination.is_symlink() and destination.read_bytes() == raw:
            continue
        if destination.exists() or destination.is_symlink():
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(destination), str(saved))
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        # Private restored files remain private. Make local helpers executable.
        mode = source.stat().st_mode & 0o777
        if relative.parts[:2] == ('.local', 'bin'):
            mode |= 0o100
        destination.chmod(mode)
        count += 1
    print(f'Applied {count} files. Backup location: {backup}')


def install(args):
    repo = args.repo.resolve()
    with tempfile.TemporaryDirectory(prefix='fea-dotfiles-') as temporary:
        tree = Path(temporary)
        for source in (repo / 'home').iterdir():
            if source.name == 'dot_config':
                copy_settings(source, tree / '.config')
            elif source.name == 'dot_local':
                for directory in ('bin', 'share'):
                    copy_settings(source / directory, tree / '.local' / directory)
            elif source.name.startswith('.'):
                copy_settings(source, tree / source.name)
        copy_settings(repo / 'byobu/.byobu', tree / '.byobu')
        # Use a personal override instead of overwriting /usr/share/byobu.
        (tree / '.byobu/.tmux.conf').write_text(
            'set -g history-limit 100000\nset -g status-position top\nset -g mode-keys vi\n')
        apply_tree(tree, args.home, '/home/ibreschi', repo)


def export(args):
    output = args.output.expanduser().absolute()
    if output.exists():
        raise ValueError(f'Refusing to overwrite {output}')
    if not output.parent.is_dir():
        raise ValueError(f'Output directory does not exist: {output.parent}')
    with tempfile.TemporaryDirectory(prefix='fea-export-') as temporary:
        root = Path(temporary)
        tree = root / 'home'
        tree.mkdir()
        for relative in SETTINGS + (['.secrets'] if args.include_secrets else []):
            source = args.home / relative
            if source.exists():
                copy_settings(source, tree / relative)
        # Only the registry, not Electron caches or browser sessions.
        registry = args.home / '.config/obsidian/obsidian.json'
        if registry.is_file():
            copy_settings(registry, tree / '.config/obsidian/obsidian.json')
        for vault in args.vault:
            vault = vault.expanduser().resolve()
            relative = vault.relative_to(args.home.resolve())
            if not vault.is_dir():
                raise ValueError(f'Vault is not a directory: {vault}')
            copy_settings(vault, tree / relative)
        metadata = {'format': 1, 'home': str(args.home),
                    'vaults_included': [str(path) for path in args.vault],
                    'secrets_included': args.include_secrets}
        (root / 'metadata.json').write_text(json.dumps(metadata, indent=2))
        inventory = subprocess.run(['apt-mark', 'showmanual'], capture_output=True, text=True, check=True)
        (root / 'apt-manual.txt').write_text(inventory.stdout)
        archive = root / 'settings.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            for name in ('home', 'metadata.json', 'apt-manual.txt'):
                tar.add(root / name, arcname=name)
        # GPG reads the passphrase from the terminal, never arguments or logs.
        try:
            subprocess.run(['gpg', '--symmetric', '--cipher-algo', 'AES256',
                            '--output', str(output), str(archive)], check=True)
            output.chmod(0o600)
        except BaseException:
            output.unlink(missing_ok=True)
            raise
    print(f'Encrypted settings archive: {output}')
    print('Includes private configuration. Transfer privately and keep the passphrase separately.')


def restore(args):
    with tempfile.TemporaryDirectory(prefix='fea-restore-') as temporary:
        root = Path(temporary)
        archive = root / 'settings.tar.gz'
        subprocess.run(['gpg', '--output', str(archive), '--decrypt', str(args.archive.expanduser())], check=True)
        extracted = root / 'extracted'
        extracted.mkdir()
        with tarfile.open(archive, 'r:gz') as tar:
            for member in tar.getmembers():
                path = Path(member.name)
                if path.is_absolute() or '..' in path.parts or not (member.isdir() or member.isfile()):
                    raise ValueError(f'Unsafe archive entry: {member.name}')
                if not path.parts or path.parts[0] not in {'home', 'metadata.json', 'apt-manual.txt'}:
                    raise ValueError(f'Unexpected archive entry: {member.name}')
            # Entries were checked above; no links, devices, or outside paths.
            tar.extractall(extracted, filter='data')
        metadata = json.loads((extracted / 'metadata.json').read_text())
        if metadata.get('format') != 1 or not str(metadata.get('home', '')).startswith('/') or metadata['home'] == '/':
            raise ValueError('Unrecognized archive metadata')
        apply_tree(extracted / 'home', args.home, metadata['home'], args.repo.resolve())
        inventory = args.home / '.local/state/fea_config/old-apt-manual.txt'
        inventory.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(extracted / 'apt-manual.txt', inventory)
        print('Restored current settings. Restart OpenCode to load agents, skills, and configuration.')
        print('Reauthenticate providers/MCP servers; vault contents need --vault at export or a separate copy.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home(), help=argparse.SUPPRESS)
    commands = parser.add_subparsers(dest='command', required=True)
    default_repo = Path(__file__).resolve().parents[1]
    setup = commands.add_parser('install', help='Install repository dotfiles with backups')
    setup.add_argument('--repo', type=Path, default=default_repo)
    setup.set_defaults(action=install)
    snapshot = commands.add_parser('export', help='Export current settings encrypted with a GPG passphrase')
    snapshot.add_argument('output', type=Path)
    snapshot.add_argument('--include-secrets', action='store_true', help='Also include ~/.secrets')
    snapshot.add_argument('--vault', action='append', type=Path, default=[], help='Include an Obsidian vault inside HOME; repeatable')
    snapshot.set_defaults(action=export)
    recover = commands.add_parser('restore', help='Restore an encrypted settings archive with backups')
    recover.add_argument('archive', type=Path)
    recover.add_argument('--repo', type=Path, default=default_repo)
    recover.set_defaults(action=restore)
    args = parser.parse_args()
    args.home = args.home.expanduser().absolute()
    args.action(args)


if __name__ == '__main__':
    main()
