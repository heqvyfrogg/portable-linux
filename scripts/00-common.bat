@echo off
set "ROOT=%~dp0.."
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%ROOT%\config\settings.cfg") do set "%%A=%%B"
set "QEMU=%ROOT%\qemu\qemu-system-x86_64w.exe"
set "QIMG=%ROOT%\qemu\qemu-img.exe"
set "KEY=%ROOT%\ssh\id_ed25519"
set "KNOWN_HOSTS=%ROOT%\ssh\known_hosts"
set "SSH_CMD=%ROOT%\bin\ssh.exe"
set "SSH_OPTS=-F none -i "%KEY%" -p %SSH_PORT% -o StrictHostKeyChecking=no -o UserKnownHostsFile="%KNOWN_HOSTS%" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey"
