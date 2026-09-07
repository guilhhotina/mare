from pathlib import Path
import argparse
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description='Maré no core native, sem browser')
parser.add_argument('--core', default=os.environ.get('CORE_BIN', str(ROOT.parent / 'core-native-desktop/build-zcis/bin/core')))
parser.add_argument('--build', action='store_true')
parser.add_argument('--port', type=int, default=8788)
parser.add_argument('--window', default='1280x720')
args = parser.parse_args()
if args.build:
    subprocess.run([sys.executable, str(ROOT / 'tools/build_native.py')], check=True, cwd=ROOT)
core = Path(args.core).expanduser().resolve()
output = ROOT / 'dist/native'
if not core.is_file():
    parser.error('core não encontrado; informe --core ou CORE_BIN')
if not (output / 'game.lua').is_file():
    parser.error('bundle ausente; rode npm run build:native ou use --build')
os.chdir(output)
os.execv(core, [str(core), '--conf', 'native.toml', '--screen', '1280x720', '--window', args.window, '--fps', '30', '--port', str(args.port), '--engine', 'main.lua', '--game', 'game.lua'])
