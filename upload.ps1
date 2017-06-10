Param(
    $path,
    $storj
)
if (-not $path) {$path = '.'}
if (-not $storj) {$storj = '~\storj.exe'}
(&$storj list-buckets | sls "id: (.*?) .*Name: (.*)").matches | ? Success | %{
    $bucketName = $_.Groups[2].value;
    $bucketID = $_.Groups[1].Value;
    $attempt = 0;
    $bucketFiles = $null;
    while (-not $bucketFiles -and $attempt -le 3) {
        $bucketFiles = (&$storj list-files $bucketID | sls "id: (.*?) .*Name: (.*)").matches;
        $attempt++;
    }
    
    Get-ChildItem (Join-Path $path $bucketName) -Recurse | ? length -gt 1000 | %{
        $isFound = $false;
        $file = $_;
        ForEach ($bFile in $bucketFiles) {
            $fileID = $bFile.Groups[1].Value;
            $fileName = $bFile.Groups[2].Value;
            Write-Debug "Checking sufficient mirrors of $fileName ($fileID) in '$bucketName' ($bucketID)";
            $attempt = 0;
            $count = -5;
            while ($count -lt 2 -and $attempt -le 3) {
                $count = -5;
                $mirrors = &$storj list-mirrors $bucketID $fileID
                $mirrors | %{if ($_.Contains("Available")) {break} else {$count++}}
                $attempt++;
            }
            if ($count -lt 2) {
                Write-Warning "File '$fileName' ($fileID) in '$bucketName' ($bucketID) have a insufficient mirrors ($count)";
                &$storj remove-file $bucketID $fileID
            }
            Write-Debug $fileName "== $file ?";
            if ($file.ToString() -eq $fileName.ToString() -and $count -gt 1) {
                Write-Host $file "found";
                $isFound = $true;
                break;
            }
        }
        if (-not $isFound) {
            Write-Debug "&$storj upload-file $bucketID" $file.FullName;
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
                    Write-Debug "Wait for bridge rate limit disappear";
                    sleep 60;
                    $errorsCount++;
                    # sleep (60 * 60 + 10);
                }
                if ($errorsCount -ge 3) {
                    $errorsCount = 0;
                    Write-Debug "Wait for free tier error limit disappear";
                    sleep (60 * 60);
                }
            } While ($errors);
        }
    }
}
