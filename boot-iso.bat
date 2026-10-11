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
if not "%~2"=="" goto OVERWRITE_DISK
set "OVERWRITE=n"
set /p "OVERWRITE=Overwrite and re-create disk? [y/N]: "
set "OVERWRITE=!OVERWRITE: =!"
if /i "!OVERWRITE!"=="y" goto OVERWRITE_DISK
set "TARGET_DISK=%ROOT%\disk\custom_%RANDOM%.qcow2"
goto CREATE_DISK

:OVERWRITE_DISK
del /f /q "!TARGET_DISK!"
goto CREATE_DISK

:CREATE_DISK
echo [INFO] Creating 20GB virtual disk: !TARGET_DISK! ...
"%ROOT%\qemu\qemu-img.exe" create -f qcow2 "!TARGET_DISK!" 20G

echo.
echo [INFO] Starting Installation. A QEMU window will open...
echo [TIP] インストール時の重要ポイント:
echo       1. ブートメニューでは 'Install' (テキストモード) を選ぶとキーボードだけで快適に操作できます
echo       2. ソフトウェアエミュレーション(TCG)のため、ネットワーク設定等で2〜3分停止して見える場合がありますが待機してください
echo       3. ディスク書き込みの確認画面 (Write changes to disks) では必ず [Yes] を選んでください
echo       4. インストール完了後は 'start-custom.bat' でディスクから起動できます
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -cdrom "%ISO_PATH%" -boot d -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:MODE_ATTACH
set "TARGET_DISK=%ROOT%\disk\custom.qcow2"
if not exist "!TARGET_DISK!" goto ERR_NO_DISK

echo.
echo [INFO] Starting with existing disk and attached ISO...
start "" "%QEMU_GUI%" -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% -drive file="!TARGET_DISK!",if=virtio,cache=unsafe -cdrom "%ISO_PATH%" -boot d -netdev user,id=n0,ipv6=off,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -device qemu-xhci -device usb-tablet -vga virtio -display sdl
exit /b 0

:ERR_NO_DISK
echo.
echo [ERROR] disk\custom.qcow2 not found. Choose Mode 2 first.
pause
exit /b 1
