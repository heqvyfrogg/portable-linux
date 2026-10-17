# Portable Linux on Windows

管理者権限がなくWSLが使えないWindows環境向けに構成した、Debian仮想環境パッケージです。レジストリやシステム領域を変更せず、展開したフォルダ内だけで動作します。
ZIPファイルを解凍して `start.bat` を実行すると、パスワード入力なしでターミナル画面が起動します。

---

## 1. 高速化設定の内容

ソフトウェアエミュレーション（TCG）で生じる遅延を抑えるため、以下の最適化を行っています。

1. **IPv6タイムアウトの防止 (`ipv6=off`、DNS設定)**
   - QEMUの仮想ネットワーク（SLIRP）でIPv6スタックを無効化しています。
   - 外部通信時にIPv6 DNSへの問い合わせで生じる待機時間を防ぎます。
   - `/etc/resolv.conf` に `options timeout:1 attempts:2 single-request` を設定し、名前解決の待機時間を短縮しています。
2. **ディスクI/Oの高速化 (`cache=unsafe`、`force-unsafe-io`)**
   - ホスト側のディスク同期待ちを省き、ゲストOS側にも `/etc/dpkg/dpkg.cfg.d/force-unsafe-io` を適用しています。
   - パッケージ展開時のディスク同期（fsync）を省くことで、`apt` による導入時間を短縮しています。
3. **国内ミラーとAPT設定 (JAIST、多言語インデックス除外)**
   - パッケージ取得先を北陸先端科学技術大学院大学のミラーサーバー（`ftp.jaist.ac.jp`）に設定しています。
   - `APT::Acquire::Translation "none"` により多言語インデックスのダウンロードを省き、ソースパッケージを除外して `apt update` の時間を抑えています。
4. **Gitのマルチスレッド設定**
   - `git config --global pack.threads 4` および `core.preloadindex true` を設定し、複数CPUコアを活用してリポジトリ取得やオブジェクト展開を高速化しています。
5. **JIT変換キャッシュの拡大 (`tb-size=1024`)**
   - QEMUのTranslation Blockキャッシュを1024MBに設定し、バイナリ実行時の再コンパイル頻度を抑えています。
6. **仮想マシンへのリソース割り当て**
   - メモリ: 4096MB
   - 仮想CPU: 4コア

---

## 2. 特徴

- **ローカルホスト（127.0.0.1）やSSHポートへの非依存**:
  - コマンドプロンプトの標準入出力をQEMUのシリアルコンソール（`mon:stdio`）に直結しています。
  - ループバック通信やSSH接続が制限された環境（学校PC等）でも、ネットワークソケットを介さず直接bashプロンプトを操作できます。
- **ホスト側エディタ（Zed等）との双方向ファイル共有**:
  - ホスト側の `workspace\` フォルダが、ゲストOS側の `/home/debian/workspace` に仮想ストレージとして自動マウントされます。
  - Windows側でZedなどのエディタを用いてソースコードやファイルを編集し、VM側でそのまま実行・ビルドできます。
- **シリアルコンソールの自動ログイン**:
  - `debian` ユーザーでの自動ログインが設定されており、パスワード入力なしで起動後すぐにシェルプロンプトを利用できます。
- **ペースト時の改行乱れの防止**:
  - Windowsの改行（CRLF）を貼り付けた際に空行が挟まる現象を、`/etc/inputrc` のBracketed Paste設定と端末設定で防いでいます。
- **管理者権限の不要化**: システム設定やレジストリを変更しません。
- **安全な停止**: `exit` または `sudo poweroff` を実行すると、仮想マシンが正常終了してコンソールが閉じます。

---

## 3. 使い方

### 方法A: 1行コマンドでの導入

導入先のフォルダで、コマンドプロンプトまたはPowerShellから以下のコマンドを実行します。必要なファイルを取得して展開します。

- **コマンドプロンプト (cmd)**:
  ```cmd
  curl.exe -sL "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat" -o setup.bat && setup.bat
  ```

- **PowerShell**:
  ```powershell
  curl.exe -sL "https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat" -o setup.bat; .\setup.bat
  ```

---

### 方法B: ZIPファイルからの導入

1. GitHub Releasesから `portable-linux.zip` をダウンロードし、任意のフォルダに解凍します。
2. フォルダ内の `start.bat` を実行します。
3. 起動処理と初期設定が完了すると、Debianのbashプロンプトが表示されます。
4. 作業終了時に `exit` を入力すると、仮想マシンが停止してウィンドウが閉じます。

---

## 4. 任意のISOファイルからの起動 (Ubuntu、Arch、Alpine、Kali等)

Linuxディストリビューションの `.iso` ファイルを用意することで、任意のOSを起動またはインストールできます。

1. **ISOファイルの指定方法**
   - **ドラッグ＆ドロップ**: `.iso` ファイルを `boot-iso.bat` に重ねて開きます。
   - **配置フォルダ**: `iso\` フォルダ内に `.iso` ファイルを置いて `boot-iso.bat` を実行します。
   - **ファイル選択**: `boot-iso.bat` を実行し、表示される選択画面から `.iso` ファイルを指定します。
2. **起動モード**
   - **1. Live ブート**: 仮想ディスクを作成せず、ISOから直接起動します。
   - **2. 新規ディスクにインストール**: 20GBの仮想ディスク（`disk\custom.qcow2`）を作成し、インストーラーを起動します。
   - **3. 既存ディスクに接続**: 作成済みの `custom.qcow2` にISOを接続して起動します。
3. **インストーラー操作時の留意事項**
   - **インストールモードの選択**: キーボードで操作しやすいテキストモード（Install）を推奨します。
   - **ネットワーク設定時の待機**: エミュレーション動作のため、DHCP設定やコンポーネント展開に数分かかる場合があります。
   - **ディスク書き込みの確定**: パーティション設定の最終画面（`Write the changes to disks?`）では、`<Yes>` を選択して進めてください。
4. **インストール完了後の起動**
   - インストール完了後は、`start-custom.bat` から起動できます。
