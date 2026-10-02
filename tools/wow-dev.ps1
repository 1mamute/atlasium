<#
.SYNOPSIS
  Drives a running WoW 3.3.5a client for in-game checks of Atlasium.

.DESCRIPTION
  status      Reports whether the client is running and whether the add-on changed in a way
              that /reload cannot pick up (a restart is needed).
  reload      Types /reload, checks that the UI reloaded, waits for it to load, takes a WoW
              screenshot and prints its path.
  screenshot  Takes a WoW screenshot without reloading and prints its path.

  Commands are typed into the WoW chat box with window messages, so the client stays in the
  background and you can keep using the computer.

  The WoW folder comes from -WowDir, else the ATLASIUM_WOW_DIR environment variable, else
  ATLASIUM_WOW_DIR in the repo's .env file (see .env.example).
  Exit codes: 0 ok, 2 client not running, 3 restart needed, 4 screenshot not found,
  5 reload did not happen.

.EXAMPLE
  ./tools/wow-dev.ps1 status
  ./tools/wow-dev.ps1 reload -LoadDelay 10
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('status', 'reload', 'screenshot')]
  [string]$Mode = 'status',
  [string]$WowDir = $env:ATLASIUM_WOW_DIR,
  [int]$LoadDelay = 8,
  [int]$ShotTimeout = 10
)

$ErrorActionPreference = 'Stop'
$RepoDir = Join-Path $PSScriptRoot '..' | Resolve-Path
$AddonDir = Join-Path $RepoDir 'Atlasium' | Resolve-Path

# Reads KEY=VALUE lines from the repo's .env. Blank lines, # comments and surrounding quotes are ignored.
function Read-DotEnv($path) {
  $vars = @{}
  if (-not (Test-Path $path)) { return $vars }
  foreach ($line in Get-Content $path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
      $vars[$Matches[1]] = $Matches[2] -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1'
    }
  }
  $vars
}

# -WowDir wins, then the environment variable, then .env.
if (-not $WowDir) { $WowDir = (Read-DotEnv (Join-Path $RepoDir '.env'))['ATLASIUM_WOW_DIR'] }

if (-not $WowDir -or -not (Test-Path $WowDir)) {
  throw "Set ATLASIUM_WOW_DIR in .env (see .env.example) to the WoW 3.3.5a folder (got '$WowDir')."
}
$ShotDir = Join-Path $WowDir 'Screenshots'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WowInput {
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  const uint WM_KEYDOWN = 0x100, WM_KEYUP = 0x101, WM_CHAR = 0x102;

  public static void Key(IntPtr h, int vk, int scan) {
    int down = 1 | (scan << 16);
    PostMessage(h, WM_KEYDOWN, (IntPtr)vk, (IntPtr)down);
    PostMessage(h, WM_KEYUP, (IntPtr)vk, (IntPtr)(down | (1 << 30) | (1 << 31)));
  }

  public static void Chars(IntPtr h, string text) {
    foreach (char c in text) PostMessage(h, WM_CHAR, (IntPtr)c, (IntPtr)1);
  }
}
'@

function Get-WowProcess {
  Get-Process -Name 'Wow', 'WoW' -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
}

# The add-on file list as first seen for a client process. Creation times are not usable for this:
# editors that save by replacing the file give an edited file a new creation time.
$StatePath = Join-Path $env:TEMP 'atlasium-wow-dev.json'

function Get-KnownFiles($proc, $current) {
  $state = $null
  if (Test-Path $StatePath) { $state = Get-Content $StatePath -Raw | ConvertFrom-Json }
  if (-not $state -or $state.pid -ne $proc.Id) {
    $state = [pscustomobject]@{ pid = $proc.Id; files = @($current) }
    $state | ConvertTo-Json | Set-Content $StatePath
  }
  @($state.files)
}

# Files the client only reads at startup: .toc changes, new files, textures.
function Get-RestartReasons($proc) {
  $started = $proc.StartTime
  $files = Get-ChildItem $AddonDir -Recurse -File
  $current = $files | ForEach-Object { $_.FullName.Substring($AddonDir.Path.Length + 1) }
  $known = Get-KnownFiles $proc $current
  $reasons = @()
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($AddonDir.Path.Length + 1)
    if ($f.Extension -eq '.toc' -and $f.LastWriteTime -gt $started) {
      $reasons += "$rel changed"
    } elseif ($rel -notin $known) {
      $reasons += "$rel is new"
    } elseif ($f.Extension -in '.blp', '.tga' -and $f.LastWriteTime -gt $started) {
      $reasons += "$rel texture changed (may be cached)"
    }
  }
  $reasons
}

# Types a slash command into the chat box of the (background) client window: Enter opens the box,
# the text goes in as characters, Enter sends it. Anything that is not a slash command would be
# said in public chat, so it is refused.
function Send-Chat($proc, $text) {
  if ($text -notmatch '^/[a-z]+( |$)') { throw "Refusing to send '$text': not a slash command." }
  $h = $proc.MainWindowHandle
  [WowInput]::Key($h, 0x0D, 0x1C)                    # VK_RETURN
  Start-Sleep -Milliseconds 200
  [WowInput]::Chars($h, $text)
  Start-Sleep -Milliseconds 200
  [WowInput]::Key($h, 0x0D, 0x1C)
}

# The client writes SavedVariables on every reload, so their write time shows that a reload happened.
function Get-SavedVariablesTime {
  $files = Get-ChildItem (Join-Path $WowDir 'WTF\Account\*\SavedVariables\Atlasium.lua') -ErrorAction SilentlyContinue
  ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
}

function Take-Screenshot($proc) {
  $since = Get-Date
  Send-Chat $proc '/run Screenshot()'
  $deadline = $since.AddSeconds($ShotTimeout)
  while ((Get-Date) -lt $deadline) {
    $shot = Get-ChildItem $ShotDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -ge $since -and $_.Length -gt 0 } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($shot) {
      Start-Sleep -Milliseconds 300                  # let the client finish writing
      return $shot.FullName
    }
    Start-Sleep -Milliseconds 250
  }
  $null
}

$proc = Get-WowProcess
if (-not $proc) {
  Write-Output 'NOT_RUNNING: start the client and log in a character.'
  exit 2
}

$reasons = @(Get-RestartReasons $proc)
if ($reasons.Count -gt 0) {
  Write-Output 'RESTART_NEEDED:'
  $reasons | ForEach-Object { Write-Output "  $_" }
  exit 3
}

switch ($Mode) {
  'status' {
    Write-Output "RUNNING: pid $($proc.Id), started $($proc.StartTime)"
  }
  'reload' {
    $since = Get-Date
    Send-Chat $proc '/reload'
    Start-Sleep -Seconds $LoadDelay
    $proc = Get-WowProcess
    if (-not $proc) { Write-Output 'NOT_RUNNING: client exited during reload.'; exit 2 }
    $saved = Get-SavedVariablesTime
    if (-not $saved -or $saved -lt $since) {
      Write-Output 'NO_RELOAD: SavedVariables were not written, so /reload did not run.'
      exit 5
    }
    $shot = Take-Screenshot $proc
    if (-not $shot) { Write-Output "NO_SCREENSHOT: nothing new in $ShotDir"; exit 4 }
    Write-Output "SCREENSHOT: $shot"
  }
  'screenshot' {
    $shot = Take-Screenshot $proc
    if (-not $shot) { Write-Output "NO_SCREENSHOT: nothing new in $ShotDir"; exit 4 }
    Write-Output "SCREENSHOT: $shot"
  }
}
