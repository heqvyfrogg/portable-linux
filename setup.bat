@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux Installer

rem 1. Determine target directory: use arg %1 if provided, otherwise the directory where this script is located (%~dp0)
set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" set "TARGET_DIR=%~dp0"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

echo ========================================================
echo   Portable Linux (Debian 12 + QEMU) Installer
echo   Target: %TARGET_DIR%
echo   No Administrator Privileges Required.
echo ========================================================
echo.

rem Check if already installed in this directory
if exist "%TARGET_DIR%\start.bat" (
  echo [WARN] Portable Linux already exists in: %TARGET_DIR%
  set "OVERWRITE=n"
  set /p "OVERWRITE=Do you want to re-download and update files? (y/N): "
  set "OVERWRITE=!OVERWRITE: =!"
  if /i not "!OVERWRITE!"=="y" exit /b 0
)

echo [1/3] Downloading latest portable-linux package from GitHub...
set "ZIP_FILE=%TEMP%\portable-linux_%RANDOM%.zip"
curl.exe -L -o "%ZIP_FILE%" "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/portable-linux.zip"

if not exist "%ZIP_FILE%" (
  echo [ERROR] Failed to download portable-linux.zip.
  pause
  exit /b 1
)

echo [2/3] Extracting package to %TARGET_DIR%...
powershell -NoProfile -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%TARGET_DIR%' -Force"
del /f /q "%ZIP_FILE%" >nul 2>&1

echo [3/3] Finalizing security permissions...
if exist "%TARGET_DIR%\ssh\id_ed25519" (
  icacls.exe "%TARGET_DIR%\ssh\id_ed25519" /inheritance:r >nul 2>&1
  icacls.exe "%TARGET_DIR%\ssh\id_ed25519" /grant:r "%USERNAME%:(R,W)" >nul 2>&1
)

echo.
echo ========================================================
echo   Installation Successful!
echo   Location: %TARGET_DIR%
echo   Double-click '%TARGET_DIR%\start.bat' to start!
echo ========================================================
echo.
pause
