# Portable Linux on Windows (QEMU + Debian 12 + Bundled OpenSSH) - High Performance

管理者権限なし、WSL不可のWindows環境向けに構築された、**完全ポータブル・Windows環境依存なし・レジストリ無接触・高速チューニング済み**のDebian仮想環境パッケージです。
解凍して `start.bat` をダブルクリックするだけで、パスワード入力なし・1つのターミナル画面でそのまま使用できます。

---

## 1. 高速化チューニング内容

ソフトウェアエミュレーション（TCG）における最大の遅延原因であった「JIT再コンパイル頻度」「パッケージ展開時の fsync 待ち」「IPv6名前解決タイムアウト」を徹底排除しました:

1. **IPv6 タイムアウトの完全排除 (`ipv6=off` + 高速 DNS)**:
   - QEMU 仮想ネットワーク（SLIRP）の不要な IPv6 スタックを完全無効化 (`ipv6=off`)。
   - 外部通信時に到達不能な IPv6 DNS (`fec0::3`) への問い合わせで毎回発生していた **5秒間のフリーズ（タイムアウト）を根絶**。
   - `/etc/resolv.conf` に `options timeout:1 attempts:2 single-request` を適用し、名前解決をミリ秒単位に高速化。
2. **I/O 速度の劇的向上 (`cache=unsafe` + `force-unsafe-io`)**:
   - ホスト側のディスク同期待ちをスキップするだけでなく、ゲストOS側にも `/etc/dpkg/dpkg.cfg.d/force-unsafe-io` を自動適用。
   - `apt install` や `dpkg` が 1 ファイル展開ごとに発生させていた同期待ち（fsync）を完全スキップし、パッケージ展開が **数倍〜十倍以上** に向上。
3. **国内最速ミラー & APT 最適化 (JAIST / 多言語除外)**:
   - リポジトリを日本国内最速の北陸先端大ミラー（`ftp.jaist.ac.jp`）へ自動切り替え。
   - `APT::Acquire::Translation "none"` により巨大な多言語インデックスのダウンロード・解凍を廃止し、ソースパッケージ（`deb-src`）を除外して `apt update` の所要時間を半減。
4. **Git マルチスレッド最適化**:
   - `git config --global pack.threads 4` および `core.preloadindex true` を自動設定し、TCG のマルチコアを活用して `git clone` やオブジェクト展開を劇的に高速化。
5. **JIT 変換キャッシュの大幅拡大 (`tb-size=1024`)**:
   - QEMU の Translation Block キャッシュを 1024 MB に設定。
   - 大量のバイナリ実行やビルド時のキャッシュ溢れによる再コンパイルを劇的に削減。
6. **リソース割り当ての増強**:
   - メモリ: 4096 MB (4 GB)
   - vCPU: 4 コア

---

## 2. 特徴

- **Windows機能（OpenSSH等）への依存ゼロ**: 公式ポータブル版 OpenSSH（`bin\ssh.exe`）を同梱。
- **VM全体のペースト二重改行を完全防止 (シェル / nano / 全CLIツール)**:
  - Windows のクリップボード（CRLF: `\r\n`）を Linux VM に貼り付けた際、`\r` と `\n` が二重に処理されて行間が空行だらけになる問題を、システム全体の Bracketed Paste (`/etc/inputrc`) および端末設定により根本解消。シェルでの複数行コマンド実行やテキスト編集が快適に行えます。
- **インターネット接続・DNS自動補正**:
  - QEMU user networking (SLIRP) にパブリック DNS (`1.1.1.1`) を指定。
  - 起動時に `/etc/resolv.conf` へパブリック DNS (`1.1.1.1` / `8.8.8.8`) を自動注入。
  - ※注意: QEMU の仕様上、非特権ユーザーモードネットワークでは **`ping` (ICMP) はパケットが破棄されます**。導通確認には `curl -I https://deb.debian.org` や `sudo apt update` を使用してください。
- **パスワード入力不要**: Ed25519 鍵認証を強制設定済み。
- **管理者権限・UAC昇格 一切不要**: レジストリ書き込み・システム変更は 0 件。
- **完全 1 ウィンドウ化**: QEMU はバックグラウンド（画面なし）で動作し、開くターミナルは 1 つだけ。
- **終了時自動安全シャットダウン**: `exit` を入力すると自動で `sudo poweroff` が実行され、プロセスが完全に終了します。

---

## 3. 使い方

### 方法A: 1行コマンドで即座に導入（推奨・コピペ作成不要）
任意のフォルダ（USBメモリや作業フォルダ）を開き、コマンドプロンプトまたはPowerShellで以下の**1行**を実行するだけで、全自動でダウンロード・展開されます:

- **コマンドプロンプト (cmd)**:
  ```cmd
  curl.exe -sL "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat" -o setup.bat && setup.bat
  ```

- **PowerShell**:
  ```powershell
  curl.exe -sL "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat" -o setup.bat; .\setup.bat
  ```

---

### 方法B: 手動ダウンロードで導入
1. GitHub Releases の最新 `portable-linux.zip` を任意のフォルダに解凍します。
2. フォルダ直下の **`start.bat`** をダブルクリックします。
3. 自動で起動・高速化設定が行われ（約10秒）、Debian の bash プロンプトに入ります。
4. 作業が終わったら **`exit`** と入力すると、自動で仮想マシンが安全に停止してウィンドウが閉じます。

---

## 4. 好きな ISO ファイルを使う方法 (Ubuntu / Arch / Alpine / Kali 等)

任意の Linux ディストリビューションの `.iso` ファイルから直接起動・インストールが可能です:

1. **ISO ファイルの指定方法**:
   - **方法A (ドラッグ＆ドロップ)**: お手持ちの `.iso` ファイルを `boot-iso.bat` に直接ドラッグ＆ドロップします。
   - **方法B (専用フォルダ)**: `iso\` フォルダ内に `.iso` ファイルを配置して `boot-iso.bat` を起動します。
   - **方法C (ファイル選択画面)**: `boot-iso.bat` をダブルクリックすると自動でファイル選択ダイアログが開き、任意の場所にある `.iso` を選べます。
2. **起動モードの選択**:
   - **[1] Live ブート**: ディスクを作らず、ISO から直接お試し起動（QEMU ウィンドウが開きます）。
   - **[2] 新規ディスクにインストール**: 20GB の仮想ディスク（`disk\custom.qcow2`）を自動作成し、インストーラーを起動。
   - **[3] 既存ディスクに接続**: 既存の `custom.qcow2` に ISO を接続して起動。
4. **インストール時のポイント (Kali / Debian / Ubuntu 等)**:
   - **ブートメニューでの選択**: キーボードだけでスムーズに進行できるよう、`Graphical install` ではなく **`Install` (テキストモード)** の選択を推奨します。
   - **ネットワーク設定時の待機**: 管理者権限なし環境（TCG CPUエミュレーション）のため、IPv6/DHCPの自動構成やコンポーネント展開で 2〜3 分間停止して見える場合がありますが、フリーズではないため待機してください。
   - **ディスク書き込みの確認**: パーティション設定の最終画面（`Write the changes to disks?`）ではデフォルトが `<No>` になっているため、必ず `Tab` キーで **`<Yes>`** を選択して Enter を押してください。
5. **インストール完了後の通常起動**:
   - インストール完了後は、**`start-custom.bat`** を実行することで、GUI 画面（デスクトップ環境）またはヘッドレス（SSH）で起動できます。
