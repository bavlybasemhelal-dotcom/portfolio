param([string]$Login = 'admin@gmail.com')
$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$taskNode = (Get-Command node -ErrorAction Stop).Source
$taskPassword = Read-Host 'Choose a YOGEN password (12-128 characters)' -AsSecureString
$taskConfirm = Read-Host 'Repeat the password' -AsSecureString
$taskFirstPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskPassword)
$taskSecondPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskConfirm)
try {
  $taskPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskFirstPointer)
  $taskRepeat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskSecondPointer)
  if ($taskPlain -cne $taskRepeat) { throw 'Passwords do not match.' }
  if ($taskPlain.Length -lt 12 -or $taskPlain.Length -gt 128) { throw 'Use 12-128 characters.' }
  @{login=$Login;password=$taskPlain} | ConvertTo-Json -Compress | & $taskNode (Join-Path $PSScriptRoot 'set-owner-access.cjs')
  if ($LASTEXITCODE -ne 0) { throw 'The account password was not updated.' }
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskFirstPointer)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskSecondPointer)
  $taskPlain = $null; $taskRepeat = $null
  $taskPassword.Dispose(); $taskConfirm.Dispose()
}
