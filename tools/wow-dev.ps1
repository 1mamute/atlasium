<#
.SYNOPSIS
  Drives a running WoW 3.3.5a client for in-game checks of Atlasium.

.DESCRIPTION
  status      Reports whether the client is running and whether the add-on changed in a way
              that /reload cannot pick up (a restart is needed).
  eval        Runs Lua (from -Lua or -File) in the dev console and prints the result as text:
              the chat lines that the code printed, then "=> " and the returned values. With
              -Until it runs the code again until the first returned value is not nil or false.
  log         Prints the newest entries of AtlasiumDB.log (-Tail, default 20) through eval.
  reload      Types /reload and waits for the UI to load. With the dev console strip it waits for
              a new load ID and prints a health report. Without it, it waits -LoadDelay seconds,
              takes a WoW screenshot and prints its path.
  screenshot  Takes a WoW screenshot without reloading and prints its path.
  run         Types /run <Lua> (from -Lua), waits a moment, takes a WoW screenshot and prints
              its path. The chat box takes at most 255 characters.
  mapstate    Reads the map marker in the top-left corner and prints MAP_OPEN, MAP_CLOSED or
              NO_MARKER.
  mapopen     Opens the world map when it is closed and checks the result.
  mapclose    Closes the world map when it is open and checks the result.

  Keys and text go to the client with window messages, so the client stays in the background
  and you can keep using the computer.

  Debug mode (/atlasium debug) adds the parts that the script reads and presses:
  - A green (map open) or red (map closed) square in the top-left corner of the screen.
  - The dev console strip right of the square: coloured cells that hold the last eval result.
  - Key bindings: Num Pad * opens and closes the map, Num Pad - takes a screenshot, Num Pad +
    gives the dev console the keyboard.
  The script reads the square and the strip from a capture of the client window (PrintWindow).
  The window must not be minimized. When the capture shows no square, the map modes take a WoW
  screenshot and read the square from it. Without debug mode there is no square, no strip and no
  key binding: the map modes report NO_MARKER, eval reports NO_STRIP and screenshots need
  -ChatFallback.

  An open world map has the keyboard and ignores typed chat text, so run and reload check the
  square first and do not type while the map is open. Use -SkipMapCheck to skip that check in
  reload. eval works with the map open: the add-on gives the console the keyboard itself.

  eval sends the code as hex digits, so its length has no limit. Output longer than 4096 bytes is
  cut. Each eval shows a grey "dev>" line in the game chat.

  The WoW folder comes from -WowDir, else the ATLASIUM_WOW_DIR environment variable, else
  ATLASIUM_WOW_DIR in the repo's .env file (see .env.example).
  Exit codes: 0 ok, 2 client not running, 3 restart needed, 4 screenshot not found,
  5 reload did not happen, 6 no map marker or no strip (debug mode off, add-on not loaded, UI
  hidden or window minimized), 7 the map did not open or close, 8 the map is open, so run or
  reload refused to type, 9 the Lua code failed, 10 another edit box has the keyboard (for
  example the chat box), so eval did not type, 11 the dev console did not take the keyboard,
  12 no eval result in time, 13 the strip did not pass the checksum, 14 -Until timed out.

.EXAMPLE
  ./tools/wow-dev.ps1 status
  ./tools/wow-dev.ps1 eval -Lua 'return AtlasiumDev.Dev.GetHealth()'
  ./tools/wow-dev.ps1 eval -Lua 'return WorldMapFrame:IsShown()' -Until -Timeout 5
  ./tools/wow-dev.ps1 eval -File probe.lua
  ./tools/wow-dev.ps1 log -Tail 50
  ./tools/wow-dev.ps1 reload
  ./tools/wow-dev.ps1 run -Lua 'print(GetCurrentMapAreaID())'
  ./tools/wow-dev.ps1 mapstate
  ./tools/wow-dev.ps1 mapopen
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('status', 'eval', 'log', 'reload', 'screenshot', 'run', 'mapstate', 'mapopen', 'mapclose')]
  [string]$Mode = 'status',
  [string]$Lua,
  [string]$File,                # eval: read the Lua code from this file (UTF-8)
  [switch]$Until,               # eval: repeat until the first returned value is not nil or false
  [double]$Timeout = 10,        # eval: seconds to wait for the result (with -Until: for all tries)
  [double]$Interval = 0.25,     # eval -Until: seconds between tries
  [int]$Tail = 20,              # log: number of entries
  [string]$WowDir = $env:ATLASIUM_WOW_DIR,
  [int]$LoadDelay = 8,          # reload without the strip: seconds to wait for the UI
  [int]$LoadTimeout = 60,       # reload with the strip: seconds to wait for a new load ID
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
# world map, Num Pad - (NUMPADMINUS) takes a screenshot, Num Pad + (NUMPADPLUS) gives the dev console
# the keyboard. All are operator keys: they send the same virtual key whatever the NumLock state is,
# and they are not extended keys. Keep the names in sync with Dev.BINDINGS and Dev.CONSOLE_KEY. WoW
# has no F13 to F15 on Windows. Modifier keys cannot be sent with PostMessage, because the client
# reads their state from the real keyboard.
$MapKey = @{ Vk = 0x6A; Scan = 0x37; Extended = $false }
$ShotKey = @{ Vk = 0x6D; Scan = 0x4A; Extended = $false }
$ConsoleKey = @{ Vk = 0x6B; Scan = 0x4E; Extended = $false }

# Edge of the map marker in pixels. It must match Dev.MARKER_PIXELS in Atlasium/Dev.lua.
$MarkerPixels = 24

# The dev console strip, in UI units of a frame without parent (1 unit is client height / 768
# pixels). Keep in sync with Atlasium/DevConsole.lua.
$Strip = @{
  Left = 24; Cell = 4; Columns = 64; HeaderCells = 5; MaxBytes = 4096
  Magic = 0x41, 0x74, 0x6C
  FlagFocus = 1; FlagOtherFocus = 2; FlagError = 4; FlagTruncated = 8
}
# The window area that the capture keeps, in UI units: the strip at its largest, with the marker.
$CaptureUnitsWide = $Strip.Left + $Strip.Columns * $Strip.Cell
$CaptureUnitsHigh = [Math]::Ceiling(($Strip.HeaderCells + [Math]::Ceiling($Strip.MaxBytes / 3)) / $Strip.Columns) * $Strip.Cell

Add-Type -AssemblyName System.Drawing

# P/Invoke only: in PowerShell 7, C# in Add-Type cannot use the System.Drawing types (CS1069).
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
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

  // A pause after every 256 characters keeps a long text under the limit of the message queue.
  public static void Chars(IntPtr h, string text) {
    for (int i = 0; i < text.Length; i++) {
      PostMessage(h, WM_CHAR, (IntPtr)text[i], (IntPtr)1);
      if (i % 256 == 255) Thread.Sleep(15);
    }
  }
}

public class WowImage {
  public int Width, Height, ClientHeight;
  public int[] Pixels; // 0x00RRGGBB, rows from the top
}

public static class WowCapture {
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] struct BITMAPINFOHEADER {
    public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount;
    public uint biCompression, biSizeImage; public int biXPelsPerMeter, biYPelsPerMeter;
    public uint biClrUsed, biClrImportant;
  }
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
  [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
  [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
  [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
  [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint rop);
  [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr dc, IntPtr bmp, uint start, uint lines,
    [Out] int[] bits, ref BITMAPINFOHEADER info, uint usage);
  const uint PW_CLIENTONLY_RENDERFULLCONTENT = 3, SRCCOPY = 0x00CC0020;

  public static int ClientHeight(IntPtr h) {
    RECT r;
    return GetClientRect(h, out r) ? r.Bottom - r.Top : 0;
  }

  // The top-left maxW x maxH pixels of the client area, or null (no window, minimized, failed).
  // PrintWindow works while other windows cover the client.
  public static WowImage Capture(IntPtr h, int maxW, int maxH) {
    RECT r;
    if (!GetClientRect(h, out r)) return null;
    int cw = r.Right - r.Left, ch = r.Bottom - r.Top;
    int w = Math.Min(cw, maxW), ht = Math.Min(ch, maxH);
    if (w <= 0 || ht <= 0) return null;
    IntPtr wdc = GetDC(h);
    IntPtr fullDc = CreateCompatibleDC(wdc), partDc = CreateCompatibleDC(wdc);
    IntPtr fullBmp = CreateCompatibleBitmap(wdc, cw, ch), partBmp = CreateCompatibleBitmap(wdc, w, ht);
    IntPtr oldFull = SelectObject(fullDc, fullBmp), oldPart = SelectObject(partDc, partBmp);
    try {
      if (!PrintWindow(h, fullDc, PW_CLIENTONLY_RENDERFULLCONTENT)) return null;
      BitBlt(partDc, 0, 0, w, ht, fullDc, 0, 0, SRCCOPY);
      SelectObject(partDc, oldPart); // GetDIBits needs the bitmap out of the DC
      oldPart = IntPtr.Zero;
      var info = new BITMAPINFOHEADER();
      info.biSize = 40; info.biWidth = w; info.biHeight = -ht; // negative: rows from the top
      info.biPlanes = 1; info.biBitCount = 32;
      var image = new WowImage { Width = w, Height = ht, ClientHeight = ch, Pixels = new int[w * ht] };
      if (GetDIBits(partDc, partBmp, 0, (uint)ht, image.Pixels, ref info, 0) == 0) return null;
      return image;
    } finally {
      SelectObject(fullDc, oldFull);
      if (oldPart != IntPtr.Zero) SelectObject(partDc, oldPart);
      DeleteObject(fullBmp); DeleteObject(partBmp);
      DeleteDC(fullDc); DeleteDC(partDc);
      ReleaseDC(h, wdc);
    }
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

# The top-left corner of the client window (marker and strip) as a WowImage, or $null. It takes 20 to
# 60 ms and needs no screenshot file.
function Get-WindowImage($proc) {
  $h = $proc.MainWindowHandle
  $scale = [WowCapture]::ClientHeight($h) / 768
  if ($scale -le 0) { return $null }
  $w = [int][Math]::Ceiling($CaptureUnitsWide * $scale) + 2
  $ht = [int][Math]::Ceiling([Math]::Max($CaptureUnitsHigh, $MarkerPixels) * $scale) + 2
  [WowCapture]::Capture($h, $w, $ht)
}

# A screenshot file as a WowImage. It reads the file into memory first, so the client can overwrite
# or delete it at once.
function Read-ImageFile($path) {
  $stream = [IO.MemoryStream]::new([IO.File]::ReadAllBytes($path))
  try {
    $bitmap = [System.Drawing.Bitmap]::new($stream)
    try {
      $rect = [System.Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height)
      $data = $bitmap.LockBits($rect, 'ReadOnly', 'Format32bppArgb')
      $image = [WowImage]@{ Width = $bitmap.Width; Height = $bitmap.Height; ClientHeight = $bitmap.Height }
      $image.Pixels = [int[]]::new($bitmap.Width * $bitmap.Height)
      # 32-bit rows need no padding, so the stride is the width times 4.
      [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $image.Pixels, 0, $image.Pixels.Length)
      $bitmap.UnlockBits($data)
      $image
    } finally { $bitmap.Dispose() }
  } finally { $stream.Dispose() }
}

# Classifies the map marker in the top-left corner of an image as 'open' (green), 'closed' (red) or
# 'none'. It checks the centre of the square, from 25% to 75% of its edge, so the edges and the JPEG
# blocks around them do not matter. At least 90% of those pixels must be clearly green or red, which
# a scene does not give by chance. The coordinates are client pixels, so a window of another size
# does not matter. A screenshot scaled below about 75% would miss the square.
function Get-MarkerState($image) {
  if (-not $image -or $image.Width -lt $MarkerPixels -or $image.Height -lt $MarkerPixels) { return 'none' }
  $lo = [int]($MarkerPixels * 0.25)
  $hi = [int]($MarkerPixels * 0.75)
  $green = 0; $red = 0; $total = 0
  for ($y = $lo; $y -lt $hi; $y++) {
    for ($x = $lo; $x -lt $hi; $x++) {
      $v = $image.Pixels[$y * $image.Width + $x]
      $r = ($v -shr 16) -band 0xFF; $g = ($v -shr 8) -band 0xFF; $b = $v -band 0xFF
      $total++
      if ($g -ge 170 -and $r -le 80 -and $b -le 80) { $green++ }
      elseif ($r -ge 170 -and $g -le 80 -and $b -le 80) { $red++ }
    }
  }
  if ($green -ge 0.9 * $total) { return 'open' }
  if ($red -ge 0.9 * $total) { return 'closed' }
  'none'
}

# The 3 bytes of strip cell $i (0-based), read at the centre of the cell, or $null when the cell is
# outside the image. Edge pixels are blended, so only the centre is exact.
function Get-StripCell($image, [int]$i) {
  $scale = $image.ClientHeight / 768
  $x = [int][Math]::Floor(($Strip.Left + ($i % $Strip.Columns) * $Strip.Cell + $Strip.Cell / 2) * $scale)
  $y = [int][Math]::Floor(([Math]::Floor($i / $Strip.Columns) * $Strip.Cell + $Strip.Cell / 2) * $scale)
  if ($x -ge $image.Width -or $y -ge $image.Height) { return $null }
  $v = $image.Pixels[$y * $image.Width + $x]
  , @((($v -shr 16) -band 0xFF), (($v -shr 8) -band 0xFF), ($v -band 0xFF))
}

function ConvertFrom-Cell24($cell) { ($cell[0] -shl 16) + ($cell[1] -shl 8) + $cell[2] }

# Decodes the strip header (see Atlasium/DevConsole.lua), or returns $null without the magic cell.
# With -WithData it also reads the data cells: Text is the UTF-8 text and Valid tells whether the
# checksum matches.
function Read-Strip($image, [switch]$WithData) {
  if (-not $image) { return $null }
  $magic = Get-StripCell $image 0
  if (-not $magic -or $magic[0] -ne $Strip.Magic[0] -or $magic[1] -ne $Strip.Magic[1] -or
    $magic[2] -ne $Strip.Magic[2]) { return $null }
  $header = @()
  for ($i = 1; $i -lt $Strip.HeaderCells; $i++) {
    $cell = Get-StripCell $image $i
    if (-not $cell) { return $null }
    $header += , $cell
  }
  $result = [pscustomobject]@{
    LoadId = ConvertFrom-Cell24 $header[0]
    Seq = $header[1][0] * 256 + $header[1][1]
    Flags = $header[1][2]
    Length = ConvertFrom-Cell24 $header[2]
    Checksum = ConvertFrom-Cell24 $header[3]
    Text = $null
    Valid = $false
  }
  if ($result.Length -gt $Strip.MaxBytes) { return $result }   # a misread: Valid stays false
  if ($WithData) {
    $bytes = [byte[]]::new($result.Length)
    $sum = 0
    $cell = $null
    for ($k = 0; $k -lt $bytes.Length; $k++) {
      if ($k % 3 -eq 0) {
        $cell = Get-StripCell $image ($Strip.HeaderCells + [Math]::Floor($k / 3))
        if (-not $cell) { return $result }
      }
      $bytes[$k] = $cell[$k % 3]
      $sum = ($sum + $bytes[$k] * (($k % 251) + 1)) % 16777216
    }
    $result.Text = [Text.Encoding]::UTF8.GetString($bytes)
    $result.Valid = $sum -eq $result.Checksum
  }
  $result
}

# Captures the window every 50 ms until $test (given the strip header) is true, then returns that
# image. Returns $null after $timeout seconds.
function Wait-Strip($proc, [double]$timeout, [scriptblock]$test) {
  $deadline = (Get-Date).AddSeconds($timeout)
  do {
    $image = Get-WindowImage $proc
    $header = Read-Strip $image
    if ($header -and (& $test $header)) { return $image }
    Start-Sleep -Milliseconds 50
  } while ((Get-Date) -lt $deadline)
  $null
}

function New-EvalResult([int]$code, [string]$text, [bool]$truncated = $false) {
  [pscustomobject]@{ Code = $code; Text = $text; Truncated = $truncated }
}

# Runs $code in the dev console and returns the result (Code is the exit code):
# 1. Read the strip. No strip: exit 6. Another edit box has the keyboard: exit 10, type nothing.
# 2. Press the console key, then wait for the console focus flag (2 s), else exit 11.
# 3. Type the code as hex digits (so | and non-ASCII text survive the edit box) and press Enter.
# 4. Wait for a new sequence number ($timeout), then read the data and check the checksum.
function Invoke-Eval($proc, [string]$code, [double]$timeout) {
  $before = Read-Strip (Get-WindowImage $proc)
  if (-not $before) {
    return New-EvalResult 6 'NO_STRIP: no dev console strip in the window. Turn on /atlasium debug, show the UI and do not minimize the client.'
  }
  if ($before.Flags -band $Strip.FlagOtherFocus) {
    return New-EvalResult 10 'BUSY: another edit box has the keyboard (for example the chat box). Not typing.'
  }
  if ($before.Flags -band $Strip.FlagFocus) {
    # A run that broke off left the console open, maybe with text in it. It closes after 3 s.
    $closed = Wait-Strip $proc 4 { param($s) -not ($s.Flags -band $Strip.FlagFocus) }
    if (-not $closed) { return New-EvalResult 11 'NO_FOCUS: the dev console kept the keyboard from an earlier run.' }
    $before = Read-Strip $closed
  }
  $h = $proc.MainWindowHandle
  Send-GameKey $proc $ConsoleKey
  $focused = Wait-Strip $proc 2 { param($s) $s.Flags -band ($Strip.FlagFocus -bor $Strip.FlagOtherFocus) }
  if (-not $focused) {
    return New-EvalResult 11 'NO_FOCUS: the console key did not give the dev console the keyboard (combat delays new bindings; run /atlasium debug again after combat).'
  }
  if (-not ((Read-Strip $focused).Flags -band $Strip.FlagFocus)) {
    return New-EvalResult 10 'BUSY: another edit box took the keyboard. Not typing.'
  }
  $hex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($code)) -replace '-', ''
  [WowInput]::Chars($h, $hex)
  [WowInput]::Key($h, 0x0D, 0x1C)                    # VK_RETURN
  $done = Wait-Strip $proc $timeout { param($s) $s.LoadId -ne $before.LoadId -or $s.Seq -ne $before.Seq }
  if (-not $done) { return New-EvalResult 12 "NO_RESULT: no eval result in $timeout s." }
  $reply = Read-Strip $done -WithData
  if ($reply.LoadId -ne $before.LoadId) { return New-EvalResult 12 'NO_RESULT: the UI reloaded during the eval.' }
  if (-not $reply.Valid) {
    $reply = Read-Strip (Get-WindowImage $proc) -WithData
    if (-not $reply -or -not $reply.Valid) {
      return New-EvalResult 13 'BAD_CHECKSUM: the strip did not decode. Check that the client draws the strip colours exactly (no gamma, no colour filter).'
    }
  }
  $truncated = [bool]($reply.Flags -band $Strip.FlagTruncated)
  if ($reply.Flags -band $Strip.FlagError) { return New-EvalResult 9 $reply.Text $truncated }
  New-EvalResult 0 $reply.Text $truncated
}

function Write-EvalResult($result) {
  if ($result.Code -notin 0, 9) { Write-Output $result.Text; return }
  if ($result.Code -eq 9) { Write-Output 'EVAL_ERROR:' }
  if ($result.Text) { Write-Output $result.Text } else { Write-Output '(no output)' }
  if ($result.Truncated) { Write-Output "(truncated at $($Strip.MaxBytes) bytes)" }
}

# For -Until: the last line is "=> " with a first value that is not nil or false.
function Test-Truthy($result) {
  if ($result.Code -ne 0 -or -not $result.Text) { return $false }
  $last = ($result.Text -split "`n")[-1]
  $last.StartsWith('=> ') -and $last -notmatch '^=> (nil|false)(,|$)'
}

# The value of a string that Lua's %q wrote ("=> " and a quoted string), or $null for other text.
function ConvertFrom-LuaQuoted([string]$text) {
  if ($text -notmatch '(?s)^=> "(.*)"$') { return $null }
  [regex]::Replace($Matches[1], '\\(\n|\\|"|r|\d{3})', {
      param($m)
      switch ($m.Groups[1].Value) {
        "`n" { "`n" }
        'r' { "`r" }
        default { if ($_ -match '^\d') { [string][char][int]$_ } else { $_ } }
      }
    })
}

# The Lua code of eval: -File or -Lua.
function Get-EvalCode {
  if ($File) { return [IO.File]::ReadAllText((Resolve-Path $File), [Text.Encoding]::UTF8) }
  if (-not $Lua) { throw 'eval needs -Lua <code> or -File <path>.' }
  $Lua
}

# Reads the map marker: from a window capture, else from a key screenshot. State is 'open', 'closed',
# 'none' (a screenshot without marker) or 'noshot' (the key made no screenshot, for example when
# debug mode is off or a chat box is open). Shot is the screenshot path, or $null for a capture.
function Get-MapState($proc) {
  $state = Get-MarkerState (Get-WindowImage $proc)
  if ($state -ne 'none') { return [pscustomobject]@{ State = $state; Shot = $null } }
  $shot = Take-Screenshot $proc $StateTimeout
  if (-not $shot) { return [pscustomobject]@{ State = 'noshot'; Shot = $null } }
  [pscustomobject]@{ State = Get-MarkerState (Read-ImageFile $shot); Shot = $shot }
}

function Get-Source($state) {
  if ($state.Shot) { $state.Shot } else { '(window capture)' }
}

function Write-NoMarker($state) {
  if ($state.State -eq 'noshot') {
    Write-Output "NO_MARKER: no marker in the window capture, and the screenshot key made no screenshot. Turn on /atlasium debug, and close any chat box or menu."
  } else {
    Write-Output "NO_MARKER: no map marker in $($state.Shot). Turn on /atlasium debug and show the UI."
  }
}

# For run and reload. Exits with 8 when the world map is open, because the map has the keyboard and
# would swallow the text. With no marker the state is unknown: say so and go on. It returns nothing,
# because Write-Output in a function adds to its return value.
function Assert-CanType($state) {
  if ($state.State -eq 'open') {
    Write-Output "MAP_OPEN: not typing, the world map is open and swallows text. Run mapclose first. $(Get-Source $state)"
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
  if ($before.State -eq $want) { Write-Output "${label}: $(Get-Source $before) (already)"; return }
  Send-GameKey $proc $MapKey
  # The map and the marker draw on the next frame. Read captures for 2 s, then fall back to Get-MapState.
  $deadline = (Get-Date).AddSeconds(2)
  do {
    Start-Sleep -Milliseconds 100
    if ((Get-MarkerState (Get-WindowImage $proc)) -eq $want) { Write-Output "${label}: (window capture)"; return }
  } while ((Get-Date) -lt $deadline)
  $after = Get-MapState $proc
  if ($after.State -eq $want) { Write-Output "${label}: $(Get-Source $after)"; return }
  Write-Output "MAP_UNCHANGED: wanted $want, the marker shows $($after.State). $(Get-Source $after)"
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
  'eval' {
    $code = Get-EvalCode
    if (-not $Until) {
      $result = Invoke-Eval $proc $code $Timeout
      Write-EvalResult $result
      exit $result.Code
    }
    # Errors count as "not yet": the state that the code reads may not exist yet.
    $deadline = (Get-Date).AddSeconds($Timeout)
    $tries = 0
    do {
      $tries++
      $result = Invoke-Eval $proc $code ([Math]::Max(1, ($deadline - (Get-Date)).TotalSeconds))
      if ($result.Code -notin 0, 9) { Write-EvalResult $result; exit $result.Code }
      if (Test-Truthy $result) {
        Write-EvalResult $result
        Write-Output "UNTIL_MET: after $tries tries"
        exit 0
      }
      Start-Sleep -Milliseconds ([int]($Interval * 1000))
    } while ((Get-Date) -lt $deadline)
    Write-EvalResult $result
    Write-Output "UNTIL_TIMEOUT: not met after $tries tries in $Timeout s"
    exit 14
  }
  'log' {
    $code = "local l = AtlasiumDev.db.log local t = {} for i = math.max(1, #l - $($Tail - 1)), #l do t[#t + 1] = l[i] end return table.concat(t, '\n')"
    $result = Invoke-Eval $proc $code $Timeout
    if ($result.Code -ne 0) { Write-EvalResult $result; exit $result.Code }
    $text = ConvertFrom-LuaQuoted $result.Text
    if ($null -eq $text) { Write-EvalResult $result }
    elseif ($text) { Write-Output $text }
    else { Write-Output '(the log is empty)' }
  }
  'reload' {
    if (-not $SkipMapCheck) {
      Assert-CanType (Get-MapState $proc)
    }
    $before = Read-Strip (Get-WindowImage $proc)
    $since = Get-Date
    Send-Chat $proc '/reload'
    if ($before) {
      # A new load ID shows that the add-on loaded again. Faster and surer than a fixed wait.
      $after = Wait-Strip $proc $LoadTimeout { param($s) $s.LoadId -ne $before.LoadId }
      if (-not $after) {
        if (-not (Get-WowProcess)) { Write-Output 'NOT_RUNNING: client exited during reload.'; exit 2 }
        Write-Output "NO_RELOAD: the load ID did not change in $LoadTimeout s."
        exit 5
      }
      Write-Output "RELOADED: load ID $((Read-Strip $after).LoadId)"
      $result = Invoke-Eval $proc 'return AtlasiumDev.Dev.GetHealth()' $Timeout
      Write-EvalResult $result
      exit $result.Code
    }
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
      'open' { Write-Output "MAP_OPEN: $(Get-Source $state)" }
      'closed' { Write-Output "MAP_CLOSED: $(Get-Source $state)" }
      default { Write-NoMarker $state; exit 6 }
    }
  }
  'mapopen' { Set-MapState $proc 'open' }
  'mapclose' { Set-MapState $proc 'closed' }
}
