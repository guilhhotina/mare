from pathlib import Path
import argparse
import fcntl
import runpy
import shutil
from native_assets import build

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description='Gera o bundle nativo do Maré')
parser.add_argument('--output', type=Path, default=ROOT / 'dist/native')
args = parser.parse_args()
output = args.output.expanduser().resolve()
output.parent.mkdir(parents=True, exist_ok=True)
lock = open(output.parent / (output.name + '.lock'), 'a')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    parser.error('bundle em uso; escolha outro destino com --output')
result = runpy.run_path(str(ROOT / 'tools/build.py'))
output.mkdir(parents=True, exist_ok=True)
(output / 'cache').mkdir(exist_ok=True)
build(output / 'assets')
shutil.copytree(ROOT / 'src/native', output / 'lua/native', dirs_exist_ok=True)
shutil.copy2(ROOT / 'web/main.lua', output / 'main.lua')
shutil.copy2(ROOT / 'tools/native.toml', output / 'native.toml')
source = "local Platform=require('lua.native.platform')\nlocal app=(function()\n" + result['bundle'] + '\nend)()\nreturn Platform.attach(app)\n'
(output / 'game.lua').write_text(source)
(output / 'runtime.json').write_text('{"storage_format":1}\n')
print('Native bundle:', output)
