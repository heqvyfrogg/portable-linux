@echo off
rem Normalize ROOT to absolute canonical path (handles spaces safely)
for %%I in ("%~dp0..") do set "ROOT=%%~fI"

rem Load settings
if exist "%ROOT%\config\settings.cfg" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%ROOT%\config\settings.cfg") do set "%%A=%%B"
)

set "QEMU=%ROOT%\qemu\qemu-system-x86_64w.exe"
set "QIMG=%ROOT%\qemu\qemu-img.exe"
set "KEY=%ROOT%\ssh\id_ed25519"
set "KNOWN_HOSTS=%ROOT%\ssh\known_hosts"
set "SSH_CMD=%ROOT%\bin\ssh.exe"
set "SSH_OPTS=-F none -i "%KEY%" -p %SSH_PORT% -o StrictHostKeyChecking=no -o UserKnownHostsFile="%KNOWN_HOSTS%" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey"
