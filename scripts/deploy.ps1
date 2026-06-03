#!/usr/bin/env pwsh
# ─── superapp-api deploy helper (Windows → evans) ─────────────────────────────
# Pushes the local commit via git, then SSHes to the server to run deploy.sh.
# Mirrors the GitHub Actions deploy job (ci.yml) but for local dev.
[CmdletBinding()]
param(
  [string]$HostAlias   = 'evans',
  [string]$RemoteDir   = '~/Project/superapp',
  [string]$RemoteScript = 'scripts/deploy.sh',
  [switch]$SkipPush,
  [switch]$SkipBuild,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$LocalRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

# ─── Pre-flight ─────────────────────────────────────────────────────────────
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  throw "ssh not found in PATH. Install OpenSSH for Windows."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git not found in PATH."
}

Write-Host "==> Pre-flight: test SSH to $HostAlias" -ForegroundColor Cyan
$probe = ssh -o BatchMode=yes -o ConnectTimeout=8 $HostAlias 'echo ok && uname -s'
if ($LASTEXITCODE -ne 0) { throw "SSH to $HostAlias failed" }
Write-Host "    connected: $probe"

# ─── Step 1: git push (if not skipped) ──────────────────────────────────────
if (-not $SkipPush) {
  Write-Host "==> Checking git status in $LocalRoot" -ForegroundColor Cyan
  Push-Location $LocalRoot
  try {
    $status = (& git status --porcelain) -join "`n"
    if ($status) {
      Write-Host "    Working tree has changes:" -ForegroundColor Yellow
      Write-Host "    $($status -split "`n" | Select-Object -First 20 | ForEach-Object { "    $_" })"
      $answer = Read-Host "    Continue with 'git add -A && git commit'? (y/N)"
      if ($answer -ne 'y') { throw "Aborted by user" }
      & git add -A
      & git commit -m "deploy: snapshot from Windows $(Get-Date -Format o)"
    }

    $branch = (& git branch --show-current).Trim()
    Write-Host "==> git push origin $branch" -ForegroundColor Cyan
    if ($DryRun) {
      Write-Host "    (dry-run: would push)" -ForegroundColor Yellow
    } else {
      & git push origin $branch
      if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)" }
    }
  } finally {
    Pop-Location
  }
} else {
  Write-Host "==> Skipping git push (--SkipPush)" -ForegroundColor Yellow
}

# ─── Step 2: remote deploy.sh ──────────────────────────────────────────────
$deployCmd = "bash $RemoteDir/$RemoteScript"
if ($SkipBuild)  { $deployCmd += " --no-restart" }
if ($DryRun)     { Write-Host "==> Dry-run: would run '$deployCmd' on $HostAlias" -ForegroundColor Yellow; return }

Write-Host "==> Remote: $deployCmd" -ForegroundColor Cyan
ssh $HostAlias $deployCmd
if ($LASTEXITCODE -ne 0) {
  throw "Remote deploy failed (exit $LASTEXITCODE)"
}

Write-Host "==> Deploy complete" -ForegroundColor Green
