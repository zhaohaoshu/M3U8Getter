param(
    [uri]$m3u8Uri,
    [string]$path
)

New-Item -Path $path -ItemType Directory -Force

$tmpPath = Join-Path $path _tmp
function Download($uri, $path) {
    if (-not (Test-Path $path)) {
        Write-Host Download $path
        Invoke-WebRequest -Uri $uri -OutFile $tmpPath
        Move-Item -Path $tmpPath -Destination $path
    } else {
        Write-Host Exists $path
    }
}

$m3u8Path = Join-Path $path $m3u8Uri.Segments[-1]
Download -uri $m3u8Uri -path $m3u8Path

$m3u8LocalPath = Join-Path $path ('_local_' + $m3u8Uri.Segments[-1])
[System.IO.File]::CreateText($m3u8LocalPath).Close()
Get-Content $m3u8Path | ForEach-Object {
    Write-Host $_
    if ($_ -and -not $_.StartsWith('#')) {
        $entryUri = [uri]::new($m3u8Uri, $_)
        Write-Host Get $entryUri
        $entryPath = Join-Path $path $entryUri.Segments[-1]
        Download -uri $entryUri -path $entryPath
        [System.IO.File]::AppendAllLines($m3u8LocalPath, [string[]]$entryUri.Segments[-1])
    } elseif ($ss = $_ | Select-String -Pattern '#EXT-X-KEY:.*URI="(?<keyUri>.*)"') {
        $matchGroup = $ss.Matches[0].Groups | Where-Object { $_.Name -eq 'keyUri' }
        $keyUri = [uri]::new($m3u8Uri, $matchGroup.Value)
        Write-Host Get $keyUri
        $keyPath = Join-Path $path $keyUri.Segments[-1]
        Download -uri $keyUri -path $keyPath
        [System.IO.File]::AppendAllLines($m3u8LocalPath, [string[]]($_.SubString(0, $matchGroup.Index) + $keyUri.Segments[-1] + $_.SubString($matchGroup.Index + $matchGroup.Length)))
    } else {
        [System.IO.File]::AppendAllLines($m3u8LocalPath, [string[]]$_)
    }
}
