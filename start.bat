@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Debian 13 (Portable)
call "%~dp0scripts\00-common.bat"

rem 0. Check core dependencies (QEMU, Debian base image)
if not exist "%ROOT%\qemu\qemu-system-x86_64.exe" goto RUN_AUTO_INIT
if not exist "%ROOT%\%BASE_IMAGE%" goto RUN_AUTO_INIT
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

rem 1. Check if QEMU is already running
%SystemRoot%\System32\tasklist.exe 2>nul | %SystemRoot%\System32\findstr.exe /i "qemu-system-x86_64" >nul
if not errorlevel 1 goto QEMU_ALREADY_RUNNING

set "CIDATA_OPT="
if exist "%ROOT%\config\cidata.iso" set CIDATA_OPT=-cdrom "%ROOT%\config\cidata.iso"

set "PAYLOAD_OPT="
if exist "%ROOT%\payload" set "PAYLOAD_OPT=-drive file=fat:rw:%ROOT%\payload,if=virtio,format=raw"

set "QEMU_CONSOLE=%ROOT%\qemu\qemu-system-x86_64.exe"

cls
echo ========================================================
echo   Debian GNU/Linux 13 (Portable Console - Offline Dev)
echo   Memory: %MEM%MB  vCPU: %SMP% cores  Cache: unsafe (Fast I/O)
echo   Tools: gcc, g++, Go, Python3, Helix (hx), Neovim (nvim)
echo   Type 'exit' or 'sudo poweroff' to shut down.
echo   Emergency exit: Press Ctrl+A, then press X.
echo ========================================================
echo.

rem Launch QEMU with direct terminal binding (mon:stdio) and no localhost/network port requirements
"%QEMU_CONSOLE%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -drive file="%ROOT%\%DISK_IMAGE%",if=virtio,cache=unsafe %CIDATA_OPT% %PAYLOAD_OPT% ^
  -netdev user,id=n0,ipv6=off,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -display none -serial mon:stdio

echo.
echo [OK] VM stopped safely. Goodbye!
exit /b 0

:QEMU_ALREADY_RUNNING
echo [WARN] A QEMU process is already running.
echo To stop it, run 'scripts\04-stop.bat' or close the other console window.
pause
exit /b 1
