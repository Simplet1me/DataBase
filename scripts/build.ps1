$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
# 构建操作独立于启动脚本；前端依赖按锁文件安装，启动不负责安装依赖或初始化数据库。
Push-Location (Join-Path $projectRoot 'frontend')
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw '前端依赖安装失败。' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw '前端构建失败。' }
} finally { Pop-Location }
if (Get-Command mvn -ErrorAction SilentlyContinue) { mvn -DskipTests package } else { & '.\mvnw.cmd' -DskipTests package }
if ($LASTEXITCODE -ne 0) { throw '后端打包失败；请停止正在占用 target 内 jar 的开发进程后重试。' }
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'release') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'target/DataBase-0.0.1-SNAPSHOT.jar') -Destination (Join-Path $projectRoot 'release/club-manage.jar') -Force
Write-Host '构建完成：release/club-manage.jar 与 frontend/dist。'
