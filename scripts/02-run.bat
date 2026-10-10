@echo off
call "%~dp000-common.bat"
if not exist "%ROOT%\%DISK_IMAGE%" (
  echo [INFO] Disk not found. Running 01-make-disk.bat...
  call "%~dp001-make-disk.bat"
)
echo [INFO] Starting Debian in background (SSH port: %SSH_PORT%)...
start "" "%QEMU%" ^
  -accel %ACCEL% -cpu %CPU% -m %MEM% -smp %SMP% ^
  -drive file="%ROOT%\%DISK_IMAGE%",if=virtio,cache=unsafe ^
  -netdev user,id=n0,hostfwd=tcp::%SSH_PORT%-:22,dns=1.1.1.1 -device virtio-net-pci,netdev=n0 ^
  -device virtio-rng-pci -vga none -display none -serial file:"%ROOT%\boot.log"
echo [OK] Debian launched. Ready in ~10 seconds.
