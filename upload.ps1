[CmdletBinding()]
Param(
    $path,
    $storj,
    [Switch]$UseItAsBucket
)

if (-not $path) {$path = '.'}
if (-not $storj) {$storj = '~\storj.exe'}

$dirs = Get-ChildItem $path -Directory

$attempt = 0;
do {
    $buckets = (&$storj list-buckets | sls "id: (.*?) .*Name: (.*)").matches;
    $attempt++;
} while (-not $buckets -and $attempt -le 3);

# Creation of non-existing buckets
if (-not $UseItAsBucket) {
    foreach ($dir in $dirs) {
        $found = $false;
        foreach ($bucket in $buckets) {
            if ($bucket.Groups[2].Value.ToString() -eq $dir.Basename.ToString()) {
                $found = $true;
            Write-Verbose ($bucket.Groups[2].Value.ToString() + " == " + $dir.Basename.ToString());
                break;
            }
        }
        if (-not $found) {
            Write-Verbose ("&$storj add-bucket " + $dir.Basename);
            $folder = [System.Text.Encoding]::Default.GetString([System.Text.Encoding]::UTF8.GetBytes($dir.Basename));
            &$storj add-bucket $folder
        }
    }
}

# Reread new list after creation
$attempt = 0;
do {
    Write-Verbose "Attempt $attempt to get list of the buckets...";
    $buckets = (&$storj list-buckets | sls "id: (.*?) .*Name: (.*)").matches;
    $attempt++;
} while (-not $buckets -and $attempt -le 3);

$buckets | %{
    $bucketName = $_.Groups[2].value;
    $bucketID = $_.Groups[1].Value;

    $files = $null;
    if ($UseItAsBucket) {
        if ($bucketName.CompareTo((Split-Path $path -Leaf)) -eq 0) {
            $files = Get-ChildItem $path -Recurse | ? length -gt 1000;
        } else {
            $files = $null;
        }
    } else {
        $files = Get-ChildItem (Join-Path $path $bucketName) -Recurse | ? length -gt 1000;
    }

    $attempt = 0;
    $bucketFiles = $null;
    do {
        Write-Verbose "Attempt $attempt to read files from bucket $bucketID"
        $bucketFiles = (&$storj list-files $bucketID | sls "id: (.*?) .*Name: (.*)").matches;
        $attempt++;
    } while (-not $bucketFiles -and $attempt -le 3);

    # Remove files without mirrors from buckets
    ForEach ($bFile in $bucketFiles) {
        $fileID = $bFile.Groups[1].Value;
        $fileName = $bFile.Groups[2].Value;

        $attempt = 0;
        $count = -5;
        do {
            Write-Verbose "Attempt $attempt to get mirrors for $fileID from $bucketID...";
            $count = -5;
            $mirrors = &$storj list-mirrors $bucketID $fileID
            $mirrors | %{if ($_.Contains("Available")) {break} else {$count++}}
            $attempt++;
        } while ($count -lt 2 -and $attempt -le 3);
        if ($count -lt 0) {$count = 0}

        Write-Verbose "Checking sufficient mirrors of $fileName ( $fileID ) in '$bucketName' ( $bucketID )";
        if ($count -lt 2) {
            Write-Warning "File '$fileName' ( $fileID ) in '$bucketName' ( $bucketID ) have a insufficient mirrors ($count)";
            &$storj remove-file $bucketID $fileID
        }
    }

    $attempt = 0;
    $bucketFiles = $null;
    do {
        Write-Verbose "Attempt $attempt to read files from bucket $bucketID"
        $bucketFiles = (&$storj list-files $bucketID | sls "id: (.*?) .*Name: (.*)").matches;
        $attempt++;
    } while (-not $bucketFiles -and $attempt -le 3);

    foreach ($file in $files) {
        $found = $false;
        ForEach ($bFile in $bucketFiles) {
            $fileID = $bFile.Groups[1].Value;
            $fileName = $bFile.Groups[2].Value;

            if ($file.ToString() -eq $fileName.ToString()) {
                Write-Verbose "$file exist in $bucketID";
                $found = $true;
                break;
            }
        }

        if (-not $found) {
            Write-Verbose ("&$storj upload-file $bucketID " + $file.FullName);
            $errorsCount = 0;
            do {
                $errors = $null;
                $uploadContext = $null;
                &$storj upload-file $bucketID $file.FullName | % {
                    [System.Console]::WriteLine($_);
                    $errors = $_.Contains("error") -or $_.Contains("Exception");
                    $uploadContext += $_;
                }
                if ($errors -and $uploadContext.Contains("rate limit")) {
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
            } While ($errors);
        }
    }
}
