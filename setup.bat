@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux Installer

rem 1. Determine target directory: use arg %1 if provided, otherwise default to a dedicated 'portable-linux' folder in current directory
set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" (
  rem If running from inside a portable-linux folder already (e.g. updater mode), keep it, otherwise install to portable-linux subfolder
  if exist "%~dp0start.bat" (
    set "TARGET_DIR=%~dp0"
  ) else (
    set "TARGET_DIR=%~dp0portable-linux"
  )
)
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

echo ========================================================
echo   Portable Linux (Debian 13 + QEMU) Installer
echo   Target: %TARGET_DIR%
echo   No Administrator Privileges Required.
echo ========================================================
echo.

rem Check if active QEMU or SSH process is running before updating
%SystemRoot%\System32\tasklist.exe /fi "imagename eq qemu-system-x86_64w.exe" 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64w" >nul
if not errorlevel 1 (
  echo [ERROR] QEMU VM process is currently running.
  echo Please stop the running VM with 'scripts\04-stop.bat' or close it before running setup.
  pause
  exit /b 1
)

rem Check if already installed in this directory
set "IS_UPDATE=0"
if exist "%TARGET_DIR%\start.bat" (
  set "IS_UPDATE=1"
  echo [WARN] Portable Linux already exists in: %TARGET_DIR%
  set "OVERWRITE=n"
  set /p "OVERWRITE=Do you want to re-download and update files? (y/N): "
  set "OVERWRITE=!OVERWRITE: =!"
  if /i not "!OVERWRITE!"=="y" exit /b 0
)

rem Backup existing user config if updating
if "!IS_UPDATE!"=="1" (
  if exist "%TARGET_DIR%\config\settings.cfg" (
    copy /y "%TARGET_DIR%\config\settings.cfg" "%TEMP%\portable_linux_settings_bak.cfg" >nul 2>&1
  )
)

echo [1/2] Downloading latest portable-linux package from GitHub...
set "ZIP_FILE=%TEMP%\portable-linux_%RANDOM%.zip"
curl.exe -fL -sS -o "%ZIP_FILE%" "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/portable-linux.zip"
if errorlevel 1 (
  echo [ERROR] Failed to download portable-linux.zip from GitHub Releases.
  if exist "%ZIP_FILE%" del /f /q "%ZIP_FILE%" >nul 2>&1
  pause
  exit /b 1
)

if not exist "%ZIP_FILE%" (
  echo [ERROR] Downloaded package file not found.
  pause
  exit /b 1
)

echo [2/2] Extracting package to %TARGET_DIR%...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%" >nul 2>&1
powershell -NoProfile -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%TARGET_DIR%' -Force"
del /f /q "%ZIP_FILE%" >nul 2>&1

rem Restore preserved user config if updating
if "!IS_UPDATE!"=="1" (
  if exist "%TEMP%\portable_linux_settings_bak.cfg" (
    move /y "%TEMP%\portable_linux_settings_bak.cfg" "%TARGET_DIR%\config\settings.cfg" >nul 2>&1
    echo       Restored existing user configuration (settings.cfg).
  )
)

echo.
echo ========================================================
echo   Files Extracted Successfully!
echo   Location: %TARGET_DIR%
echo ========================================================
echo.

rem Offer immediate core components initialization (~600MB: QEMU, SSH, Debian 13)
set "RUN_INIT=y"
set /p "RUN_INIT=Do you want to download core components now (~600MB: QEMU and Debian 13)? [Y/n]: "
set "RUN_INIT=!RUN_INIT: =!"
if /i "!RUN_INIT!"=="n" (
  echo.
  echo [NOTE] Core components (QEMU and Debian 13 base image) will be
  echo        automatically downloaded on first launch via 'start.bat'.
  echo.
  echo To start later:
  echo   Double-click '%TARGET_DIR%\start.bat'
  echo.
  pause
  exit /b 0
)

echo.
echo ========================================================
echo   Starting initialization [init.bat] ...
echo ========================================================
echo.
call "%TARGET_DIR%\init.bat"
if errorlevel 1 (
  echo [ERROR] Initialization failed.
  pause
  exit /b 1
)

echo.
echo ========================================================
echo   Setup Complete!
echo   Double-click '%TARGET_DIR%\start.bat' to launch!
echo ========================================================
echo.
pause
