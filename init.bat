@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux - Initial Setup
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

echo ========================================================
echo   Portable Linux (Debian 13 + QEMU) Initial Setup
echo   No Administrator Privileges Required.
echo ========================================================
echo.

rem 1. Create required directories
for %%D in (bin qemu images disk ssh config\cidata tools) do (
  if not exist "%ROOT%\%%D" mkdir "%ROOT%\%%D"
)

rem 2. Download 7-Zip standalone extractors for safe unpacking
set "TOOLS=%ROOT%\tools"
if not exist "%TOOLS%\7zr.exe" (
  echo [1/6] Downloading 7-Zip extraction tools...
  curl.exe -L -s -o "%TOOLS%\7zr.exe" "https://www.7-zip.org/a/7zr.exe"
  curl.exe -L -s -o "%TOOLS%\7z-extra.7z" "https://github.com/ip7z/7zip/releases/download/26.04/7z2604-extra.7z"
  "%TOOLS%\7zr.exe" x "%TOOLS%\7z-extra.7z" -o"%TOOLS%\7z-extra" -y >nul 2>&1
  del /f /q "%TOOLS%\7z-extra.7z" >nul 2>&1
)

set "SEVENZ=%TOOLS%\7z-extra\x64\7za.exe"
if not exist "%SEVENZ%" set "SEVENZ=%TOOLS%\7z-extra\7za.exe"

rem 3. Download and extract Win32-OpenSSH
if not exist "%ROOT%\bin\ssh.exe" (
  echo [2/6] Downloading portable OpenSSH binaries...
  curl.exe -L -s -o "%TOOLS%\openssh.zip" "https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64.zip"
  powershell -NoProfile -Command "Expand-Archive -Path '%TOOLS%\openssh.zip' -DestinationPath '%TOOLS%\openssh_tmp' -Force"
  move /y "%TOOLS%\openssh_tmp\OpenSSH-Win64\*" "%ROOT%\bin\" >nul
  rmdir /s /q "%TOOLS%\openssh_tmp" >nul 2>&1
  del /f /q "%TOOLS%\openssh.zip" >nul 2>&1
  echo       OpenSSH extracted to bin\
) else (
  echo [2/6] Portable OpenSSH already present in bin\
)

rem 4. Download and extract QEMU (non-install, registry-free)
if not exist "%ROOT%\qemu\qemu-system-x86_64w.exe" (
  echo [3/6] Downloading QEMU Windows package...
  curl.exe -L -o "%TOOLS%\qemu-setup.exe" "https://qemu.weilnetz.de/w64/qemu-w64-setup-20260811.exe"
  echo       Extracting QEMU binaries without running installer...
  
  rem Download 7z installer to extract NSIS with full 7z.dll
  curl.exe -L -s -o "%TOOLS%\7z-setup.exe" "https://github.com/ip7z/7zip/releases/download/26.04/7z2604-x64.exe"
  "%SEVENZ%" x "%TOOLS%\7z-setup.exe" -o"%TOOLS%\7z-full" -y >nul 2>&1
  "%TOOLS%\7z-full\7z.exe" x "%TOOLS%\qemu-setup.exe" -o"%ROOT%\qemu" -y >nul 2>&1
  
  del /f /q "%TOOLS%\qemu-setup.exe" >nul 2>&1
  del /f /q "%TOOLS%\7z-setup.exe" >nul 2>&1
  rmdir /s /q "%TOOLS%\7z-full" >nul 2>&1
  echo       QEMU extracted to qemu\
) else (
  echo [3/6] QEMU already present in qemu\
)

rem 5. Download Debian 13 Cloud Image (Trixie)
set "BASE_IMG=%ROOT%\images\debian-13-genericcloud-amd64-daily.qcow2"
if not exist "%BASE_IMG%" (
  echo [4/6] Downloading Debian 13 cloud image - approx 350MB...
  curl.exe -L -o "%BASE_IMG%" "https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-genericcloud-amd64-daily.qcow2"
) else (
  echo [4/6] Debian base cloud image already present.
)

rem 6. Generate SSH keypair and lock permissions
if not exist "%ROOT%\ssh\id_ed25519" (
  echo [5/6] Generating portable Ed25519 keypair...
  "%ROOT%\bin\ssh-keygen.exe" -t ed25519 -N "" -f "%ROOT%\ssh\id_ed25519" -q
  icacls.exe "%ROOT%\ssh\id_ed25519" /inheritance:r >nul
  icacls.exe "%ROOT%\ssh\id_ed25519" /grant:r "%USERNAME%:(R,W)" >nul
) else (
  echo [5/6] SSH keypair already exists.
)

rem Build cloud-init ISO with user's generated public key (dynamic, non-hardcoded)
echo       Generating cloud-init configuration disk (cidata.iso)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\make-cidata.ps1" -Root "%ROOT%" >nul 2>&1

rem 7. Create differential disk
set "DIFF_IMG=%ROOT%\disk\debian.qcow2"
if not exist "%DIFF_IMG%" (
  echo [6/6] Creating 20GB differential virtual disk...
  pushd "%ROOT%\disk"
  "%ROOT%\qemu\qemu-img.exe" create -f qcow2 -b "..\images\debian-13-genericcloud-amd64-daily.qcow2" -F qcow2 "debian.qcow2" 20G >nul
  popd
) else (
  echo [6/6] Differential disk already exists.
)

rem Cleanup temporary tools directory
rmdir /s /q "%TOOLS%" >nul 2>&1

echo.
echo ========================================================
echo   Setup Complete!
echo   Run start.bat to launch your portable Debian 13 VM.
echo ========================================================
echo.
pause
