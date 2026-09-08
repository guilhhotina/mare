from pathlib import Path
import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from storage_migration import migrate_storage

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description='Maré no core native, sem browser')
parser.add_argument('--core', default=os.environ.get('CORE_BIN', str(ROOT.parent / 'core-native-desktop/build-zcis/bin/core')))
parser.add_argument('--build', action='store_true')
parser.add_argument('--port', type=int, default=8788)
parser.add_argument('--window', default='1280x720')
parser.add_argument('--instance', help='nome de uma instância isolada; reutiliza seu snapshot e seus saves')
parser.add_argument('--bundle', type=Path, default=ROOT / 'dist/native', help='bundle de origem para execução ou criação de snapshot')
args = parser.parse_args()
if args.instance and not re.fullmatch(r'[A-Za-z0-9_-]+', args.instance):
    parser.error('--instance deve conter apenas letras, números, hífen ou sublinhado')
output = args.bundle.expanduser().resolve()
if args.build:
    subprocess.run([sys.executable, str(ROOT / 'tools/build_native.py'), '--output', str(output)], check=True, cwd=ROOT)
core = Path(args.core).expanduser().resolve()
if not core.is_file():
    parser.error('core não encontrado; informe --core ou CORE_BIN')
if not (output / 'game.lua').is_file():
    parser.error('bundle ausente; rode npm run build:native ou use --build')
instance = ROOT / 'dist/instances' / args.instance if args.instance else output
instance.parent.mkdir(parents=True, exist_ok=True)
lock = open(instance.parent / (instance.name + '.lock'), 'a')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    parser.error('esta instância já está em execução')
os.set_inheritable(lock.fileno(), True)
if args.instance:
    if instance.exists() and not (instance / 'build.json').is_file():
        parser.error('snapshot incompleto; use outro nome de instância')
    if not instance.exists():
        bundle_lock = open(output.parent / (output.name + '.lock'), 'a')
        try:
            fcntl.flock(bundle_lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error('bundle em compilação; aguarde antes de criar o snapshot')
        instance.mkdir(parents=True)
        for name in ('game.lua', 'main.lua', 'native.toml'):
            shutil.copy2(output / name, instance / name)
        if (output / 'runtime.json').is_file():
            shutil.copy2(output / 'runtime.json', instance / 'runtime.json')
        for name in ('assets', 'lua'):
            shutil.copytree(output / name, instance / name)
        (instance / 'cache').mkdir()
        digest = hashlib.sha256()
        for file in sorted(instance.rglob('*')):
            if file.is_file():
                digest.update(str(file.relative_to(instance)).encode())
                digest.update(file.read_bytes())
        (instance / 'build.json').write_text(json.dumps({'sha256': digest.hexdigest()}, indent=2) + '\n')
        bundle_lock.close()
    output = instance
try:
    runtime_path = output / 'runtime.json'
    if runtime_path.is_file():
        runtime = json.loads(runtime_path.read_text())
        if not isinstance(runtime, dict) or type(runtime.get('storage_format')) is not int or runtime['storage_format'] != 1:
            parser.error('versao de transporte de saves nao suportada')
        migrate_storage(output / 'app.db')
except (ValueError, OSError, sqlite3.Error) as error:
    parser.error(f'nao foi possivel preparar os saves: {error}')
for cached in (output / 'cache').glob('texture-*.tga'):
    if re.fullmatch(r'texture-[0-9]+\.tga', cached.name):
        cached.unlink()
os.chdir(output)
os.execv(core, [str(core), '--conf', 'native.toml', '--screen', '1280x720', '--window', args.window, '--fps', '30', '--port', str(args.port), '--engine', 'main.lua', '--game', 'game.lua'])
