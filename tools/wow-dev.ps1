<#
.SYNOPSIS
  Drives a running WoW 3.3.5a client for in-game checks of Atlasium.

.DESCRIPTION
  status      Reports whether the client is running and whether the add-on changed in a way
              that /reload cannot pick up (a restart is needed).
  reload      Types /reload, checks that the UI reloaded, waits for it to load, takes a WoW
              screenshot and prints its path.
  screenshot  Takes a WoW screenshot without reloading and prints its path.
  run         Types /run <Lua> (from -Lua), waits a moment, takes a WoW screenshot and prints
              its path. The chat box takes at most 255 characters.
  mapstate    Takes a screenshot, reads the map marker in its top-left corner and prints
              MAP_OPEN, MAP_CLOSED or NO_MARKER with the screenshot path.
  mapopen     Opens the world map when it is closed and checks the result with a screenshot.
  mapclose    Closes the world map when it is open and checks the result with a screenshot.

  Slash commands are typed into the WoW chat box with window messages, so the client stays in
  the background and you can keep using the computer.

  The map modes and the screenshots use keys, not the chat box. An open world map has the
  keyboard and ignores typed text, so chat would not work then. In debug mode (/atlasium debug)
  the add-on binds Num Pad * to open and close the map and Num Pad - to take a screenshot, and
  it shows a green (map open) or red (map closed) square in the top-left corner of the screen.
  The script reads that square from the screenshot. Without debug mode there is no marker and
  no key binding: the map modes report NO_MARKER, and screenshots need -ChatFallback.
  run and reload check the marker first and do not type while the map is open. Use -SkipMapCheck
  to skip that check in reload.

  The WoW folder comes from -WowDir, else the ATLASIUM_WOW_DIR environment variable, else
  ATLASIUM_WOW_DIR in the repo's .env file (see .env.example).
  Exit codes: 0 ok, 2 client not running, 3 restart needed, 4 screenshot not found,
  5 reload did not happen, 6 no map marker (debug mode off, add-on not loaded or UI hidden),
  7 the map did not open or close, 8 the map is open, so run or reload refused to type.

.EXAMPLE
  ./tools/wow-dev.ps1 status
  ./tools/wow-dev.ps1 reload -LoadDelay 10
  ./tools/wow-dev.ps1 run -Lua 'print(GetCurrentMapAreaID())'
  ./tools/wow-dev.ps1 mapstate
  ./tools/wow-dev.ps1 mapopen
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('status', 'reload', 'screenshot', 'run', 'mapstate', 'mapopen', 'mapclose')]
  [string]$Mode = 'status',
  [string]$Lua,
  [string]$WowDir = $env:ATLASIUM_WOW_DIR,
  [int]$LoadDelay = 8,
  [int]$ShotTimeout = 10,
  [int]$StateTimeout = 5,       # seconds to wait for the screenshot that reads the map marker
  [switch]$ChatFallback,        # screenshot: type /run Screenshot() when the key does nothing (map must be closed)
  [switch]$SkipMapCheck         # reload: do not read the map marker before typing
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

# Keys that Atlasium/Dev.lua binds in debug mode: Num Pad * (WoW name NUMPADMULTIPLY) toggles the
# world map, Num Pad - (NUMPADMINUS) takes a screenshot. Both are operator keys: they send the same
# virtual key whatever the NumLock state is, and they are not extended keys. Keep the names in sync
# with Dev.BINDINGS. WoW has no F13 to F15 on Windows. Modifier keys cannot be sent with PostMessage,
# because the client reads their state from the real keyboard.
$MapKey = @{ Vk = 0x6A; Scan = 0x37; Extended = $false }
$ShotKey = @{ Vk = 0x6D; Scan = 0x4A; Extended = $false }

# Edge of the map marker in pixels. It must match Dev.MARKER_PIXELS in Atlasium/Dev.lua.
$MarkerPixels = 24

Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WowInput {
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  const uint WM_KEYDOWN = 0x100, WM_KEYUP = 0x101, WM_CHAR = 0x102;

  public static void Key(IntPtr h, int vk, int scan) { Key(h, vk, scan, false); }

  // lParam: repeat count 1, scan code, bit 24 for an extended key; key up also sets bits 30 and 31.
  public static void Key(IntPtr h, int vk, int scan, bool extended) {
    int down = 1 | (scan << 16) | (extended ? (1 << 24) : 0);
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

# Presses a key in the (background) client window. The client has the keyboard whether the chat box
# is closed or the world map is open, so this works where typing does not.
function Send-GameKey($proc, $key) {
  [WowInput]::Key($proc.MainWindowHandle, $key.Vk, $key.Scan, $key.Extended)
}

# The path of a screenshot file written after $since, or $null.
function Wait-Screenshot($since, $timeout) {
  $deadline = $since.AddSeconds($timeout)
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

# Takes a screenshot with the screenshot key, and waits $timeout seconds for the file. Without debug
# mode the key does nothing. With -Chat the function then types /run Screenshot(), which is safe only
# when the world map is closed.
function Take-Screenshot($proc, [int]$timeout = $ShotTimeout, [switch]$chat) {
  $since = Get-Date
  Send-GameKey $proc $ShotKey
  $shot = Wait-Screenshot $since $(if ($chat) { [Math]::Min(3, $timeout) } else { $timeout })
  if (-not $shot -and $chat) {
    $since = Get-Date
    Send-Chat $proc '/run Screenshot()'
    $shot = Wait-Screenshot $since $timeout
  }
  $shot
}

# Classifies the map marker in the top-left corner of a screenshot as 'open' (green), 'closed' (red)
# or 'none'. It checks the centre of the square, from 25% to 75% of its edge, so the edges and the
# JPEG blocks around them do not matter. At least 90% of those pixels must be clearly green or red,
# which a scene does not give by chance. The coordinates are screenshot pixels, so a window of
# another size does not matter. A screenshot scaled below about 75% would miss the square.
function Get-MarkerState($bitmap) {
  if ($bitmap.Width -lt $MarkerPixels -or $bitmap.Height -lt $MarkerPixels) { return 'none' }
  $lo = [int]($MarkerPixels * 0.25)
  $hi = [int]($MarkerPixels * 0.75)
  $green = 0; $red = 0; $total = 0
  for ($y = $lo; $y -lt $hi; $y++) {
    for ($x = $lo; $x -lt $hi; $x++) {
      $c = $bitmap.GetPixel($x, $y)
      $total++
      if ($c.G -ge 170 -and $c.R -le 80 -and $c.B -le 80) { $green++ }
      elseif ($c.R -ge 170 -and $c.G -le 80 -and $c.B -le 80) { $red++ }
    }
  }
  if ($green -ge 0.9 * $total) { return 'open' }
  if ($red -ge 0.9 * $total) { return 'closed' }
  'none'
}

# Reads the file into memory first, so the client can overwrite or delete it at once.
function Read-MapMarker($path) {
  $stream = [IO.MemoryStream]::new([IO.File]::ReadAllBytes($path))
  try {
    $bitmap = [System.Drawing.Bitmap]::new($stream)
    try { Get-MarkerState $bitmap } finally { $bitmap.Dispose() }
  } finally { $stream.Dispose() }
}

# Takes a key screenshot and reads the marker. State is 'open', 'closed', 'none' (a screenshot without
# marker) or 'noshot' (the key made no screenshot, for example when debug mode is off or a chat box
# is open).
function Get-MapState($proc) {
  $shot = Take-Screenshot $proc $StateTimeout
  if (-not $shot) { return [pscustomobject]@{ State = 'noshot'; Shot = $null } }
  [pscustomobject]@{ State = Read-MapMarker $shot; Shot = $shot }
}

function Write-NoMarker($state) {
  if ($state.State -eq 'noshot') {
    Write-Output "NO_MARKER: the screenshot key made no screenshot. Turn on /atlasium debug, and close any chat box or menu."
  } else {
    Write-Output "NO_MARKER: no map marker in $($state.Shot). Turn on /atlasium debug and show the UI."
  }
}

# For run and reload. Exits with 8 when the world map is open, because the map has the keyboard and
# would swallow the text. With no marker the state is unknown: say so and go on. It returns nothing,
# because Write-Output in a function adds to its return value.
function Assert-CanType($state) {
  if ($state.State -eq 'open') {
    Write-Output "MAP_OPEN: not typing, the world map is open and swallows text. Run mapclose first. $($state.Shot)"
    exit 8
  }
  if ($state.State -ne 'closed') {
    Write-Output "NO_MARKER: cannot tell whether the world map is open (needs /atlasium debug). Typing anyway."
  }
}

# mapopen and mapclose: press the toggle key only when the state is not the wanted one, then read
# the state again. Never sends Escape: with the map closed it opens the game menu.
function Set-MapState($proc, $want) {
  $label = if ($want -eq 'open') { 'MAP_OPEN' } else { 'MAP_CLOSED' }
  $before = Get-MapState $proc
  if ($before.State -notin 'open', 'closed') { Write-NoMarker $before; exit 6 }
  if ($before.State -eq $want) { Write-Output "${label}: $($before.Shot) (already)"; return }
  Send-GameKey $proc $MapKey
  Start-Sleep -Milliseconds 600                      # the map and the marker draw on the next frame
  $after = Get-MapState $proc
  if ($after.State -eq $want) { Write-Output "${label}: $($after.Shot)"; return }
  Write-Output "MAP_UNCHANGED: wanted $want, the marker shows $($after.State). $($after.Shot)"
  exit 7
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
    if (-not $SkipMapCheck) {
      Assert-CanType (Get-MapState $proc)
    }
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
    # The map is closed after a reload, so the chat fallback is safe.
    $shot = Take-Screenshot $proc -chat
    if (-not $shot) { Write-Output "NO_SCREENSHOT: nothing new in $ShotDir"; exit 4 }
    Write-Output "SCREENSHOT: $shot"
  }
  'run' {
    if (-not $Lua) { throw 'run needs -Lua <code>.' }
    $text = "/run $Lua"
    if ($text.Length -gt 255) { throw "The chat box takes 255 characters; got $($text.Length)." }
    $mapState = Get-MapState $proc
    Assert-CanType $mapState
    Send-Chat $proc $text
    Start-Sleep -Milliseconds 800
    # With a known closed map the key works, so chat is needed only when the state is unknown.
    $shot = Take-Screenshot $proc -chat:($mapState.State -ne 'closed')
    if (-not $shot) { Write-Output "NO_SCREENSHOT: nothing new in $ShotDir"; exit 4 }
    Write-Output "SCREENSHOT: $shot"
  }
  'screenshot' {
    $shot = Take-Screenshot $proc -chat:$ChatFallback
    if (-not $shot) {
      Write-Output "NO_SCREENSHOT: nothing new in $ShotDir. The key needs /atlasium debug; with the map closed, -ChatFallback types the command instead."
      exit 4
    }
    Write-Output "SCREENSHOT: $shot"
  }
  'mapstate' {
    $state = Get-MapState $proc
    switch ($state.State) {
      'open' { Write-Output "MAP_OPEN: $($state.Shot)" }
      'closed' { Write-Output "MAP_CLOSED: $($state.Shot)" }
      default { Write-NoMarker $state; exit 6 }
    }
  }
  'mapopen' { Set-MapState $proc 'open' }
  'mapclose' { Set-MapState $proc 'closed' }
}
