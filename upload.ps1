Param(
    $path
)
if (-not $path) {$path = '.'}
(storj list-buckets | sls "id: (.*), Name: (.*?), Storage:").matches | %{
    $bucketName = $_.Groups[2].value;
    $bucketID = $_.Groups[1].Value;
    $bucketFiles = (storj list-files $bucketID | sls "Name: (.*), type:.* id: (.*)").matches;
    Get-ChildItem (Join-Path $path $bucketName) -Recurse | ? length -gt 1000 | %{
        $isFnd = $false;
        ForEach ($bFile in $bucketFiles) {
            Write-Information $bFile.Groups[1].Value "== $_ ?";
            if ($_.ToString() -eq $bFile.Groups[1].Value.ToString()) {
                Write-Information $_ "found";
                $isFnd = $true;
                break;
            }
        }
        if (-not $isFnd) {
            Write-Information "storj upload-file $bucketID" $_.FullName;
            storj upload-file $bucketID $_.FullName
        }
    }
}
