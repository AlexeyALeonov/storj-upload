[CmdletBinding()]
Param(
    $Path,
    $Storj,
    [Switch]$UseItAsBucket,
    $MinimalMirrors
)

$eUTF8 = [System.Text.Encoding]::UTF8;
$eDefault = [System.Text.Encoding]::Default;

if (-not $path) {$path = '.'}
if (-not $storj) {$storj = '~\storj.exe'}
if (-not $MinimalMirrors) {$MinimalMirrors = 2}

if ($UseItAsBucket) {
    $dirs = $path;
} else {
    $dirs = Get-ChildItem $path -Directory
}

# hash table of buckets
$bucks = @();

# buckets, created by Libstorj (bug #3)
$attempt = 0;
$buckets = $null;
do {
    [System.Console]::OutputEncoding = $eDefault;
    $buckets = (&$storj list-buckets | sls "id: (.*?) .*Decrypted: true .*Name: (.*)").matches;
    $attempt++;
} while (-not $buckets -and $attempt -le 3);

$buckets | ? Success | %{
    $bucks += @{
        bucketID = $_.Groups[1].Value; 
        bucketName = $_.Groups[2].Value;
    }
}

# buckets, created by Storj
$attempt = 0;
$buckets = $null;
do {
    [System.Console]::OutputEncoding = $eUTF8;
    $buckets = (&$storj list-buckets | sls "id: (.*?) .*Decrypted: false .*Name: (.*)").matches;
    $attempt++;
} while (-not $buckets -and $attempt -le 3);

$buckets | ? Success | %{
    $bucks += @{
        bucketID = $_.Groups[1].Value; 
        bucketName = $_.Groups[2].Value;
    }
}

# Creation of non-existing buckets
foreach ($dir in $dirs) {
    $found = $false;
    $folder = Split-Path $dir -Leaf;
    foreach ($bucket in $bucks) {
        Write-Verbose ($bucket.bucketName + " == " + $folder + "?");
        if ($bucket.bucketName -eq $folder) {
            $found = $true;
            Write-Verbose ($bucket.bucketName + " == " + $folder);
            break;
        }
    }
    if (-not $found) {
        Write-Verbose ("&$storj add-bucket " + $folder);
        (&$storj add-bucket $folder | sls "id: (.*?) ").Matches | ? Success | %{
            $bucks += @{bucketID = $_.Groups[1].Value; bucketName = $folder}
        }
    }
}

# synchronizing
$bucks | %{
    $bucketName = $_.bucketName;
    $bucketID = $_.bucketID;

    $files = $null;
    if ($UseItAsBucket) {
        if ($bucketName.CompareTo((Split-Path $path -Leaf)) -eq 0) {
            $files = Get-ChildItem $path -Recurse | ? length -gt 1;
        } else {
            $files = $null;
        }
    } else {
        $files = Get-ChildItem (Join-Path $path $bucketName) -Recurse | ? length -gt 1;
    }

    if ($files) {
        # cleanup
        for ($rem = 1; $rem -le 2; $rem++) {
            # hash table of the files from bucket
            $bFiles = @();

            # files from bucket created by Libstorj (bug #3)
            $attempt = 0;
            $bucketFiles = $null;
            do {
                Write-Verbose "Attempt $attempt to read files from bucket $bucketID"
                [System.Console]::OutputEncoding = $eDefault;
                $bucketFiles = (&$storj list-files $bucketID | sls "id: (.*?) .*Decrypted: true .*Name: (.*)").matches;
                $attempt++;
            } while (-not $bucketFiles -and $attempt -le 3);

            $bucketFiles | ? Success | %{
                $bFiles += @{
                    fileID = $_.Groups[1].Value;
                    fileName = $_.Groups[2].Value;
                }
            }

            # files from bucket created by Storj
            $attempt = 0;
            $bucketFiles = $null;
            do {
                Write-Verbose "Attempt $attempt to read files from bucket $bucketID"
                [System.Console]::OutputEncoding = $eUTF8;
                $bucketFiles = (&$storj list-files $bucketID | sls "id: (.*?) .*Decrypted: false .*Name: (.*)").matches;
                $attempt++;
            } while (-not $bucketFiles -and $attempt -le 3);

            $bucketFiles | ? Success | %{
                $bFiles += @{
                    fileID = $_.Groups[1].Value;
                    fileName = $_.Groups[2].Value;
                }
            }

            if ($rem -eq 2) {break}

            # Remove files without mirrors from buckets
            ForEach ($bFile in $bFiles) {
                $fileID = $bFile.fileID;
                $fileName = $bFile.fileName;

                $attempt = 0;
                $count = -5;
                do {
                    Write-Verbose "Attempt $attempt to get mirrors for $fileID from $bucketID...";
                    $count = -5;
                    $mirrors = &$storj list-mirrors $bucketID $fileID
                    $mirrors | %{if ($_.Contains("Available")) {break} else {$count++}}
                    $attempt++;
                } while ($count -lt $MinimalMirrors -and $attempt -le 3);
                if ($count -lt 0) {$count = 0}

                Write-Verbose "Checking sufficient mirrors of $fileName ($fileID) in '$bucketName' ($bucketID)";
                if ($count -lt $MinimalMirrors) {
                    Write-Warning "File '$fileName' ($fileID) in '$bucketName' ($bucketID) have a insufficient mirrors ($count)";
                    &$storj remove-file $bucketID $fileID
                }
            }
        }

        # uploading
        foreach ($file in $files) {
            # search for existing files
            $found = $false;
            ForEach ($bFile in $bFiles) {
                $fileID = $bFile.fileID;
                $fileName = $bFile.fileName;
                if ($file.ToString() -eq $fileName.ToString()) {
                    Write-Verbose "$file exist in $bucketID";
                    $found = $true;
                    break;
                }
            }

            if (-not $found) {
                Write-Verbose ("&$storj upload-file $bucketID " + $file.FullName);
                $errorsCount = 0;
                $attempt = 0;
                do {
                    $errors = $null;
                    $uploadContext = $null;
                    &$storj upload-file $bucketID $file.FullName | % {
                        [System.Console]::WriteLine($_);
                        $errors = $_.Contains("error") -or $_.Contains("Exception") -or $_.Contains("Unable to receive storage offer");
                        $uploadContext += $_;
                    }
                    if ($errors -and ($uploadContext.Contains("rate limit") -or $uploadContext.Contains("Unable to receive storage offer"))) {
                        Write-Verbose "Wait for bridge rate limit disappear";
                        sleep 60;
                        $errorsCount++;
                        # sleep (60 * 60 + 10);
                    }
                    if ($errorsCount -ge 3) {
                        $errorsCount = 0;
                        Write-Verbose "Wait for free tier error limit disappear";
                        sleep (60 * 60);
                    }
                    $attempt++;
                } While ($errors -and $attempt -le 3);
                if ($errors -and $attempt -ge 3) {
                    Write-Warning ("Skipping file '" + $file.FullName + "' from upload to '$bucketName' ($bucketID)");
                }
            }
        }
    }
}
