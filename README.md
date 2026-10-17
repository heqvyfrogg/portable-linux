# Portable Linux on Windows

管理者権限がなくWSLやSSHが使えないWindows環境（学校PC等）向けに構成した、完全自己完結型Debian仮想開発環境パッケージです。レジストリやシステム領域を変更せず、展開したフォルダ内だけで動作します。

ローカルホスト（127.0.0.1）やSSHポートフォワーディングを一切使わず、コマンドプロンプトやWindows Terminalの標準入出力を直接QEMUシリアルコンソールに接続してLinuxのbashシェルを操作します。

---

## 1. 特徴

- **ローカルホスト（127.0.0.1）やSSHポートへの完全非依存**:
  - ターミナルの標準入出力をQEMUのシリアルコンソール（`mon:stdio`）に直結しています。
  - ループバック通信やSSH接続が遮断された制限環境（学校PC等）でも確実に動作します。
- **フルスタック開発環境が初期状態で完備**:
  - **エディタ**: **Helix**（`hx`、設定不要でLSP・ハイライト動作）および **Neovim**（`nvim`）
  - **コンパイラ・言語環境**: **GCC 14** / **G++ 14** / **make**、**Go 1.23**、**Python 3.13**
- **学校PCのセキュリティフィルター突破（Invoke-WebRequest統一）**:
  - ホスト側の全ダウンローダーを `curl.exe` から Windows標準の **PowerShell `Invoke-WebRequest`** に統一し、特定ツールが遮断されるプロキシ環境でも確実に取得可能です。
- **完全オフライン耐性**:
  - Go、Helix、Neovim、GCC/G++コアバイナリをWindowsホスト側で事前収集してVMに注入するため、VM内部がインターネットに接続できない閉塞環境でも初期起動時から即座に開発できます。
- **シリアルコンソールの自動ログイン**:
  - `debian` ユーザーで自動ログインし、パスワード入力なしで起動後すぐにシェルプロンプトが立ち上がります（`sudo` もパスワード不要）。
- **Windows Terminal最適化**:
  - `TERM=xterm-256color` および `COLORTERM=truecolor` を自動設定し、TrueColor表示とリッチなシンタックスハイライトに対応しています。
- **ペースト時の改行乱れ防止**:
  - Windowsの改行（CRLF）貼り付け時に空行が挟まる現象を、`/etc/inputrc` のBracketed Paste設定で防止しています。
- **管理者権限の不要化**: システム設定やレジストリを変更しません。
- **安全な停止**: `exit` または `sudo poweroff` を実行すると、仮想マシンが正常終了してコンソールが閉じます。

---

## 2. 使い方

### 方法A: 1行コマンドでの導入 (PowerShell推奨)

学校PCなど `curl.exe` がブロックされる環境でも、PowerShellから直接導入できます。

```powershell
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat' -OutFile 'setup.bat'; .\setup.bat"
```

コマンドプロンプトの場合:
```cmd
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/heqvyfrogg/portable-linux/releases/latest/download/setup.bat' -OutFile 'setup.bat'" && setup.bat
```

### 方法B: ZIPファイルからの導入

1. GitHub Releasesから `portable-linux.zip` をダウンロードし、任意のフォルダに解凍します。
2. フォルダ内の `start.bat` を実行します。
3. 起動後、Debianのbashプロンプトが直接表示され、即座に開発を始められます。
4. 作業終了時に `exit` または `sudo poweroff` を入力すると、仮想マシンが安全に停止してウィンドウが閉じます。

---

## 3. 開発ツールの利用方法

Debianターミナル内で以下のコマンドをそのまま実行できます：

- **Helix エディタ**:
  ```bash
  hx main.c
  ```
- **Neovim エディタ**:
  ```bash
  nvim main.go
  ```
- **C言語コンパイル & 実行**:
  ```bash
  gcc main.c -o main && ./main
  ```
- **C++コンパイル & 実行**:
  ```bash
  g++ main.cpp -o main && ./main
  ```
- **Go言語の実行**:
  ```bash
  go run main.go
  ```
- **Pythonの実行**:
  ```bash
  python3 script.py
  ```

---

## 4. 任意のISOファイルからの起動 (Ubuntu、Arch、Alpine等)

外部のLinux ISOファイルを使って起動・インストールすることも可能です。

1. **ISOファイルの指定方法**:
   - `.iso` ファイルを `boot-iso.bat` にドラッグ＆ドロップするか、`iso\` フォルダに配置します。
2. **起動モードの選択**:
   - `[1] Live Boot`: ディスクを使わずに一時起動します。
   - `[2] Install to a new virtual disk`: 新しい仮想ディスク（20GB）を作成してインストールします。
   - `[3] Attach ISO to existing disk`: 既存のカスタムディスクにISOを接続して起動します。
3. **インストール済みOSの起動**:
   - インストール完了後は `start-custom.bat` から起動できます。
