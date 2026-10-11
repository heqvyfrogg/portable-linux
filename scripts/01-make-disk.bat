@echo off
call "%~dp000-common.bat"
if exist "%ROOT%\%DISK_IMAGE%" (
  echo [INFO] Disk image already exists: %DISK_IMAGE%
  echo Delete it manually if you want to reset the environment.
  exit /b 0
)
if not exist "%ROOT%\%BASE_IMAGE%" (
  echo [ERROR] Base cloud image not found: %ROOT%\%BASE_IMAGE%
  echo Please run 'init.bat' first to download the base image.
  exit /b 1
)
if not exist "%ROOT%\disk" mkdir "%ROOT%\disk"
echo [INFO] Creating differential disk (20GB)...
pushd "%ROOT%\disk"
"%QIMG%" create -f qcow2 -b "..\images\debian-13-genericcloud-amd64-daily.qcow2" -F qcow2 "debian.qcow2" 20G
popd
echo [OK] Done.
