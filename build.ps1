param([switch]$Preview)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$application = $manifest.applications.zotero
if (!$application.id -or !$application.update_url -or !$application.strict_min_version -or !$application.strict_max_version) {
    throw 'Zotero manifest requires id, update_url, strict_min_version and strict_max_version.'
}
if (!$application.update_url.StartsWith('https://')) {
    throw 'Zotero requires an HTTPS update_url.'
}
$outputDirectory = Join-Path $PSScriptRoot 'dist'
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$outputPath = Join-Path $outputDirectory "zotero-close-to-tray-$($manifest.version).xpi"
if ($Preview) { $outputPath = Join-Path $outputDirectory "zotero-close-to-tray-$($manifest.version)-preview.xpi" }
$stream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create)
$archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in @('manifest.json', 'bootstrap.js', 'tray.ps1', 'LICENSE',
        'icons/icon-48.png', 'icons/icon-96.png', 'icons/icon.ico')) {
        $entry = $archive.CreateEntry($name)
        $entry.LastWriteTime = [DateTimeOffset]::new(2026, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $inputStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot $name))
        $entryStream = $entry.Open()
        try { $inputStream.CopyTo($entryStream) }
        finally { $entryStream.Dispose(); $inputStream.Dispose() }
    }
}
finally {
    $archive.Dispose()
    $stream.Dispose()
}
$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Preview) {
    Write-Output $outputPath
    Write-Output "sha256:$hash"
    return
}
$updates = [ordered]@{
    addons = [ordered]@{
        $application.id = [ordered]@{
            updates = @([ordered]@{
                version = $manifest.version
                update_link = "https://github.com/p1aintiff/zotero-close-to-tray/releases/download/v$($manifest.version)/zotero-close-to-tray-$($manifest.version).xpi"
                update_hash = "sha256:$hash"
                applications = [ordered]@{ zotero = [ordered]@{
                    strict_min_version = $application.strict_min_version
                    strict_max_version = $application.strict_max_version
                } }
            })
        }
    }
} | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'updates.json'), $updates.Replace("`r`n", "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Output $outputPath
Write-Output "sha256:$hash"
