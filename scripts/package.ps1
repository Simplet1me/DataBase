$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$archivePath = [IO.Path]::GetFullPath((Join-Path $projectRoot '../../DataBase-main-已完成.zip'))
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'release/club-manage.jar'))) { throw '请先构建交付JAR。' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'frontend/dist/index.html'))) { throw '请先构建前端。' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
# 压缩包和源项目分离，只替换同名的本次完成版，不覆盖用户上传的原始压缩包。
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath }
$zip = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $files = Get-ChildItem -LiteralPath $projectRoot -File -Recurse -Force | Where-Object {
        $_.FullName -notmatch '[\\/](node_modules|target|logs|\.git)[\\/]' -and $_.Name -ne 'failure.png'
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\','/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, ('DataBase-main/' + $relative), [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $zip.Dispose() }
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Set-Content -LiteralPath ($archivePath + '.sha256') -Value ($hash + '  ' + [IO.Path]::GetFileName($archivePath)) -Encoding UTF8
Write-Host "压缩包：$archivePath"
Write-Host "SHA256：$hash"
