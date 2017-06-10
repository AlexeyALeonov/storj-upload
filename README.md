# storj-upload
`upload.ps1` This is a PowerShell script for uploading files from folders to existing buckets with same name, as folder name.
Uploads all files to the existing buckets at Storj network.
The script uses buckets names like folder names and checks for the presence of the same files in the bucket. If it does not find the files, it uploads them.

## Setup PowerShell execution policy
1. Open PowerShell as Administrator
2. Execute:
`Set-ExecutionPolicy -ExecutionPolicy Unrestricted`

## Usage
1. `$Env:STORJ_KEYPASS = "<your password for unlocking yours key from Storj>"`
2. `upload.ps1` \[`-Path <folder to scan>`\]\[`-Storj <path to the storj.exe>`\]

If Path doesn't specified, it would be a current folder.
If Storj doesn't specified, it search for `storj.exe` in home folder (`~\storj.exe`)

# Support
If you want any new feature or you have found a bug, please submit an issue or create a pull request containing fix.

I will be grateful for donations:

    BTC and SJCX: 12GMzcEZQWquBkpqAcnh2aKqvVMEZFk1Nq
    ETH: 0x8D7a2e3C16d029F838d1F6327449fd46B5daf881

Thank you very much for your support!
