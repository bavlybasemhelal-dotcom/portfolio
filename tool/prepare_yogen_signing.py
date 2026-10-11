"""Create a persistent local Android signing key; never print passwords."""
import json
import os
import pathlib
import secrets
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
private = root / '.runtime/release-keys'
private.mkdir(parents=True, exist_ok=True)
keystore = private / 'yogen-signing.jks'
password_file = private / 'signing.local.json'
properties = root / 'android/key.properties'
if keystore.exists() != password_file.exists():
    raise SystemExit('Signing files are incomplete; preserve them and recover the missing file. No key replaced.')
if not keystore.exists():
    password = secrets.token_urlsafe(36)
    env = dict(os.environ, YOGEN_KEYSTORE_PASSWORD=password)
    result = subprocess.run([
        r'C:\Program Files\Java\jdk-17\bin\keytool.exe',
        '-genkeypair', '-keystore', str(keystore), '-storetype', 'JKS',
        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
        '-alias', 'yogen', '-dname', 'CN=YOGEN',
        '-storepass:env', 'YOGEN_KEYSTORE_PASSWORD',
        '-keypass:env', 'YOGEN_KEYSTORE_PASSWORD', '-noprompt',
    ], env=env, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('Android signing key generation failed. No release published.')
    password_file.write_text(json.dumps({'alias': 'yogen', 'password': password}, indent=2), encoding='utf-8')
secret = json.loads(password_file.read_text(encoding='utf-8'))
properties.write_text(
    'storeFile=' + keystore.as_posix() + '\nkeyAlias=' + secret['alias'] +
    '\nstorePassword=' + secret['password'] + '\nkeyPassword=' + secret['password'] + '\n',
    encoding='utf-8',
)
print(json.dumps({'signingKeyReady': True, 'privateDirectory': '.runtime/release-keys', 'credentialsPrinted': False}))
