@echo off
call "%~dp000-common.bat"
if "%~1"=="" (
  %SSH_CMD% -t %SSH_OPTS% debian@127.0.0.1
) else (
  %SSH_CMD% %SSH_OPTS% debian@127.0.0.1 %*
)
