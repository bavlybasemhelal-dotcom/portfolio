$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
& node tool/backup_yogen_release.cjs
if ($LASTEXITCODE -ne 0) { throw 'Firestore snapshot did not finish.' }
& node tool/backup_yogen_script.mjs
if ($LASTEXITCODE -ne 0) { throw 'Apps Script snapshot did not finish.' }
Write-Output 'Data and script snapshots saved privately. Download current Projects/Brand/Team files separately from Drive; Firestore snapshots do not contain file bytes.'
