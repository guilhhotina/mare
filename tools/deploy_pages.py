from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT):
    subprocess.run(args, cwd=cwd, check=True)


run(sys.executable, str(ROOT / 'tools/build.py'))
run('git', 'fetch', 'origin', 'gh-pages')
with tempfile.TemporaryDirectory(prefix='pages-', dir=ROOT / 'dist') as directory:
    target = Path(directory)
    run('git', 'worktree', 'add', '--detach', directory, 'origin/gh-pages')
    try:
        run('git', 'rm', '-r', '.', cwd=target)
        shutil.copytree(ROOT / 'web', target, dirs_exist_ok=True, ignore=shutil.ignore_patterns('*.db', '*.db-*'))
        (target / '.nojekyll').touch()
        run('git', 'add', '.', cwd=target)
        run('git', 'commit', '--allow-empty', '-m', 'Deploy Maré static site', cwd=target)
        run('git', 'push', 'origin', 'HEAD:gh-pages', cwd=target)
    finally:
        run('git', 'worktree', 'remove', '--force', directory)
print('https://guilhhotina.github.io/mare/')
