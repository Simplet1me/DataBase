@echo off
setlocal
cd /d "%~dp0.."
where mvn >nul 2>nul
if errorlevel 1 (
  call "%CD%\mvnw.cmd" -DskipTests package
) else (
  call mvn -DskipTests package
)
if errorlevel 1 exit /b 1
if not exist "release" mkdir "release"
copy /y "target\DataBase-0.0.1-SNAPSHOT.jar" "release\club-manage.jar" >nul
if errorlevel 1 exit /b 1
echo Build complete: release\club-manage.jar
exit /b 0
