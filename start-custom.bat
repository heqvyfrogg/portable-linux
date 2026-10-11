@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux - Custom OS
call "%~dp0scripts\00-common.bat"

rem Check core dependencies (QEMU)
if not exist "%ROOT%\qemu\qemu-system-x86_64.exe" goto RUN_AUTO_INIT
goto CORE_READY

:RUN_AUTO_INIT
echo ========================================================
echo   First-time setup detected: QEMU components missing.
echo   Running automatic initialization [init.bat] ...
echo ========================================================
echo.
call "%ROOT%\init.bat"
if errorlevel 1 (
  echo [ERROR] Initialization failed.
  pause
  exit /b 1
)

:CORE_READY
set "TARGET_DISK=%ROOT%\disk\custom.qcow2"

if not exist "!TARGET_DISK!" goto ERR_DISK_NOT_FOUND

echo ========================================================
echo   Portable Linux - Custom Installed OS
echo   Disk: !TARGET_DISK!
echo ========================================================
echo.
set "DMODE=%~1"
if not "%DMODE%"=="" goto DMODE_CHOSEN

echo Select Display Mode:
echo   [1] GUI Window (Desktop environment, graphical apps)
echo   [2] Headless / Background (Console / SSH on port %SSH_PORT%)
echo.
set "DMODE=1"
set /p "DMODE=Enter choice (1-2) [default: 1]: "
set "DMODE=!DMODE: =!"

:DMODE_CHOSEN
if "!DMODE!"=="1" goto MODE_GUI
if "!DMODE!"=="2" goto MODE_HEADLESS
goto MODE_GUI

:MODE_GUI
set "QEMU_GUI=%ROOT%\qemu\qemu-system-x86_64.exe"
echo [INFO] Launching with GUI Window...
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_HEADLESS
echo [INFO] Launching in background...
start "" "%QEMU%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga none -display none
echo [OK] Started. If SSH server is installed in the guest, connect using:
echo      ssh -p %SSH_PORT% username@127.0.0.1
echo      To stop the background VM, run 'scripts\04-stop.bat' or close the process.
if "%~1"=="" pause
exit /b 0

:ERR_DISK_NOT_FOUND
echo [ERROR] Virtual disk '!TARGET_DISK!' not found.
echo Please run 'boot-iso.bat' first and select [2] to install an OS from ISO.
if "%~1"=="" pause
exit /b 1
