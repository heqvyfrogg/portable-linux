param(
    [string]$Root = ""
)

if ($Root -eq "") {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$cidataDir = "$Root\config\cidata"
$isoPath = "$Root\config\cidata.iso"
$pubKeyFile = "$Root\ssh\id_ed25519.pub"
$csPath = "$Root\scripts\StreamSaver.cs"

$userPath = "$cidataDir\user-data"
$metaPath = "$cidataDir\meta-data"

$pubKey = ""
if (Test-Path $pubKeyFile) {
    $pubKey = (Get-Content $pubKeyFile -Raw).Trim()
}

if (-not (Test-Path $cidataDir)) {
    New-Item -ItemType Directory -Path $cidataDir -Force | Out-Null
}

# 1. Dynamically generate user-data with serial auto-login and workspace auto-mount
$userDataLines = @(
    "#cloud-config"
    "users:"
    "  - name: debian"
    "    gecos: Debian Portable User"
    "    sudo: ALL=(ALL) NOPASSWD:ALL"
    "    lock_passwd: false"
    "    plain_text_passwd: debian"
    "    shell: /bin/bash"
    "    ssh_authorized_keys:"
    "      - $pubKey"
    ""
    "ssh_pwauth: true"
    "chpasswd:"
    "  expire: false"
    "write_files:"
    "  - path: /etc/systemd/system/serial-getty@.service.d/override.conf"
    "    content: |"
    "      [Service]"
    "      ExecStart="
    "      ExecStart=-/sbin/agetty -a debian --noclear %I 115200,38400,9600 linux"
    "  - path: /etc/inputrc.d/portable.inputrc"
    "    content: |"
    "      set enable-bracketed-paste on"
    "  - path: /etc/nanorc.d/portable.nanorc"
    "    content: |"
    "      unbind ^J main"
    "      set softwrap"
    "      set tabstospaces"
    "      set tabsize 4"
    "  - path: /etc/dpkg/dpkg.cfg.d/force-unsafe-io"
    "    content: |"
    "      force-unsafe-io"
    "  - path: /etc/apt/apt.conf.d/99speedup"
    "    content: |"
    "      Acquire::Languages `"none`";"
    "      Acquire::PDiffs `"false`";"
    "      Acquire::ForceIPv4 `"true`";"
    "  - path: /etc/apt/sources.list.d/debian.sources"
    "    content: |"
    "      Types: deb"
    "      URIs: http://ftp.jaist.ac.jp/debian"
    "      Suites: trixie trixie-updates trixie-backports"
    "      Components: main contrib non-free non-free-firmware"
    "      Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg"
    ""
    "      Types: deb"
    "      URIs: http://security.debian.org/debian-security"
    "      Suites: trixie-security"
    "      Components: main contrib non-free non-free-firmware"
    "      Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg"
    "bootcmd:"
    "  - echo `"nameserver 1.1.1.1`" > /etc/resolv.conf"
    "  - echo `"nameserver 8.8.8.8`" >> /etc/resolv.conf"
    "  - echo `"options timeout:1 attempts:2 single-request`" >> /etc/resolv.conf"
    "  - mkdir -p /etc/systemd/system/serial-getty@.service.d"
    "  - printf `'[Service]\nExecStart=\nExecStart=-/sbin/agetty -a debian --noclear %%I 115200,38400,9600 linux\n`' > /etc/systemd/system/serial-getty@.service.d/override.conf"
    "  - mkdir -p /home/debian/workspace"
    "  - chown -R 1000:1000 /home/debian/workspace"
    "  - grep -q `"/home/debian/workspace`" /etc/fstab || echo `"/dev/vdb1 /home/debian/workspace vfat umask=000,uid=1000,gid=1000,nofail 0 0`" >> /etc/fstab"
    "  - grep -q `"/home/debian/workspace`" /etc/fstab || echo `"/dev/vdb /home/debian/workspace vfat umask=000,uid=1000,gid=1000,nofail 0 0`" >> /etc/fstab"
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$userContent = ($userDataLines -join "`n") + "`n"
[System.IO.File]::WriteAllText($userPath, $userContent, $utf8NoBom)

# 2. Dynamically generate meta-data (UTF-8 No BOM)
$metaContent = "instance-id: portable-debian-01`nlocal-hostname: debian-portable`n"
[System.IO.File]::WriteAllText($metaPath, $metaContent, $utf8NoBom)

# 3. Generate cidata.iso using IMAPI2 (Joliet=2 + ISO9660=1 = 3 preserves long filenames)
if (-not (Test-Path $csPath)) {
    Write-Host "[ERROR] StreamSaver.cs not found: $csPath"
    exit 1
}

Add-Type -Path $csPath

$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3
$fsi.VolumeName = "cidata"
$fsi.Root.AddTree($cidataDir, $false)
$res = $fsi.CreateResultImage()

[StreamSaver]::SaveToFile($res.ImageStream, $isoPath)

$isoSize = (Get-Item $isoPath).Length
Write-Host "[OK] Dynamic cidata.iso created: $isoSize bytes"
exit 0
