@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

if not exist "VERSION" (
    echo [ERROR] VERSION file not found.
    exit /b 1
)

set /p VERSION=<VERSION
if "%VERSION%"=="" (
    echo [ERROR] VERSION is empty.
    exit /b 1
)

set "BUILD_DIR=%CD%\Builds"
set "STAGE_DIR=%BUILD_DIR%\kfx-dedrm-v%VERSION%"
set "KINDLE_DIR=%STAGE_DIR%\COPY TO KINDLE ROOT"
set "OUTPUT=%BUILD_DIR%\kfx-dedrm-v%VERSION%.zip"
set "KTERM_PACKAGE=%CD%\third_party\kterm\package\kterm"
set "KTERM_LICENSE=%CD%\third_party\kterm\COPYING"
set "KTERM_SOURCE=%CD%\third_party\kterm\kterm-v2.6-source.zip"

if not exist "%KTERM_PACKAGE%\bin\kterm" (
    echo [ERROR] Bundled kterm 2.6 package is missing.
    exit /b 1
)
if not exist "%KTERM_LICENSE%" (
    echo [ERROR] kterm GPL license is missing.
    exit /b 1
)
if not exist "%KTERM_SOURCE%" (
    echo [ERROR] kterm corresponding source archive is missing.
    exit /b 1
)

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
if exist "%OUTPUT%" del /q "%OUTPUT%"

echo Checking shell script line endings...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $bad=@(); foreach ($f in Get-ChildItem -Path (Join-Path '%CD%' 'src') -Recurse -Filter *.sh) { if ([System.IO.File]::ReadAllBytes($f.FullName) -contains 13) { $bad += $f } }; if ($bad.Count -gt 0) { foreach ($f in $bad) { Write-Host ('[ERROR] CRLF detected: ' + $f.FullName) }; exit 1 }"

if errorlevel 1 (
    echo [ERROR] Build aborted because one or more shell scripts contain CRLF line endings.
    exit /b 1
)

echo Staging kfx-dedrm v%VERSION% distribution with kterm 2.6...
mkdir "%STAGE_DIR%" >nul 2>&1
mkdir "%KINDLE_DIR%" >nul 2>&1
xcopy "%CD%\src\*" "%KINDLE_DIR%\" /E /I /Q /Y >nul
mkdir "%KINDLE_DIR%\extensions" >nul 2>&1
xcopy "%KTERM_PACKAGE%\*" "%KINDLE_DIR%\extensions\kterm\" /E /I /Q /Y >nul

copy /Y "%CD%\README.md" "%STAGE_DIR%\README.md" >nul
copy /Y "%CD%\LICENSE" "%STAGE_DIR%\LICENSE" >nul
copy /Y "%CD%\THIRD_PARTY_NOTICES.md" "%STAGE_DIR%\THIRD_PARTY_NOTICES.md" >nul
copy /Y "%CD%\VERSION" "%STAGE_DIR%\VERSION" >nul
mkdir "%STAGE_DIR%\licenses\kterm-2.6" >nul 2>&1
copy /Y "%KTERM_LICENSE%" "%STAGE_DIR%\licenses\kterm-2.6\COPYING" >nul
mkdir "%STAGE_DIR%\source\kterm-2.6" >nul 2>&1
copy /Y "%KTERM_SOURCE%" "%STAGE_DIR%\source\kterm-2.6\kterm-v2.6-source.zip" >nul
mkdir "%STAGE_DIR%\source\satsuoni-kfx-dedrm-10.0.28-scriptlet\kindle_device" >nul 2>&1
xcopy "%CD%\third_party\satsuoni\kindle_device\*" "%STAGE_DIR%\source\satsuoni-kfx-dedrm-10.0.28-scriptlet\kindle_device\" /E /I /Q /Y >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Compress-Archive -Path (Join-Path '%STAGE_DIR%' '*') -DestinationPath '%OUTPUT%' -CompressionLevel Optimal"

if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

if not exist "%OUTPUT%" (
    echo [ERROR] Build completed without producing the ZIP.
    exit /b 1
)

echo.
echo [OK] Release created:
echo %OUTPUT%
exit /b 0
