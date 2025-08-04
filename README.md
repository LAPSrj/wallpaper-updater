# Daily Wallpaper Updater

This repository provides a PowerShell script and a pre-configured Windows Task Scheduler XML file to automatically download and set Bing's wallpaper of the day as your desktop background, updating daily without user interaction.

It basically does the same as the [Bing Wallpaper](https://www.bing.com/apps/wallpaper) app, but with the following benefits:

- It works consistently
- **It changes the images on all virtual desktops, not just the current one**
- It doesn't open Bing the first time you click on your desktop after a image change

The reason I made this script is because I got tired of all the bugs of the official app, like when sometimes it would just close and I would notice when the wallpaper wasn't updated or when it was running but it wouldn't update the background, even after restarting the app. And the most annoying issue of all, it would only change the background of the desktop I was using at the time it download the new one. And if you are wondering why I don't use the spotlight wallpapers it's because the Bing ones are prettier.


## Files Included

- **wallpaper_downloader.ps1**  
  PowerShell script that:
  - Downloads the daily Bing wallpaper (default: Canada version).
  - Saves it with its original filename and keeps a copy as `Today.jpg`.
  - Sets it as your Windows wallpaper.
  - Keeps the last 10 downloaded wallpapers, in case you want to retrieve your favorites.

- **Update Wallpaper.xml**  
  A ready-to-import Windows Task Scheduler task that:
  - Runs the script daily at 5:00 AM (or at the first opportunity).
  - Updates the wallpaper silently in the background.

### Why is there a `Today.jpg` file?

Since Microsoft still doesn't offer an easy way to programatically change the background of all the desktops at once, I had to get creative to achieve that. The solution I found was to use the same image file but change its contents daily. By doing so it is possible to just make a call for Windows Explorer to update its cache and the image is be replaced on all virtual desktops.


## Requirements

- Windows 10 or 11


## Installation Steps

### 1. Download Files

1. Click **Code → Download ZIP** or clone this repository:
   ```
   git clone https://github.com/<your-username>/wallpaper-updater.git
   ```
2. Extract or place both files (`wallpaper_downloader.ps1` and `Update Wallpaper.xml`) into your user profile folder:
   ```
   C:\\Users\[username]\
   ```
   
   or simply paste this into Windows Explorer address bar:

   ```
   %USERPROFILE%\
   ```

   or any preferred folder (but make sure you adjust the paths in Task Scheduler if you change the location).

### 2. Import Scheduled Task

1. Press **Win+R**, type `taskschd.msc`, press **Enter**.
2. In Task Scheduler, click **Action → Import Task...**
3. Select the `Update Wallpaper.xml` file.
4. Review the task settings:
   - **General → Run only when user is logged on** (recommended for reliable wallpaper updates).
   - **Triggers → Adjust time** if you want it to run at a different hour.
   - **Actions → Verify script path and location parameter** matches your chosen folder and region.
5. Click **OK**, enter your Windows account password when prompted.

### 3. (Optional) Edit Script Parameters

The script supports different Bing locations:

| Location Code | Region             |
|---------------|--------------------|
| us            | United States      |
| ca            | Canada (default)   |
| uk            | United Kingdom     |
| jp            | Japan              |
| de            | Germany            |
| fr            | France             |
| es            | Spain              |
| br            | Brazil             |
| in            | India              |
| au            | Australia          |
| cn            | China              |
| it            | Italy              |

Example: To use the Brazilian feed, change the scheduled task arguments to:
```
-WindowStyle Hidden -ExecutionPolicy Bypass -File "%USERPROFILE%\wallpaper_downloader.ps1" -Location br
```

### 4. Test the Task

- Right-click the imported task → **Run**.
- Within a few seconds, the wallpaper should download and update to Bing's daily image.


## Updating the background on all desktops

For this script to be able to change the image on all desktops, you need to either:

- Delete all other desktops before running it for the first time; or
- Manually run the script once on each desktop; or
- Go to the Settings app, Personalization, Background, right click the image and click Set for all desktops.
**Settings** app → **Personalization** → Right click the current background image → Click **Set for all desktops**

If you want to use a different background on a specific desktop, you can change the image on that desktop and it won't be automatically updated anymore.


## Disclaimer

This project is an independent, open-source utility that automates the process of downloading and setting Bing's daily wallpaper. 

- All images are fetched from [bing.gifposter.com](https://bing.gifposter.com), which republishes wallpapers from the Microsoft Bing homepage.  
- This project is **not affiliated with Microsoft**, Bing, or gifposter.com in any way.  
- All images, names, and copyrights belong to their respective owners.  
- This project does not claim ownership of any image and is provided solely for personal use.
- Satya, I'm a Microsoft fanboy but lately it's been getting hard to keep being one. And this script was coded from a Surface.