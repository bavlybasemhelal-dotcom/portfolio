param([switch]$WebOnly, [switch]$AndroidOnly)
$ErrorActionPreference = 'Stop'
if ($WebOnly -and $AndroidOnly) { throw 'Choose one platform or omit both switches.' }
$releaseRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $releaseRoot
$releaseVersionMatch = [regex]::Match((Get-Content -LiteralPath 'pubspec.yaml' -Raw), '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
if (!$releaseVersionMatch.Success) { throw 'pubspec.yaml must include version and build number.' }
$releaseVersion = $releaseVersionMatch.Groups[1].Value
$releaseCode = [int]$releaseVersionMatch.Groups[2].Value
$releaseWeb = "releases/$releaseVersion/web"
$releaseLogs = Join-Path $releaseRoot ".runtime/updates/$releaseVersion/build-logs"
New-Item -ItemType Directory -Path $releaseLogs -Force | Out-Null
$flutterCommand = 'C:\dev\flutter\bin\flutter.bat'
$pythonCommand = 'C:\Users\Dell\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (!$AndroidOnly) {
    & $pythonCommand tool/prepare_launcher_assets.py
    if ($LASTEXITCODE -ne 0) { throw 'Launcher asset export failed.' }
    & $flutterCommand build web --release --no-pub --no-wasm-dry-run --output=$releaseWeb --dart-define-from-file=config/firebase.web.json --dart-define-from-file=config/drive.phase05.json --dart-define=YOGEN_SITE=yogen --dart-define=YOGEN_RELEASE=true 2>&1 | Tee-Object -FilePath (Join-Path $releaseLogs 'build-web.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Web release build failed.' }
}
if (!$WebOnly) {
    & $pythonCommand tool/prepare_yogen_signing.py
    if ($LASTEXITCODE -ne 0) { throw 'Android signing preparation failed.' }
    $env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
    $env:PATH = $env:JAVA_HOME + '\bin;' + $env:PATH
    $env:JAVA_TOOL_OPTIONS = '-XX:ActiveProcessorCount=2'
    $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false'
    & $flutterCommand build apk --release --no-pub --dart-define-from-file=config/firebase.android.json --dart-define-from-file=config/drive.phase05.json --dart-define=YOGEN_SITE=yogen --dart-define=YOGEN_RELEASE=true 2>&1 | Tee-Object -FilePath (Join-Path $releaseLogs 'build-android.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
}
$releaseAndroidMetadata = 'build/app/outputs/apk/release/output-metadata.json'
$releaseAndroidMatches = $false
if (Test-Path -LiteralPath $releaseAndroidMetadata) {
    $releaseAndroidInfo = Get-Content -LiteralPath $releaseAndroidMetadata -Raw | ConvertFrom-Json
    $releaseAndroidMatches = $releaseAndroidInfo.elements[0].versionName -eq $releaseVersion -and $releaseAndroidInfo.elements[0].versionCode -eq $releaseCode
}
if ((Test-Path "$releaseWeb/index.html") -and (Test-Path 'build/app/outputs/flutter-apk/app-release.apk') -and $releaseAndroidMatches) {
    & $pythonCommand tool/package_yogen_release.py
    if ($LASTEXITCODE -ne 0) { throw 'Release packaging failed.' }
}
Write-Output 'Release packaging finished. No tests or deployment were run by this script.'
