# Author: https://github.com/LAPSrj
# Instructions: https://github.com/LAPSrj/wallpaper-updater

param(
    [string]$Location = "ca"
)

# Define valid locations
$validLocations = @("us","uk","jp","de","fr","es","br","in","ca","au","cn","it")

# Fallback to default if invalid
if ($validLocations -notcontains $Location) {
    $Location = "ca"
}

# Build URL dynamically (empty suffix for 'us')
$baseUrl = "https://bing.gifposter.com"
$suffix = if ($Location -eq "us") { "" } else { "/$Location" }
$Url = "$baseUrl$suffix"

# Define variables
$DownloadFolder = "$env:USERPROFILE\TodayWallpapers"
$FixedFile = Join-Path $DownloadFolder "Today.jpg"

# Ensure the folder exists
if (!(Test-Path $DownloadFolder)) {
    New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
}

# Get raw HTML content
try {
    $html = Invoke-WebRequest -Uri $Url -UseBasicParsing
    $content = $html.Content
} catch {
    Write-Host "Failed to fetch the webpage."
    exit 1
}

# Extract first image URL in .dayimg section
if ($content -match '(?s)<section[^>]*class="dayimg".*?<img[^>]+src="([^"]+)"') {
    $imageUrl = $matches[1]
} else {
    Write-Host "No matching image found."
    exit 1
}

# Convert to absolute URL if relative
if ($imageUrl -notmatch '^https?://') {
    $imageUrl = (New-Object System.Uri((New-Object System.Uri($Url)), $imageUrl)).AbsoluteUri
}

# Remove '_mb' before downloading
$cleanImageUrl = $imageUrl -replace "_mb", ""

# Build file name and path (real filename from source)
$fileName = [System.IO.Path]::GetFileName($cleanImageUrl)
$realFilePath = Join-Path $DownloadFolder $fileName

# Download image
Invoke-WebRequest -Uri $cleanImageUrl -OutFile $realFilePath

# Copy image to fixed filename (used by wallpaper)
Copy-Item -Path $realFilePath -Destination $FixedFile -Force

# Keep only last 10 files (excluding BingToday.jpg)
Get-ChildItem -Path $DownloadFolder -File |
    Where-Object { $_.Name -ne "BingToday.jpg" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 10 |
    Remove-Item

# Add Wallpaper type only once
if (-not ("Wallpaper" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
}

$SPI_SETDESKWALLPAPER = 0x0014
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDWININICHANGE = 0x02

# Update wallpaper from fixed file
[Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $FixedFile, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE)

# Force wallpaper reload on all desktops
Start-Process -FilePath "RUNDLL32.EXE" -ArgumentList "USER32.DLL,UpdatePerUserSystemParameters" -WindowStyle Hidden

Write-Host "Wallpaper updated successfully from: $realFilePath"
