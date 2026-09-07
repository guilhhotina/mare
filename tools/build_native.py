from pathlib import Path
import runpy
import shutil
from native_assets import build

ROOT = Path(__file__).resolve().parents[1]
result = runpy.run_path(str(ROOT / 'tools/build.py'))
output = ROOT / 'dist/native'
output.mkdir(parents=True, exist_ok=True)
(output / 'cache').mkdir(exist_ok=True)
build(output / 'assets')
shutil.copytree(ROOT / 'src/native', output / 'lua/native', dirs_exist_ok=True)
shutil.copy2(ROOT / 'web/main.lua', output / 'main.lua')
shutil.copy2(ROOT / 'tools/native.toml', output / 'native.toml')
source = "local Platform=require('lua.native.platform')\nlocal app=(function()\n" + result['bundle'] + '\nend)()\nreturn Platform.attach(app)\n'
(output / 'game.lua').write_text(source)
print('Native bundle:', output)
