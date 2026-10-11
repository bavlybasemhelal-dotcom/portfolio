"""Normalize public Firebase settings and platform identifiers; no OAuth data."""
import json
import pathlib
import plistlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]

def save(path, data):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

def replace(path, old, new):
    target = ROOT / path
    text = target.read_text(encoding='utf-8-sig')
    if old not in text:
        return
    target.write_text(text.replace(old, new), encoding='utf-8')

def settings(platform):
    raw = json.loads((ROOT / f'.runtime/firebase-sdk-{platform}.local.json').read_text(encoding='utf-8-sig'))['result']
    if platform == 'web':
        config = raw['sdkConfig']
    elif platform == 'android':
        native = json.loads(raw['fileContents'])
        client = native['client'][0]
        config = dict(apiKey=client['api_key'][0]['current_key'], appId=client['client_info']['mobilesdk_app_id'],
            messagingSenderId=native['project_info']['project_number'], projectId=native['project_info']['project_id'],
            storageBucket=native['project_info'].get('storage_bucket', ''))
        (ROOT / 'android/app/google-services.json').write_text(raw['fileContents'], encoding='utf-8')
    else:
        native = plistlib.loads(raw['fileContents'].encode())
        config = dict(apiKey=native['API_KEY'], appId=native['GOOGLE_APP_ID'], messagingSenderId=native['GCM_SENDER_ID'],
            projectId=native['PROJECT_ID'], storageBucket=native.get('STORAGE_BUCKET', ''), iosBundleId=native['BUNDLE_ID'])
        (ROOT / 'ios/Runner/GoogleService-Info.plist').write_text(raw['fileContents'], encoding='utf-8')
        (ROOT / 'macos/Runner/GoogleService-Info.plist').write_text(raw['fileContents'], encoding='utf-8')
    assert config['projectId'] == 'portfolio-14d15'
    mapping = {'apiKey': 'FIREBASE_API_KEY', 'appId': 'FIREBASE_APP_ID', 'messagingSenderId': 'FIREBASE_MESSAGING_SENDER_ID',
        'projectId': 'FIREBASE_PROJECT_ID', 'authDomain': 'FIREBASE_AUTH_DOMAIN', 'storageBucket': 'FIREBASE_STORAGE_BUCKET',
        'iosBundleId': 'FIREBASE_IOS_BUNDLE_ID'}
    save(f'config/firebase.{platform}.json', {mapping[k]: str(v) for k, v in config.items() if k in mapping})
    return {'platform': platform, 'appId': config['appId'], 'projectId': config['projectId']}

if __name__ == '__main__':
    apps = [settings(p) for p in ['web', 'android', 'apple']]
    save('phases/results/03/checks/firebase-apps.json', apps)
    replace('android/app/build.gradle.kts', 'com.yogen.yogen_portfolio', 'com.yogen.portfolio')
    old = ROOT / 'android/app/src/main/kotlin/com/yogen/yogen_portfolio/MainActivity.kt'
    new = ROOT / 'android/app/src/main/kotlin/com/yogen/portfolio/MainActivity.kt'
    if old.exists():
        assert old.resolve().is_relative_to(ROOT) and new.resolve().is_relative_to(ROOT)
        new.parent.mkdir(parents=True, exist_ok=True)
        new.write_text(old.read_text().replace('com.yogen.yogen_portfolio', 'com.yogen.portfolio'), encoding='utf-8')
        old.unlink()
    replace('android/app/src/main/AndroidManifest.xml', '<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application')
    replace('android/app/src/main/AndroidManifest.xml', 'android:label="yogen_portfolio"', 'android:label="YOGEN"')
    for path in ['ios/Runner.xcodeproj/project.pbxproj', 'macos/Runner/Configs/AppInfo.xcconfig']:
        replace(path, 'com.yogen.yogenPortfolio', 'com.yogen.portfolio')
    replace('macos/Runner/Configs/AppInfo.xcconfig', 'PRODUCT_NAME = yogen_portfolio', 'PRODUCT_NAME = YOGEN')
    replace('ios/Runner/Info.plist', '<string>Yogen Portfolio</string>', '<string>YOGEN</string>')
    replace('ios/Runner/Info.plist', '<string>yogen_portfolio</string>', '<string>YOGEN</string>')
    for path in ['macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements']:
        target = ROOT / path
        text = target.read_text()
        if 'com.apple.security.network.client' not in text:
            target.write_text(text.replace('</dict>', '<key>com.apple.security.network.client</key>\n\t<true/>\n</dict>'), encoding='utf-8')
    replace('windows/runner/main.cpp', 'L"yogen_portfolio"', 'L"YOGEN"')
    replace('windows/runner/Runner.rc', '"FileDescription", "yogen_portfolio"', '"FileDescription", "YOGEN"')
    replace('windows/runner/Runner.rc', '"ProductName", "yogen_portfolio"', '"ProductName", "YOGEN"')
    replace('linux/runner/my_application.cc', '"yogen_portfolio"', '"YOGEN"')
    replace('web/index.html', 'A new Flutter project.', 'YOGEN technical verification - Phase 03')
    replace('web/index.html', 'yogen_portfolio', 'YOGEN')
    replace('web/index.html', '<head>', '<head>\n  <meta name="robots" content="noindex,nofollow">')
    replace('web/manifest.json', '"yogen_portfolio"', '"YOGEN"')
    for family, files in {'ibmplexsansarabic': ['IBMPlexSansArabic-Regular.ttf', 'IBMPlexSansArabic-SemiBold.ttf', 'OFL.txt'],
                          'ibmplexsans': ['IBMPlexSans%5Bwdth%2Cwght%5D.ttf', 'OFL.txt']}.items():
        for name in files:
            path = ROOT / 'assets/fonts' / family / urllib.parse.unquote(name)
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                urllib.request.urlretrieve(f'https://raw.githubusercontent.com/google/fonts/main/ofl/{family}/{name}', path)
    print(json.dumps({'registeredApps': apps, 'nativePackage': 'com.yogen.portfolio', 'fonts': 'downloaded'}, ensure_ascii=True))
