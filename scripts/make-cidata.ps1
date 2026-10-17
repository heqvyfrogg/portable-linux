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

# 1. Dynamically generate user-data with complete offline dev toolchain and terminal optimization
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
    "  - path: /etc/sudoers.d/99-debian-nopasswd"
    "    permissions: '0440'"
    "    content: |"
    "      debian ALL=(ALL) NOPASSWD:ALL"
    "  - path: /etc/systemd/system/serial-getty@.service.d/override.conf"
    "    content: |"
    "      [Service]"
    "      ExecStart="
    "      ExecStart=-/sbin/agetty --autologin debian --noclear %I 115200,38400,9600 linux"
    "  - path: /etc/profile.d/terminal.sh"
    "    content: |"
    "      export TERM=xterm-256color"
    "      export COLORTERM=truecolor"
    "      export PATH=/usr/local/go/bin:/usr/local/bin:`$PATH"
    "      if [ -t 0 ]; then stty sane 2>/dev/null; fi"
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
    "      Suites: trixie trixie-updates"
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
    "  - echo `'debian ALL=(ALL) NOPASSWD:ALL'` > /etc/sudoers.d/99-debian-nopasswd && chmod 0440 /etc/sudoers.d/99-debian-nopasswd"
    "  - mkdir -p /etc/systemd/system/serial-getty@.service.d"
    "  - echo `'[Service]'` > /etc/systemd/system/serial-getty@.service.d/override.conf"
    "  - echo `'ExecStart='` >> /etc/systemd/system/serial-getty@.service.d/override.conf"
    "  - echo `'ExecStart=-/sbin/agetty --autologin debian --noclear %I 115200,38400,9600 linux'` >> /etc/systemd/system/serial-getty@.service.d/override.conf"
    "  - mkdir -p /mnt/payload"
    "  - mount -t vfat /dev/vdb1 /mnt/payload 2>/dev/null || mount -t vfat /dev/vdb /mnt/payload 2>/dev/null || true"
    "  - if [ -f /mnt/payload/go.linux-amd64.tar.gz ]; then tar -C /usr/local -xzf /mnt/payload/go.linux-amd64.tar.gz; fi"
    "  - if [ -f /mnt/payload/helix.tar.xz ]; then mkdir -p /tmp/hx && tar -C /tmp/hx -xJf /mnt/payload/helix.tar.xz && cp /tmp/hx/*/hx /usr/local/bin/hx && cp -r /tmp/hx/*/runtime /usr/local/bin/ && rm -rf /tmp/hx; fi"
    "  - if [ -f /mnt/payload/nvim.tar.gz ]; then mkdir -p /tmp/nvim && tar -C /tmp/nvim -xzf /mnt/payload/nvim.tar.gz && cp -r /tmp/nvim/nvim-linux-x86_64/* /usr/local/ && rm -rf /tmp/nvim; fi"
    "  - if [ -d /mnt/payload/debs ]; then dpkg --force-all -i /mnt/payload/debs/*.deb 2>/dev/null || true; fi"
    "  - ln -sf /usr/bin/x86_64-linux-gnu-gcc-14 /usr/local/bin/gcc 2>/dev/null || true"
    "  - ln -sf /usr/bin/x86_64-linux-gnu-g++-14 /usr/local/bin/g++ 2>/dev/null || true"
    "  - ln -sf /usr/bin/make /usr/local/bin/make 2>/dev/null || true"
    "  - umount /mnt/payload 2>/dev/null || true"
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
