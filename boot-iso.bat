@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux - Boot from ISO
call "%~dp0scripts\00-common.bat"

echo ========================================================
echo   Portable Linux - Boot from ISO
echo   Ubuntu, Arch, Alpine, Kali, Fedora, etc.
echo ========================================================
echo.

rem 1. Determine ISO file
set "ISO_PATH=%~1"
if not "%ISO_PATH%"=="" (
  if exist "%ISO_PATH%" goto ISO_SELECTED
)

rem Check current directory, iso\, and images\ for any .iso
for %%F in ("%ROOT%\*.iso") do (
  set "ISO_PATH=%%F"
  goto ISO_FOUND_IN_DIR
)
for %%F in ("%ROOT%\iso\*.iso") do (
  set "ISO_PATH=%%F"
  goto ISO_FOUND_IN_DIR
)
for %%F in ("%ROOT%\images\*.iso") do (
  set "ISO_PATH=%%F"
  goto ISO_FOUND_IN_DIR
)

goto CHOOSE_ISO_GUI

:ISO_FOUND_IN_DIR
echo [INFO] Found ISO in folder: !ISO_PATH!
set /p "USE_FOUND=Use this ISO? [Y/n]: "
if /i not "!USE_FOUND!"=="n" goto ISO_SELECTED

:CHOOSE_ISO_GUI
echo [INFO] Opening file selector to choose ISO...
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.OpenFileDialog; $f.Filter = 'ISO Files (*.iso)|*.iso|All Files (*.*)|*.*'; $f.Title = 'Select Linux ISO File'; if($f.ShowDialog() -eq 'OK'){ $f.FileName }"`) do set "ISO_PATH=%%I"

if "%ISO_PATH%"=="" (
  echo [ERROR] No ISO file selected.
  pause
  exit /b 1
)

:ISO_SELECTED
echo.
echo [SELECTED ISO] %ISO_PATH%
echo.
echo Select Boot Mode:
echo   [1] Live Boot (Test without disk / Temporary)
echo   [2] Install to a new virtual disk (20GB qcow2)
echo   [3] Attach ISO to existing disk (disk\custom.qcow2)
echo.
set /p "MODE=Enter choice (1-3) [default: 1]: "
if "%MODE%"=="" set "MODE=1"

set "QEMU_GUI=%ROOT%\qemu\qemu-system-x86_64.exe"

if "%MODE%"=="1" goto MODE_LIVE
if "%MODE%"=="2" goto MODE_INSTALL
if "%MODE%"=="3" goto MODE_ATTACH
goto MODE_LIVE

:MODE_LIVE
echo.
echo [INFO] Starting Live Boot. A QEMU window will open...
start "" "%QEMU_GUI%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -cdrom "%ISO_PATH%" -boot d ^
  -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_INSTALL
set "TARGET_DISK=%ROOT%\disk\custom.qcow2"
if not exist "!TARGET_DISK!" goto CREATE_DISK

echo [WARN] disk\custom.qcow2 already exists.
set /p "OVERWRITE=Overwrite and re-create disk? [y/N]: "
if /i "!OVERWRITE!"=="y" (
  del /f /q "!TARGET_DISK!"
  goto CREATE_DISK
)
set "TARGET_DISK=%ROOT%\disk\custom_%RANDOM%.qcow2"

:CREATE_DISK
echo [INFO] Creating 20GB virtual disk: !TARGET_DISK! ...
"%QIMG%" create -f qcow2 "!TARGET_DISK!" 20G

echo.
echo [INFO] Starting Installation. A QEMU window will open...
echo [TIP] Once installation is finished, use 'start-custom.bat' to boot from disk.
start "" "%QEMU_GUI%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -drive file="!TARGET_DISK!",if=virtio,cache=unsafe ^
  -cdrom "%ISO_PATH%" -boot d ^
  -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_ATTACH
set "TARGET_DISK=%ROOT%\disk\custom.qcow2"
if not exist "!TARGET_DISK!" (
  echo [ERROR] disk\custom.qcow2 not found. Choose Mode 2 first.
  pause
  exit /b 1
)
start "" "%QEMU_GUI%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -drive file="!TARGET_DISK!",if=virtio,cache=unsafe ^
  -cdrom "%ISO_PATH%" ^
  -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -device usb-tablet -vga virtio -display sdl
exit /b 0

