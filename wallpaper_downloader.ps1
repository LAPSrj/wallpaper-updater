# Author: https://github.com/LAPSrj
# Project: https://github.com/LAPSrj/wallpaper-updater

param(
  [string]$Location = "ca",   # e.g., ca, us, br, fr, en-GB, fr-CA, ...
  [switch]$Force             # bypass today's success stamp for testing
)

Add-Type -AssemblyName System.Net.Http

# ---- Console vs compiled detection (silent only when compiled) ----
$procName   = ([Diagnostics.Process]::GetCurrentProcess().ProcessName).ToLowerInvariant()
$IsCompiled = $procName -notin @('powershell','pwsh','powershell_ise')
$IsConsole  = -not $IsCompiled

if (-not $IsConsole) {
  # Mute informational streams & swallow host UI when compiled/no-console
  $ErrorActionPreference = 'SilentlyContinue'
  $WarningPreference     = 'SilentlyContinue'
  $InformationPreference = 'SilentlyContinue'
  $VerbosePreference     = 'SilentlyContinue'
  $ProgressPreference    = 'SilentlyContinue'
  try {
    [Console]::SetOut([System.IO.TextWriter]::Null)
    [Console]::SetError([System.IO.TextWriter]::Null)
  } catch {}

  function global:Write-Host { param([Parameter(ValueFromRemainingArguments=$true)][object[]]$Object,[ConsoleColor]$ForegroundColor,[ConsoleColor]$BackgroundColor,[switch]$NoNewline) }
  function global:Out-Host   { param([Parameter(ValueFromPipeline=$true,ValueFromRemainingArguments=$true)][object[]]$InputObject,[switch]$Paging) process {} }
  function global:Out-Default{ param([Parameter(ValueFromPipeline=$true,ValueFromRemainingArguments=$true)]$InputObject) process {} }
  function global:Read-Host  { param([string]$Prompt) '' }
}

# ---- Base directory: CURRENT USER folder\TodayWallpaper ----
# (replaces previous "same folder as script/exe")
$UserHome = $HOME
if ([string]::IsNullOrWhiteSpace($UserHome)) { $UserHome = $env:USERPROFILE }
if ([string]::IsNullOrWhiteSpace($UserHome)) { $UserHome = [Environment]::GetFolderPath('UserProfile') }
$BaseDir = Join-Path -Path $UserHome -ChildPath 'TodayWallpapers'

# ---- Market helpers ----
function Resolve-Market([string]$Loc) {
  if (-not $Loc) { return 'en-CA' }
  switch ($Loc.ToLower()) {
    'us'   { return 'en-US' }
    'uk'   { return 'en-GB' }
    'gb'   { return 'en-GB' }
    'ca'   { return 'en-CA' }
    'ca-fr'{ return 'fr-CA' }
    'fr-ca'{ return 'fr-CA' }
    'br'   { return 'pt-BR' }
    'pt-br'{ return 'pt-BR' }
    'fr'   { return 'fr-FR' }
    'de'   { return 'de-DE' }
    'it'   { return 'it-IT' }
    'es'   { return 'es-ES' }
    'mx'   { return 'es-MX' }
    'au'   { return 'en-AU' }
    'jp'   { return 'ja-JP' }
    'ja-jp'{ return 'ja-JP' }
    'cn'   { return 'zh-CN' }
    'zh-cn'{ return 'zh-CN' }
    default { return $Loc } # allow full mkt like en-GB
  }
}

function Get-BingImageMeta([string]$Market) {
  $ua  = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
  $url = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$Market&uhd=1&uhdwidth=7680&uhdheight=4320"
  $resp = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $ua } -ErrorAction Stop
  if (-not $resp.images -or $resp.images.Count -eq 0) { throw "No images returned for market $Market" }
  return $resp.images[0]
}

function Get-BestCandidateUrls($img) {
  $base = 'https://www.bing.com'
  $urls = New-Object System.Collections.Generic.List[string]
  if ($img.url)     { $urls.Add("$base$($img.url)") }   # often 1920x1080 fallback
  if ($img.urlbase) {
    $urls.Add("$base$($img.urlbase)_UHD.jpg")
    foreach ($s in '7680x4320','5120x2880','3840x2400','3840x2160','2560x1440','1920x1200','1920x1080') {
      $urls.Add("$base$($img.urlbase)_$s.jpg")
    }
  }
  # De-dup and strip mobile suffix
  $seen = @{}
  $ordered = foreach ($u in $urls) { if (-not $seen.ContainsKey($u)) { $seen[$u] = $true; $u } }
  $ordered | ForEach-Object { $_ -replace '_mb','' }
}

function Get-BingFileNameFromUrl([uri]$Uri) {
  # filename is usually in query: id=OHR.Name_EN-US123_UHD.jpg
  $qsPair = $Uri.Query.TrimStart('?') -split '&' | Where-Object { $_ -like 'id=*' } | Select-Object -First 1
  if ($qsPair) {
    $name = $qsPair.Substring(3)
    try   { $name = [System.Web.HttpUtility]::UrlDecode($name) } catch { try { $name = [System.Net.WebUtility]::UrlDecode($name) } catch {} }
  } else {
    $name = Split-Path -Leaf $Uri.AbsolutePath
  }
  if (-not [System.IO.Path]::GetExtension($name)) { $name += '.jpg' }
  foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace($ch,'_') }
  $name
}

# ---- HTTP client with redirects, TLS 1.2+, and JPEG-only negotiation ----
$script:HttpClient = $null
function Get-HttpClient {
  if ($script:HttpClient) { return $script:HttpClient }
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  $handler = [System.Net.Http.HttpClientHandler]::new()
  $handler.AllowAutoRedirect = $true
  $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
  $client = [System.Net.Http.HttpClient]::new($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $client.DefaultRequestHeaders.UserAgent.ParseAdd('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36')
  $client.DefaultRequestHeaders.Referrer = [Uri]'https://www.bing.com/'
  # --- CHANGED: only request JPEG so Windows can use it as wallpaper ---
  $client.DefaultRequestHeaders.Accept.Clear()
  $client.DefaultRequestHeaders.Accept.ParseAdd('image/jpeg')
  $script:HttpClient = $client
  $client
}

function Try-DownloadFirst([string[]]$Urls, [string]$Folder) {
  $client = Get-HttpClient
  foreach ($u in $Urls) {
    try {
      $req  = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $u)
      $resp = $client.SendAsync($req).Result
      if (-not $resp.IsSuccessStatusCode) { continue }

      $ctype = $resp.Content.Headers.ContentType
      $mt = if ($ctype) { $ctype.MediaType } else { $null }
      # --- CHANGED: accept only JPEG responses ---
      if (-not $mt -or $mt -notmatch '^image/(jpeg|jpg)$') { continue }

      $finalUri = $resp.RequestMessage.RequestUri
      $fileName = Get-BingFileNameFromUrl $finalUri
      # --- CHANGED: make sure the file ends with .jpg ---
      $fileName = [System.IO.Path]::ChangeExtension($fileName, '.jpg')
      $outPath  = Join-Path -Path $Folder -ChildPath $fileName

      $bytes = $resp.Content.ReadAsByteArrayAsync().Result
      if (-not $bytes -or $bytes.Length -lt 8192) { continue }
      [System.IO.File]::WriteAllBytes($outPath, $bytes)
      return @{ Url = $finalUri.AbsoluteUri; Path = $outPath }
    } catch { continue }
  }
  throw "Failed to download from any candidate URL."
}

# ---- Wallpaper helpers ----
function Set-Wallpaper([string]$ImagePath) {
  Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue  # Fill
  Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper   -Value '0'  -ErrorAction SilentlyContinue
  Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@ -ErrorAction SilentlyContinue | Out-Null
  [Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01 -bor 0x02) | Out-Null  # SPI_SETDESKWALLPAPER
  Start-Process -FilePath "RUNDLL32.EXE" -ArgumentList "USER32.DLL,UpdatePerUserSystemParameters" -WindowStyle Hidden
}

function Prune-OldImages([string]$Folder, [int]$Keep = 10) {
  try {
    $files = Get-ChildItem -LiteralPath $Folder -Filter *.jpg -File -ErrorAction Stop |
             Where-Object { $_.Name -ne 'Today.jpg' -and $_.Name -notlike 'last_success_*' } |
             Sort-Object LastWriteTime -Descending
    if ($files.Count -gt $Keep) {
      $toRemove = $files | Select-Object -Skip $Keep
      foreach ($f in $toRemove) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
  } catch {}
}

# ---- Main ----
function Invoke-Main {
  $mkt = Resolve-Market -Loc $Location

  # Everything lives under current user's TodayWallpaper
  $Folder   = $BaseDir
  $TodayJpg = Join-Path -Path $Folder -ChildPath 'Today.jpg'
  if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }

  # Per-market daily success stamp (Hidden) in same folder
  $Stamp    = Join-Path -Path $Folder -ChildPath ("last_success_{0}.txt" -f $mkt.Replace('-','_'))
  $today    = (Get-Date).ToString('yyyy-MM-dd')

  if (-not $Force) {
    if (Test-Path $Stamp) {
      $done = Get-Content $Stamp -Raw -ErrorAction SilentlyContinue
      if ($done -eq $today) {
        if ($IsConsole) { Write-Host "Skipped: already updated today ($today). Use -Force to override." }
        return
      }
    }
  }

  # Fetch metadata and build best URLs
  $img = Get-BingImageMeta -Market $mkt
  $candidates = Get-BestCandidateUrls -img $img

  # Download to original filename in same folder
  $result = Try-DownloadFirst -Urls $candidates -Folder $Folder
  $downloadedPath = $result.Path

  # Copy to Today.jpg and set wallpaper
  Copy-Item -Path $downloadedPath -Destination $TodayJpg -Force
  Set-Wallpaper -ImagePath $TodayJpg

  # Prune to last 10 (excluding Today.jpg and stamp)
  Prune-OldImages -Folder $Folder -Keep 10

  # Write/mark hidden stamp
  if (-not (Test-Path $Stamp)) { New-Item -ItemType File -Path $Stamp -Force | Out-Null }
  Set-Content -Path $Stamp -Value $today -NoNewline
  try {
    $fi = Get-Item -LiteralPath $Stamp -Force
    $fi.Attributes = $fi.Attributes -bor [System.IO.FileAttributes]::Hidden
  } catch {}

  if ($IsConsole) {
    Write-Host "Downloaded: $($result.Url)"
    Write-Host "Saved as : $downloadedPath"
    Write-Host "Updated  : $TodayJpg"
    Write-Host "Market   : $mkt"
  }
}

if ($IsConsole) { Invoke-Main } else { Invoke-Main | Out-Null; exit 0 }
