"""Shared release locations. Reading paths never builds or packages an app."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent


def release_identity(root=ROOT):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
                      (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)
    if not match:
        raise ValueError('pubspec.yaml must include version and build number.')
    return match.group(1), int(match.group(2))


def web_release_dir(root=ROOT):
    version, _ = release_identity(root)
    return root / 'releases' / version / 'web'


def sync_hosting_paths(root=ROOT):
    """Keep both Hosting configurations on the version built by the release tool."""
    public = web_release_dir(root).relative_to(root).as_posix()
    for name in ['firebase.json', 'firebase.company.json']:
        file = root / name
        if not file.exists():
            continue
        config = json.loads(file.read_text(encoding='utf-8'))
        if config['hosting']['public'] != public:
            config['hosting']['public'] = public
            file.write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
    return public


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sync', action='store_true',
                        help='Update Hosting paths only; never build or deploy.')
    args = parser.parse_args()
    public = (sync_hosting_paths() if args.sync
              else web_release_dir().relative_to(ROOT).as_posix())
    version, build = release_identity()
    print(json.dumps({'version': version, 'build': build, 'web': public,
                      'built': False, 'deployed': False}))
