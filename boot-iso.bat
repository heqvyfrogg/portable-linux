@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Portable Linux - Boot from ISO
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
echo ========================================================
echo   Portable Linux - Boot from ISO
echo   Ubuntu, Arch, Alpine, Kali, Fedora, etc.
echo ========================================================
echo.

if not exist "%ROOT%\iso" mkdir "%ROOT%\iso"
if not exist "%ROOT%\disk" mkdir "%ROOT%\disk"

rem 1. Determine ISO file: from argument (drag & drop) or dedicated iso\ folder only
set "ISO_PATH=%~1"
if not "%ISO_PATH%"=="" (
  if exist "%ISO_PATH%" goto ISO_SELECTED
)

rem Check only the dedicated iso\ folder
for %%F in ("%ROOT%\iso\*.iso") do (
  set "ISO_PATH=%%F"
  goto ISO_FOUND_IN_DIR
)

goto CHOOSE_ISO_GUI

:ISO_FOUND_IN_DIR
echo [INFO] Found ISO in folder: !ISO_PATH!
if not "%~2"=="" goto ISO_SELECTED
set "USE_FOUND=y"
set /p "USE_FOUND=Use this ISO? [Y/n]: "
set "USE_FOUND=!USE_FOUND: =!"
if /i "!USE_FOUND!"=="n" goto CHOOSE_ISO_GUI
goto ISO_SELECTED

:CHOOSE_ISO_GUI
echo [INFO] Opening file selector to choose ISO...
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.OpenFileDialog; $f.Filter = 'ISO Files (*.iso)|*.iso|All Files (*.*)|*.*'; $f.Title = 'Select Linux ISO File'; $top = New-Object System.Windows.Forms.Form -Property @{TopMost=$true}; if($f.ShowDialog($top) -eq 'OK'){ $f.FileName }"` ) do set "ISO_PATH=%%I"

if "%ISO_PATH%"=="" (
  echo [ERROR] No ISO file selected.
  pause
  exit /b 1
)

:ISO_SELECTED
echo.
echo [SELECTED ISO] %ISO_PATH%
echo.
set "MODE=%~2"
if not "%MODE%"=="" goto MODE_CHOSEN

echo Select Boot Mode:
echo   [1] Live Boot (Test without disk / Temporary)
echo   [2] Install to a new virtual disk (20GB qcow2)
echo   [3] Attach ISO to existing disk (disk\custom.qcow2)
echo.
set "MODE=1"
set /p "MODE=Enter choice (1-3) [default: 1]: "
set "MODE=!MODE: =!"

:MODE_CHOSEN
set "QEMU_GUI=%ROOT%\qemu\qemu-system-x86_64.exe"

if "!MODE!"=="1" goto MODE_LIVE
if "!MODE!"=="2" goto MODE_INSTALL
if "!MODE!"=="3" goto MODE_ATTACH
goto MODE_LIVE

:MODE_LIVE
echo.
echo [INFO] Starting Live Boot. A QEMU window will open...
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -cdrom "%ISO_PATH%" -boot d -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_INSTALL
set "TARGET_DISK=%ROOT%\disk\custom.qcow2"
if not exist "!TARGET_DISK!" goto CREATE_DISK

echo [WARN] disk\custom.qcow2 already exists.
if not "%~2"=="" goto BACKUP_AND_CREATE
set "OVERWRITE=n"
set /p "OVERWRITE=Overwrite and re-create disk? (y: Overwrite / b: Backup existing / N: Cancel): "
set "OVERWRITE=!OVERWRITE: =!"
if /i "!OVERWRITE!"=="y" goto OVERWRITE_DISK
if /i "!OVERWRITE!"=="b" goto BACKUP_AND_CREATE
echo [INFO] Installation cancelled.
exit /b 0

:OVERWRITE_DISK
del /f /q "!TARGET_DISK!"
goto CREATE_DISK

:BACKUP_AND_CREATE
set "BACKUP_DISK=%ROOT%\disk\custom_%RANDOM%.qcow2"
echo [INFO] Moving existing disk to: !BACKUP_DISK!
move /y "!TARGET_DISK!" "!BACKUP_DISK!" >nul
goto CREATE_DISK

:CREATE_DISK
echo [INFO] Creating 20GB virtual disk: !TARGET_DISK! ...
"%ROOT%\qemu\qemu-img.exe" create -f qcow2 "!TARGET_DISK!" 20G

echo.
echo [INFO] Starting Installation. A QEMU window will open...
echo [TIP] Key points during installation:
echo       1. Choose 'Install' (text mode) in boot menu for smooth keyboard-only operation.
echo       2. Under software emulation (TCG), network configuration may take 2-3 minutes.
echo       3. Always choose [Yes] on 'Write changes to disks' screen.
echo       4. Once installed, launch your OS anytime via 'start-custom.bat'.
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -cdrom "%ISO_PATH%" -boot d -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_ATTACH
set /a DISK_COUNT=0
for %%F in ("%ROOT%\disk\custom*.qcow2") do (
  set /a DISK_COUNT+=1
  set "DISK_!DISK_COUNT!=%%F"
  set "DISK_NAME_!DISK_COUNT!=%%~nxF"
)

if !DISK_COUNT! equ 0 goto ERR_NO_DISK

if !DISK_COUNT! equ 1 (
  set "TARGET_DISK=!DISK_1!"
  goto ATTACH_READY
)

echo ========================================================
echo   Select Virtual Disk to Attach ISO
echo ========================================================
echo.
for /l %%I in (1,1,!DISK_COUNT!) do (
  echo   [%%I] !DISK_NAME_%%I!
)
echo.
set "CHOICE=1"
set /p "CHOICE=Select virtual disk (1-!DISK_COUNT!) [default: 1]: "
set "CHOICE=!CHOICE: =!"
if not defined DISK_%CHOICE% (
  set "TARGET_DISK=!DISK_1!"
) else (
  set "TARGET_DISK=!DISK_%CHOICE%!"
)

:ATTACH_READY
echo.
echo [INFO] Starting with disk '!TARGET_DISK!' and attached ISO...
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -cdrom "%ISO_PATH%" -boot d -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:ERR_NO_DISK
echo.
echo [ERROR] No custom virtual disk (disk\custom*.qcow2) found. Choose Mode 2 first.
pause
exit /b 1
