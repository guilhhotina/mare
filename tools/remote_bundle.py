from pathlib import Path
import hashlib
import shutil
import tempfile
from native_assets import build as build_assets, lua


def build(bundle, platform, root, output):
    temporary_root = root / 'dist'
    temporary_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='remote-assets-', dir=temporary_root) as directory:
        source = Path(directory)
        build_assets(source)
        files = sorted(source.iterdir())
        digest = hashlib.sha256()
        manifest = []
        for file in files:
            data = file.read_bytes()
            digest.update(file.name.encode())
            digest.update(data)
            manifest.append([file.name, len(data)])
        version = digest.hexdigest()[:16]
        destination = output / 'native' / version
        destination.mkdir(parents=True, exist_ok=True)
        for file in files:
            shutil.copy2(file, destination / file.name)
    modules = []
    for file in sorted((root / 'src/native').glob('*.lua')):
        name = 'lua.native.' + file.stem
        modules.append('package.preload[' + lua(name) + ']=function(...)\n' + file.read_text() + '\nend\n')
    native = ''.join(modules)
    native += "local Assets=require('lua.native.assets')\n"
    native += 'Assets.configure(' + lua('https://guilhhotina.github.io/mare/native/' + version + '/') + ',' + lua(manifest) + ')\n'
    native += "Platform=require('lua.native.platform')\n"
    return "local web=type(mare_load)=='function'\nlocal Platform\nif web then\nPlatform=(function()\n" + platform + '\nend)()\nelse\n' + native + '\nend\nlocal app=(function()\n' + bundle + '\nend)()\nif web then return app end\nreturn Platform.attach(app)\n'
