import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('migrate', ROOT / 'scripts/migrate.py')
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)
REAL_RUN = subprocess.run


def noninteractive_run(command, **kwargs):
    if command[0] == 'gpg':
        command = ['gpg', '--batch', '--pinentry-mode', 'loopback',
                   '--passphrase', 'test-only-passphrase', *command[1:]]
    elif command == ['apt-mark', 'showmanual']:
        return subprocess.CompletedProcess(command, 0, 'git\nvim\n', '')
    return REAL_RUN(command, **kwargs)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='fea-test-')
        self.root = Path(self.temp.name)
        self.home = self.root / 'new home'
        self.home.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def write(self, home, relative, content):
        path = home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_install_backups_and_repeatability(self):
        self.write(self.home, '.bashrc', 'original bashrc\n')
        args = SimpleNamespace(repo=ROOT, home=self.home)
        migrate.install(args)
        backups = list((self.home / '.local/state/fea_config/backups').glob('*/.bashrc'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'original bashrc\n')
        config = (self.home / '.config/i3/config').read_text()
        self.assertIn(str(ROOT / 'imgs/minimalistic-shapes-dark-neon-puzzle.jpg'), config)
        self.assertNotIn('/home/ibreschi/.config', config)
        self.assertNotIn('/home/ibreschi/.cargo', config)
        self.assertIn(f'status_command "{self.home}/.local/bin/i3status-rs"', config)
        self.assertIn('exec alacritty', config)
        before = {str(p): p.read_bytes() for p in self.home.rglob('*') if p.is_file()}
        migrate.install(args)
        after = {str(p): p.read_bytes() for p in self.home.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        self.assertFalse((self.home / '.local/file').exists())

    def test_existing_directory_symlink_is_backed_up(self):
        outside = self.root / 'external'
        outside.mkdir()
        self.write(outside, 'config', 'external file\n')
        (self.home / '.config').mkdir()
        (self.home / '.config/i3').symlink_to(outside, target_is_directory=True)
        migrate.install(SimpleNamespace(repo=ROOT, home=self.home))
        self.assertEqual((outside / 'config').read_text(), 'external file\n')
        self.assertFalse((self.home / '.config/i3').is_symlink())

    def test_roundtrip_private_settings_skills_and_vault(self):
        old = self.root / 'old'
        old.mkdir()
        config = {'mcp': {'playwright': {'command': [str(old) + '/.nvm/versions/node/v22.20.0/bin/npx'],
                                       'environment': {'PATH': str(old) + '/.nvm/versions/node/v22.20.0/bin:/usr/bin'}},
                          'test': {'environment': {'TOKEN': 'private-test-token'}}}}
        self.write(old, '.config/opencode/opencode.json', json.dumps(config))
        self.write(old, '.config/opencode/node_modules/ignored.js', 'cache')
        self.write(old, '.secrets/token', 'private-test-token').chmod(0o600)
        actual_skill = self.write(old, '.claude/skills/real/SKILL.md', 'skill instructions')
        (old / '.config/opencode/skills').mkdir()
        (old / '.config/opencode/skills/link').symlink_to(actual_skill.parent, target_is_directory=True)
        self.write(old, 'notes/.obsidian/plugins/example/data.json', '{"enabled":true}')
        self.write(old, 'notes/note.md', f'An old path {old} stays in the note.')
        output = self.root / 'archive.tar.gz.gpg'
        with patch.object(migrate.subprocess, 'run', side_effect=noninteractive_run):
            migrate.export(SimpleNamespace(home=old, output=output, include_secrets=True, vault=[old / 'notes']))
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            self.assertNotIn(b'private-test-token', output.read_bytes())
            migrate.restore(SimpleNamespace(home=self.home, archive=output, repo=ROOT))
        restored = json.loads((self.home / '.config/opencode/opencode.json').read_text())
        self.assertEqual(restored['mcp']['playwright']['command'], ['npx'])
        self.assertIn(str(self.home / '.local/bin'), restored['mcp']['playwright']['environment']['PATH'])
        self.assertEqual((self.home / '.secrets/token').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.home / '.config/opencode/skills/link/SKILL.md').read_text(), 'skill instructions')
        self.assertFalse((self.home / '.config/opencode/node_modules').exists())
        self.assertIn(str(old), (self.home / 'notes/note.md').read_text())
        self.assertTrue((self.home / 'notes/.obsidian/plugins/example/data.json').exists())

    def test_unsafe_archive_rejected_before_extraction(self):
        archive = self.root / 'unsafe.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            info = tarfile.TarInfo('../escaped')
            info.size = 3
            tar.addfile(info, io.BytesIO(b'bad'))
        output = self.root / 'unsafe.gpg'
        with patch.object(migrate.subprocess, 'run', side_effect=noninteractive_run):
            migrate.subprocess.run(['gpg', '--symmetric', '--output', str(output), str(archive)], check=True)
            with self.assertRaisesRegex(ValueError, 'Unsafe archive'):
                migrate.restore(SimpleNamespace(home=self.home, archive=output, repo=ROOT))
        self.assertEqual(list(self.home.iterdir()), [])

    def test_dry_run_has_no_filesystem_changes(self):
        before = list(self.home.rglob('*'))
        environment = {**os.environ, 'HOME': str(self.home)}
        result = REAL_RUN(['bash', str(ROOT / 'install.sh'), '--dry-run', '--restore', '/missing/archive.gpg'],
                          env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Preview complete; no changes made.', result.stdout)
        self.assertEqual(before, list(self.home.rglob('*')))


if __name__ == '__main__':
    unittest.main()
