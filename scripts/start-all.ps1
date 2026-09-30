$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$jarFile = Join-Path $projectRoot 'release/club-manage.jar'
if (-not (Test-Path -LiteralPath $jarFile)) { throw '缺少 release/club-manage.jar，请先运行 scripts/build.ps1。' }
Get-Command java,node -ErrorAction Stop | Out-Null
foreach ($port in @(8080,5173)) {
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "端口 $port 已占用，请先停止占用进程或本项目。" }
}
$logDirectory = Join-Path $projectRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$state = @()
try {
    # 隐藏启动窗口，运行日志写入项目 logs 目录。
    $backend = Start-Process -FilePath (Get-Command java).Source -ArgumentList @('-jar', ('"' + $jarFile + '"')) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDirectory/backend.log" -RedirectStandardError "$logDirectory/backend-error.log"
    $state += @{ id=$backend.Id; started=$backend.StartTime.ToUniversalTime().ToString('o'); name='java'; role='backend' }
    $frontend = Start-Process -FilePath (Get-Command node).Source -ArgumentList @('scripts/serve-frontend.mjs') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logDirectory/frontend.log" -RedirectStandardError "$logDirectory/frontend-error.log"
    $state += @{ id=$frontend.Id; started=$frontend.StartTime.ToUniversalTime().ToString('o'); name='node'; role='frontend' }
    $state | ConvertTo-Json | Set-Content -LiteralPath "$logDirectory/run-state.json" -Encoding UTF8
    Write-Host '前后端已启动。浏览器访问 http://localhost:5173 ，日志位于 logs。'
    Write-Host '停止服务：双击 scripts/stop-all.bat。'
} catch {
    foreach ($entry in $state) { Stop-Process -Id $entry.id -ErrorAction SilentlyContinue }
    throw
}
