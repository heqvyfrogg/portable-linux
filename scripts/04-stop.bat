@echo off
call "%~dp000-common.bat"
echo [INFO] Sending safe poweroff request to Debian...
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes -o ConnectTimeout=5 debian@127.0.0.1 "sudo poweroff" 2>nul
echo [OK] Shutdown command sent.

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
echo [OK] VM stopped safely.
