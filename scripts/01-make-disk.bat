@echo off
call "%~dp000-common.bat"
if exist "%ROOT%\%DISK_IMAGE%" (
  echo [INFO] Disk image already exists: %DISK_IMAGE%
  echo Delete it manually if you want to reset the environment.
  exit /b 0
)
echo [INFO] Creating differential disk (20GB)...
"%QIMG%" create -f qcow2 -b "%ROOT%\%BASE_IMAGE%" -F qcow2 "%ROOT%\%DISK_IMAGE%" 20G
echo [OK] Done.
