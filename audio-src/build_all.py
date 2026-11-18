"""全音声を再生成して検証する: python build_all.py"""
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
for script in ('sfx.py', 'music.py', 'verify.py'):
    subprocess.run([sys.executable, os.path.join(here, script)], cwd=here, check=True)
