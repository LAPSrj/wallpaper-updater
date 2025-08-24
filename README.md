# Daily Wallpaper Updater

This repository provides a PowerShell script and a pre-configured Windows Task Scheduler XML file to automatically download and set Bing's wallpaper of the day as your desktop background, updating daily without user interaction.

It basically does the same as the [Bing Wallpaper](https://www.bing.com/apps/wallpaper) app, but with the following benefits:

- It works consistently
- **It changes the images on all virtual desktops, not just the current one**
- It doesn't open Bing the first time you click on your desktop after a image change
- Images are downloaded direclty from Bing

The reason I made this script is because I got tired of all the bugs of the official app, like when sometimes it would just close and I would notice when the wallpaper wasn't updated or when it was running but it wouldn't update the background, even after restarting the app. And the most annoying issue of all, it would only change the background of the desktop I was using at the time it download the new one. And if you are wondering why I don't use the spotlight wallpapers it's because the Bing ones are prettier.


## Files Included

- **wallpaper_downloader.ps1**  
  PowerShell script:
  - Calls Bing’s API to get today’s image for the selected market.
  - Tries the **best URLs** first (`_UHD.jpg`, 7680×4320, 5120×2880, 3840×2160, …, then the standard url, ensuring the highest resolution is downloaded).
  - Sets the wallpaper on **all virtual desktops**.
  - Prunes to last **10** images.
  - **Daily-success guard**: only does real work **once/day per market** (hourly repeats exit instantly once done).

- **Update Wallpaper (ps1).xml** (PS1 version)  
  Task Scheduler XML that runs PowerShell with **hidden** window and **hourly repeat**:
  - Daily at **05:00**, repeats **every 1 hour** for **1 day**, **Stop at end of duration**.
  - **Start when available**, **Wake to run**, **Network required**.
  - Action: `powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%USERPROFILE%\wallpaper_downloader.ps1" -Location ca`

- **Update Wallpaper.xml** (EXE version)  
  Same schedule, but runs the compiled executable, avoiding poweshell window blinking:
  - Action: `"%USERPROFILE%\wallpaper_downloader.exe" -Location ca`

- **wallpaper_downloader.exe**  
  Compiled binary of the PowerShell script to avoid PowerShell window blinking. You can **rebuild your own** with ps2exe (below).

## Usage

### 1) Run the script once to test
```powershell
# Example: Canada (English)
.\wallpaper_downloader.ps1 -Location ca

# Example: Brazil
.\wallpaper_downloader.ps1 -Location br
```

### 2) Import the scheduled task
Open **Task Scheduler → Action → Import Task…** and pick either:

- **Update Wallpaper.xml** (PS1) — good for editing the script without recompiling.  
- **Update Wallpaper (exe).xml** (EXE) — uses the compiled app for no UI.

After import, you can adjust:
- **Triggers → Edit → Start time** if 05:00 is not ideal.
- **Actions → Arguments** to change `-Location` (e.g., `en-GB`).

You can also import via command line (PowerShell as Admin):
```powershell
# PS1 flavor
schtasks /Create /TN "Update Wallpaper" /XML ".\Update Wallpaper.xml"

# EXE flavor
schtasks /Create /TN "Update Wallpaper (exe)" /XML ".\Update Wallpaper (exe).xml"
```

## Compile to EXE (optional but recommended for Task Scheduler)
Install ps2exe (once):
```powershell
Install-Module ps2exe -Scope CurrentUser
```

Compile:
```powershell
Invoke-ps2exe .\wallpaper_downloader.ps1 .\wallpaper_downloader.exe -noConsole
```

> The script auto-detects whether it’s in a real console. In **compiled/no-console** mode it **suppresses** all UI and message boxes; in a console it prints debug messages.

## Notes & Defaults
- Default market is **`ca`**. Pass `-Location us`, `-Location fr-CA`, etc., to change.  
- Requires network: the task is set to **Run only if network available**.  
- **Wake to run** is enabled so the 05:00 run happens even from sleep, so you can have a beautiful new image when you start your day.  
- Hourly repeats continue through the day; the script immediately returns after the **first success** of the day. This ensures the script will download the image even if it has missed the first window.

## Troubleshooting
- Missed the 05:00 run? The task’s **hourly repeat** will try again on the next hour.  
- Want fewer retries? Change **Triggers → Repeat task every** to a larger interval.  
- Nothing happens when run by Task Scheduler but works in console? Ensure your **`TodayWallpapers`** folder exists and you have permission; check **Task History** and Windows Event Viewer.  
- To change the save folder or keep more/less images, edit: `Prune-OldWallpapers -Keep 10` in the script.

## License
See [LICENSE](LICENSE).
