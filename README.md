# Cloud Saves for Everything!
This is a PowerShell script that, provided a list of directories, will automatically set up shortcuts between those directories and a location on a Cloud drive as specified by you. This is intended to be used in conjuction with a Cloud service that can sync locally (i.e. OneDrive, Google Drive or Dropbox).

# DISCLAIMER
***PLEASE BACKUP YOUR SAVE GAMES FIRST!***

This script does perform backups for you, but it also deletes said backups if it thinks everything went fine. That's on purpose because I want to keep my computer clean, but be aware of that fact before doing anything without making your own backups. I don't want anyone blaming me for having corrupted or lost save games.

# Initial Setup
1. Download the `CloudSaves.ps1` script (and optionally the `Config.txt` and `DirectoryMap.txt` files), and store them together in any folder on your computer (I would recommend storing it on your Cloud drive so you can easily maintain a single Config and DirectoryMap file for all your computers).
2. Populate `Config.txt` with `cloudSavesDir` - the path to a directory synced to your Cloud storage (this directory should ideally be set to "Always keep on this device" or similar per Cloud service), `backupDir` - the path to an ideally non-synced backup directory and `tempDir` - the path to a temporary working directory. Any directory can include `%USERPROFILE%` if desired (resolves to your C:\Users\\[Username] folder). The default (should work for OneDrive users) is as follows:
```
cloudSavesDir=%USERPROFILE%\OneDrive\Games\CloudSaves
backupDir=%USERPROFILE%\CloudSaveBackups
tempDir=\TEMP
```
3. Populate `DirectoryMap.txt` with a comma-separated list of game save directories, followed by the desired name of the Cloud folder they'll be saved to, e.g.
```
%USERPROFILE%\AppData\Roaming\.minecraft\saves, Minecraft Vanilla
%USERPROFILE%\AppData\Roaming\StardewValley\Saves, Stardew Valley
C:\Program Files (x86)\Steam\steamapps\common\XCOM 2\XCom2-WarOfTheChosen\XComGame\CharacterPool, XCOM2 Character Pool
```
4. Run the script in PowerShell (you may need to adjust security settings because I can't be bothered to figure out how to sign a script after spending a whole day on this). If something goes wrong, you'll find your savegame backups in the directory you specified, and you can just copy+paste them back where they belong (perhaps after deleting the shortcut this script created where your savegame folder is, and replacing it with a regular folder again, depending on how far it got). The `Errors.log` file should show what went wrong if the script doesn't indicate anything specific, so you may be able to solve your issues from there (feel free to check the Possible Issues section below first, though).

# Setup on Other Devices
1. Download the `CloudSaves.ps1` script on your other device.
2. In the same folder, populate `Config.txt` as above, and ensure the `cloudSavesDir` points to the same Cloud-synced directory as your other device (the other 2 directories can be whatever you desire for this device, or the same as the first one).
3. Copy+paste the `DirectoryMap.txt` file you used on your first device to the folder with the script on this device (via USB, putting it in your OneDrive and getting it off there, or emailing it to yourself).
4. Run the script in PowerShell as above.

# Possible Issues
## ```[Game] appears to already be syncing.```

This means the game's local save directory is a symlink (i.e. a shortcut). This could have been created by this script, or by a user at some other point. An option for solving this is to open the saves shortcut/folder, copy the saves out, delete the shortcut/folder, then create a new folder with the same name, and copy the saves back into that. Subsequently, you should be able to run the script successfully.

## ```Files for [Game] with the same name exist locally and could be lost. Check your backup directory if you need to restore them.```

This means your local save folder already contained files with the same name, but different data. If you've started a new game before running this script, and have synced this game before, that is likely to have caused it. For games ***with a limited set of save slots***, you'll want to back up the saves in `cloudSavesDir` somewhere (other than the `backupDir` above) and check them in-game, then compare their progress against the saves in `backupDir` by deleting the saves in `cloudSavesDir` then copying the `backupDir` saves to `cloudSavesDir`, and checking them in-game too. From there, you can pick which set of saves you want to keep, either the `backupDir` ones or the ones you backed up from `cloudSavesDir` initially, by copying the set you prefer into the `cloudSavesDir` (then you can confirm the saves work and delete the backups). It is also possible in a game ***with multiple save slots***, that you could first back up the `cloudSavesDir` saves somewhere (other than the `backupDir` above) then rename those with conflicting names, then copy all the saves in `backupDir` into the `cloudSavesDir` folder (then confirm the saves work and delete the backups). Finally, this could have occurred if the game has some sort of temporary files in the saves directory or if it automatically created save files before you actually started playing, in which case it's likely unimportant (then you can confirm the saves work and delete the backups).

The final result of this should just be a `cloudSavesDir` with a set of saves in it, and a local saves folder that is a shortcut to that Cloud directory (indicated by a little shortcut arrow icon on the bottom left of the folder icon).

## ```[Game] does not appear to be installed.```
This means the parent directory of the saves folder does not exist, e.g. for `%USERPROFILE%\AppData\Roaming\StardewValley\Saves, Stardew Valley`, the `StardewValley` folder does not exist. First, confirm that the game is installed, otherwise it's likely safe to create the directory manually, or you can start a new save game, and then run the script again. It is possible this will cause the `Files [...] exist locally` warning described above, but in this case you would likely be safe to just delete the backup and continue on normally (again, I recommend testing that the game works after running the script and before deleting any backups though).