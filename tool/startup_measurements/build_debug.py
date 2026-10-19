"""Build/preserve opted-in Debug APK locally. No installation or server access."""
import hashlib
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import time


def source_snapshot(repo):
    # Whole tracked build input surface, plus untracked instrumentation. Do not
    # include generated caches, local credentials or dependency directories.
    paths = subprocess.run(['git', '-C', str(repo), 'ls-files', '-c', '-o', '--exclude-standard'],
                           check=True, capture_output=True).stdout.decode().splitlines()
    allowed = ('lib/', 'packages/', 'android/', 'assets/', 'tool/startup_measurements/')
    return {name: hashlib.sha256((repo/name).read_bytes()).hexdigest()
            for name in sorted(set(paths)) if (name.startswith(allowed) or name in
                {'pubspec.yaml', 'pubspec.lock', 'melos.yaml', 'shorebird.yaml'}) and (repo/name).is_file()}


def main():
    repo = Path(__file__).resolve().parents[2]
    snapshot = source_snapshot(repo)
    build_id = hashlib.sha256(json.dumps(snapshot,sort_keys=True).encode()).hexdigest()
    out = repo/'build/device-test'/('instrumented-debug-'+time.strftime('%Y%m%d-%H%M%S')+'-'+secrets.token_hex(4))
    out.mkdir(parents=True,exist_ok=False)
    flutter = shutil.which('flutter')
    if flutter is None: raise SystemExit('Flutter unavailable')
    command=[flutter,'build','apk','--debug','--no-pub','--dart-define=STARTUP_MEASUREMENTS=true',
             '--dart-define=MEASUREMENT_BUILD_ID='+build_id]
    with (out/'build.log').open('w',encoding='utf-8') as log:
        result=subprocess.run(command,cwd=repo,stdout=log,stderr=subprocess.STDOUT)
    unchanged=source_snapshot(repo)==snapshot
    manifest={'protocol':4,'build_id':build_id,'source_sha256':snapshot,
              'command':command[1:],'exit_code':result.returncode,'source_unchanged':unchanged,
              'installed':False,'note':'Explicit VM marker checks build identity; APK SHA alone does not attest installation.'}
    if result.returncode==0 and unchanged:
        apk=out/'app-debug.apk'
        shutil.copy2(repo/'build/app/outputs/flutter-apk/app-debug.apk',apk)
        manifest['apk_sha256']=hashlib.sha256(apk.read_bytes()).hexdigest()
    (out/'build-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(out)
    return 0 if result.returncode==0 and unchanged else 1


if __name__=='__main__':raise SystemExit(main())
