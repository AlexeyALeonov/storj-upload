# storj-upload
This project with scripts for upload and download from Storj Network

# [upload.ps1](/upload.ps1)
PowerShell script for uploading files from folders to buckets with same name, as folders name.
Uploads all files to the buckets at Storj network.
The script uses buckets names like folder names and checks for the presence of the same files in the bucket. If it does not find the files, it uploads them.

## Setup PowerShell execution policy
1. Open PowerShell as Administrator
2. Execute:
`Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
3. Execute:
`Unblock-file upload.ps1`

## Usage
1. `$Env:STORJ_KEYPASS = '<your password for unlocking yours key from Storj>'`
2. `upload.ps1` \[`-Path <folder to scan>`\]\[`-UseItAsBucket`\]\[`-Storj <path to the storj.exe>`\]\[`-MinimalMirrors <value>`\]

* `-Path <folder to scan>`
    * Synchronizing path. Current folder by default
* `-UseItAsBucket`
    * Using the base name of the `-Path` as name of the bucket
* `-Storj <path to the storj.exe>`
    * Full path to Storj CLI. `~\storj.exe` by default
* `-MinimalMirrors <value>`
    * 2 by default

# [isDownloadable.ps1](/isDownloadable.ps1)
PowerShell script for trying downloading files from buckets.
This is proof of retrievability files from buckets.

## Setup PowerShell execution policy
1. Open PowerShell as Administrator
2. Execute:
`Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
3. Execute:
`Unblock-file upload.ps1`

## Usage
1. `$Env:STORJ_KEYPASS = '<your password for unlocking yours key from Storj>'`
2. `isDownloadable.ps1` \[`-Storj <path to the storj.exe>`\]

* `-Storj <path to the storj.exe>`
    * Full path to Storj CLI. `~\storj.exe` by default

# [upload.sh](/upload.sh)
Bash script for uploading files from current directory to buckets with same name, as folders name.

## Uasge
1. Create the file `~/.storj.` with:
```
export STORJ_KEYPASS='<your password for unlocking yours key from Storj>'
```
2. Go to the folder, which content you want to upload
`cd Photo`
3. `upload.sh`

# Support
If you want any new feature or you have found a bug, please submit an issue or create a pull request containing fix.

I will be grateful for donations:

    BTC and SJCX: 12GMzcEZQWquBkpqAcnh2aKqvVMEZFk1Nq
    ETH: 0x8D7a2e3C16d029F838d1F6327449fd46B5daf881

Thank you very much for your support!
