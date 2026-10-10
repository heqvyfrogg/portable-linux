@echo off
call "%~dp000-common.bat"
echo [INFO] Sending safe poweroff request to Debian...
%SSH_CMD% %SSH_OPTS% -o BatchMode=yes -o ConnectTimeout=5 debian@127.0.0.1 "sudo poweroff"
echo [OK] Shutdown command sent.
