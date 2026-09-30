@echo off
chcp 65001 >nul
cd /d "%~dp0.."
node scripts/db.mjs demo club_manage
if errorlevel 1 exit /b 1
pause
