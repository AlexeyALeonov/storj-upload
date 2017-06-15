[CmdletBinding()]
Param(
    $Storj
)

if (-not $storj) {$storj = '~\Storj.exe'}

$temp = (Join-Path $env:Temp 1);
(&$Storj list-buckets | sls "id: (.*?) ").matches | ? Success | % {
    $bucketID = $_.Groups[1].Value; 
    (&$Storj list-files $bucketID | sls "id: (.*?) ").matches | ? Success | %{
        if (Test-Path $temp) {rm $temp}
        $fileID = $_.Groups[1].Value; 
        &$Storj download-file $bucketID $fileID $temp | %{
            if ($_.Contains("error") -or $_.Contains("failed")) {
                Write-Warning ($bucketID + " " + $fileID + ":" + $_);
            }
        }
    }
}
