# storj-upload
PowerShell script for uploading the folder
Uploads all files to the existing buckets at Storj network.
Script use the folders names for searching the existing bucket with such name and serach, which files is not exists in this bucket and upload it to this bucket.

## Usage
`$Env:STORJ_KEYPASS = <your password for unlocking yours key from Storj>`
`upload.ps1` \[`-Path <folder to scan>`\]

If Path is not specified, then it would be a current folder.
