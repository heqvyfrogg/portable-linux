@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Debian 12 (Portable)
call "%~dp0scripts\00-common.bat"

if not exist "%ROOT%\%DISK_IMAGE%" (
  echo [INFO] First-time setup: Creating virtual disk...
  call "%~dp0scripts\01-make-disk.bat"
)

rem 1. Check if QEMU is already running, if not launch with unsafe cache and tb-size=1024
%SystemRoot%\System32\tasklist.exe /fi "imagename eq qemu-system-x86_64w.exe" 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64w" >nul
if errorlevel 1 (
  start "" "%QEMU%" ^
    -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
    -drive file="%ROOT%\%DISK_IMAGE%",if=virtio,cache=unsafe ^
    -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
    -device virtio-rng-pci -vga none -display none -serial file:"%ROOT%\boot.log"
)

rem 2. Progress loop
set /a SEC=0
<nul set /p="[INFO] Launching Debian... "

:WAIT_SSH
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes -o ConnectTimeout=1 -o LogLevel=QUIET debian@127.0.0.1 "exit" 2>nul
if not errorlevel 1 goto SSH_READY

%SystemRoot%\System32\ping.exe 127.0.0.1 -n 2 >nul
set /a SEC+=1
<nul set /p="!SEC!s "

if !SEC! geq 45 (
  echo.
  echo [ERROR] Boot timed out after 45 seconds.
  pause
  exit /b 1
)
goto WAIT_SSH

:SSH_READY
echo [Ready]

rem 3. Optimize Guest I/O, DNS, APT, and Git automatically
rem - force-unsafe-io: skips per-file fsync, accelerating apt/dpkg
rem - resolv.conf: locks fast IPv4 DNS (1.1.1.1 / 8.8.8.8) with 1s timeout
rem - 99speedup: skips translation downloads and forces IPv4
rem - debian.sources: uses high-speed Japan mirror (JAIST) without deb-src
rem - git config: enables multithreaded pack processing and preloading
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes debian@127.0.0.1 "sudo sh -c 'mkdir -p /etc/dpkg/dpkg.cfg.d /etc/apt/apt.conf.d /etc/apt/sources.list.d && echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/force-unsafe-io && chattr -i /etc/resolv.conf 2>/dev/null; printf \"nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions timeout:1 attempts:2 single-request\n\" > /etc/resolv.conf && chattr +i /etc/resolv.conf 2>/dev/null; printf \"Acquire::Languages \\\"none\\\";\nAPT::Acquire::Translation \\\"none\\\";\nAcquire::PDiffs \\\"false\\\";\nAcquire::ForceIPv4 \\\"true\\\";\n\" > /etc/apt/apt.conf.d/99speedup; if [ ! -f /etc/apt/sources.list.d/.speedup_applied ]; then printf \"Types: deb\nURIs: http://ftp.jaist.ac.jp/debian\nSuites: bookworm bookworm-updates bookworm-backports\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\nTypes: deb\nURIs: http://security.debian.org/debian-security\nSuites: bookworm-security\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\" > /etc/apt/sources.list.d/debian.sources && touch /etc/apt/sources.list.d/.speedup_applied; fi'; git config --global pack.threads 4; git config --global core.preloadindex true" 2>nul

cls
echo ========================================================
echo   Debian GNU/Linux 12 (Portable / QEMU - High Performance)
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

%SystemRoot%\System32\ping.exe 127.0.0.1 -n 2 >nul
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
%SystemRoot%\System32\ping.exe 127.0.0.1 -n 2 >nul
