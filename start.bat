@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Debian 13 (Portable)
call "%~dp0scripts\00-common.bat"

rem 0. Check core dependencies (QEMU, SSH, Debian base image, SSH key)
if not exist "%QEMU%" goto RUN_AUTO_INIT
if not exist "%ROOT%\bin\ssh.exe" goto RUN_AUTO_INIT
if not exist "%ROOT%\%BASE_IMAGE%" goto RUN_AUTO_INIT
if not exist "%ROOT%\ssh\id_ed25519" goto RUN_AUTO_INIT
goto CHECK_DISK

:RUN_AUTO_INIT
echo ========================================================
echo   First-time setup detected: Core components missing.
echo   Running automatic initialization [init.bat] ...
echo ========================================================
echo.
call "%ROOT%\init.bat"
if errorlevel 1 (
  echo [ERROR] Initialization failed.
  pause
  exit /b 1
)

:CHECK_DISK
if not exist "%ROOT%\%DISK_IMAGE%" (
  echo [INFO] First-time setup: Creating virtual disk...
  call "%~dp0scripts\01-make-disk.bat"
)

rem 1. Check if QEMU is already running, if not launch with unsafe cache and tb-size=1024
%SystemRoot%\System32\tasklist.exe /fi "imagename eq qemu-system-x86_64w.exe" 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64w" >nul
if not errorlevel 1 goto QEMU_ALREADY_RUNNING

set "CIDATA_OPT="
if exist "%ROOT%\config\cidata.iso" set CIDATA_OPT=-cdrom "%ROOT%\config\cidata.iso"

start "" "%QEMU%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -drive file="%ROOT%\%DISK_IMAGE%",if=virtio,cache=unsafe %CIDATA_OPT% ^
  -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -vga virtio -display none -serial file:"%ROOT%\boot.log"

:QEMU_ALREADY_RUNNING

rem 2. Progress loop
set /a SEC=0
<nul set /p="[INFO] Launching Debian... "

:WAIT_SSH
rem Check if QEMU process died unexpectedly (fail fast instead of hanging 45s)
%SystemRoot%\System32\tasklist.exe /fi "imagename eq qemu-system-x86_64w.exe" 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64w" >nul
if errorlevel 1 goto ERR_QEMU_DIED

%SSH_CMD% %SSH_OPTS% -o BatchMode=yes -o ConnectTimeout=1 -o LogLevel=QUIET debian@127.0.0.1 "exit" 2>nul
if not errorlevel 1 goto SSH_READY

%SystemRoot%\System32\timeout.exe /t 1 /nobreak >nul 2>&1
set /a SEC+=1
<nul set /p="!SEC!s "

if !SEC! geq 45 goto ERR_TIMEOUT
goto WAIT_SSH

:ERR_QEMU_DIED
echo.
echo [ERROR] QEMU process terminated unexpectedly.
if exist "%ROOT%\boot.log" (
  echo --- Last lines of boot.log ---
  powershell -NoProfile -Command "Get-Content -Path '%ROOT%\boot.log' -Tail 10 -ErrorAction SilentlyContinue"
  echo ------------------------------
)
pause
exit /b 1

:ERR_TIMEOUT
echo.
echo [ERROR] Boot timed out after 45 seconds.
pause
exit /b 1

:SSH_READY
echo [Ready]

rem 3. Optimize Guest I/O, DNS, APT, Git, and system-wide terminal paste automatically
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes debian@127.0.0.1 "if [ ! -f /etc/.portable_speedup_applied ]; then sudo sh -c 'mkdir -p /etc/dpkg/dpkg.cfg.d /etc/apt/apt.conf.d /etc/apt/sources.list.d /etc/cloud && touch /etc/cloud/cloud-init.disabled && echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/force-unsafe-io && chattr -i /etc/resolv.conf 2>/dev/null; printf \"nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions timeout:1 attempts:2 single-request\n\" > /etc/resolv.conf && chattr +i /etc/resolv.conf 2>/dev/null; printf \"Acquire::Languages \\\"none\\\";\nAPT::Acquire::Translation \\\"none\\\";\nAcquire::PDiffs \\\"false\\\";\nAcquire::ForceIPv4 \\\"true\\\";\n\" > /etc/apt/apt.conf.d/99speedup; printf \"Types: deb\nURIs: http://ftp.jaist.ac.jp/debian\nSuites: trixie trixie-updates trixie-backports\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\nTypes: deb\nURIs: http://security.debian.org/debian-security\nSuites: trixie-security\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\" > /etc/apt/sources.list.d/debian.sources; printf \"\nset enable-bracketed-paste on\n\" >> /etc/inputrc; printf \"\nunbind ^J main\nset softwrap\nset tabstospaces\nset tabsize 4\n\" >> /etc/nanorc; touch /etc/.portable_speedup_applied'; command -v git >/dev/null 2>&1 && { git config --global pack.threads 4; git config --global core.preloadindex true; }; fi" 2>nul

cls
echo ========================================================
echo   Debian GNU/Linux 13 (Portable / QEMU - High Performance)
echo   Memory: %MEM%MB  vCPU: %SMP% cores  Cache: unsafe (Fast I/O)
echo   Type 'exit' to shut down VM and close window.
echo ========================================================
echo.

rem 4. Interactive SSH session
%SSH_CMD% -t %SSH_OPTS% debian@127.0.0.1

rem 5. Clean automatic shutdown
echo.
echo ========================================================
echo [INFO] Shell closed. Shutting down Debian safely...
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes -o ConnectTimeout=5 debian@127.0.0.1 "sudo poweroff" 2>nul

set /a STOP_SEC=0
<nul set /p="[INFO] Finalizing VM process... "

:WAIT_STOP
%SystemRoot%\System32\tasklist.exe /fi "imagename eq qemu-system-x86_64w.exe" 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64w" >nul
if errorlevel 1 goto STOPPED

%SystemRoot%\System32\timeout.exe /t 1 /nobreak >nul 2>&1
set /a STOP_SEC+=1
<nul set /p="!STOP_SEC!s "

if !STOP_SEC! geq 15 (
  %SystemRoot%\System32\taskkill.exe /f /im qemu-system-x86_64w.exe >nul 2>&1
  goto STOPPED
)
goto WAIT_STOP

:STOPPED
echo [Done]
echo [OK] Goodbye!
%SystemRoot%\System32\timeout.exe /t 1 /nobreak >nul 2>&1
