param(
    [string]$Root = ""
)

if (-not $Root) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$cidataDir = Join-Path $Root "config\cidata"
$userPath  = Join-Path $cidataDir "user-data"
$metaPath  = Join-Path $cidataDir "meta-data"
$isoPath   = Join-Path $Root "config\cidata.iso"
$pubKeyPath = Join-Path $Root "ssh\id_ed25519.pub"
$csPath    = Join-Path $Root "scripts\StreamSaver.cs"

if (-not (Test-Path $pubKeyPath)) {
    Write-Host "[ERROR] SSH public key not found: $pubKeyPath"
    exit 1
}

$pubKey = (Get-Content $pubKeyPath -Raw).Trim()

if (-not (Test-Path $cidataDir)) {
    New-Item -ItemType Directory -Path $cidataDir -Force | Out-Null
}

# 1. user-data を動的生成 (環境依存の特定ユーザー・公開鍵を排除)
$u1 = "#cloud-config"
$u2 = "users:"
$u3 = "  - name: debian"
$u4 = "    gecos: Debian Portable User"
$u5 = "    sudo: ALL=(ALL) NOPASSWD:ALL"
$u6 = "    lock_passwd: false"
$u7 = "    plain_text_passwd: debian"
$u8 = "    shell: /bin/bash"
$u9 = "    ssh_authorized_keys:"
$u10 = "      - " + $pubKey
$u11 = ""
$u12 = "ssh_pwauth: true"
$u13 = "chpasswd:"
$u14 = "  expire: false"

$userContent = "$u1`n$u2`n$u3`n$u4`n$u5`n$u6`n$u7`n$u8`n$u9`n$u10`n$u11`n$u12`n$u13`n$u14`n"
[System.IO.File]::WriteAllText($userPath, $userContent, [System.Text.Encoding]::UTF8)

# 2. meta-data を動的生成
$metaContent = "instance-id: portable-debian-01`nlocal-hostname: debian-portable`n"
[System.IO.File]::WriteAllText($metaPath, $metaContent, [System.Text.Encoding]::UTF8)

# 3. IMAPI2 を使って cidata.iso を生成 (純粋Windows標準API・外部ツール不要)
if (-not (Test-Path $csPath)) {
    Write-Host "[ERROR] StreamSaver.cs not found: $csPath"
    exit 1
}

Add-Type -Path $csPath

$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 1
$fsi.VolumeName = "cidata"
$fsi.Root.AddTree($cidataDir, $false)
$res = $fsi.CreateResultImage()

[StreamSaver]::SaveToFile($res.ImageStream, $isoPath)

$isoSize = (Get-Item $isoPath).Length
Write-Host "[OK] Dynamic cidata.iso created: $isoSize bytes"
exit 0
