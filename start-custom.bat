@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux - Custom OS
call "%~dp0scripts\00-common.bat"

set "TARGET_DISK=%ROOT%\disk\custom.qcow2"

if not exist "%TARGET_DISK%" (
  echo [ERROR] Virtual disk '%TARGET_DISK%' not found.
  echo Please run 'boot-iso.bat' first and select [2] to install an OS from ISO.
  pause
  exit /b 1
)

echo ========================================================
echo   Portable Linux - Custom Installed OS
echo   Disk: %TARGET_DISK%
echo ========================================================
echo.
echo Select Display Mode:
echo   [1] GUI Window (Desktop environment, graphical apps)
echo   [2] Headless / Background (Console / SSH on port %SSH_PORT%)
echo.
set /p "DMODE=Enter choice (1-2) [default: 1]: "
if "%DMODE%"=="" set "DMODE=1"

if "%DMODE%"=="1" (
  set "QEMU_GUI=%ROOT%\qemu\qemu-system-x86_64.exe"
  echo [INFO] Launching with GUI Window...
  start "" "%QEMU_GUI%" ^
    -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
    -drive file="%TARGET_DISK%",if=virtio,cache=unsafe ^
    -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
    -device virtio-rng-pci -vga virtio -display sdl
  exit /b 0
)

if "%DMODE%"=="2" (
  echo [INFO] Launching in background...
  start "" "%QEMU%" ^
    -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
    -drive file="%TARGET_DISK%",if=virtio,cache=unsafe ^
    -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
    -device virtio-rng-pci -vga none -display none
  echo [OK] Started. If SSH server is installed in the guest, connect using:
  echo      ssh -p %SSH_PORT% username@127.0.0.1
  pause
  exit /b 0
)
