$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$stateFile = Join-Path $projectRoot 'logs/run-state.json'
if (-not (Test-Path -LiteralPath $stateFile)) { Write-Host '没有本脚本启动的进程记录。'; exit 0 }
$state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $state) {
    $process = Get-Process -Id $entry.id -ErrorAction SilentlyContinue
    # 同时比较进程号、程序名和启动时间，防止停止复用相同进程号的其他程序。
    if ($process -and $process.ProcessName -eq $entry.name -and $process.StartTime.ToUniversalTime().ToString('o') -eq $entry.started) {
        Stop-Process -Id $entry.id
        Write-Host "已停止 $($entry.role)。"
    }
}
Remove-Item -LiteralPath $stateFile
