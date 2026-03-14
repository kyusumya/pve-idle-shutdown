# 🖥️ Proxmox Idle Shutdown

Proxmox VE ホストを **アイドル状態のときに自動シャットダウン**するためのシンプルなスクリプト。

SSH / WebUI / VMコンソールなどのアクセスを監視し、  
一定時間操作が無い場合にホストを安全に停止する。

---

# ✨ Features

- 💤 **Idle shutdown**  
  一定時間アクセスが無い場合にホストを自動停止

- 🧑‍💻 **ユーザー活動検知**
  - SSH / console logout
  - Proxmox WebUI login
  - VM console (noVNC / SPICE)

- 🔐 **ブルートフォース検知**
  - 短時間のログイン失敗を検知
  - 攻撃と判断した場合は即シャットダウン

- 🧪 **DRY_RUNモード**
  - 実際にシャットダウンせず動作確認可能

- ⚙️ **systemd timer**
  - 定期実行 (5分ごと)

---

# 📂 Project Structure

```
.
├── pve-idle-shutdown.sh
└── pve-idle-shutdown-manager.sh
```

### `pve-idle-shutdown.sh`

アイドル判定とシャットダウン処理を行うメインスクリプト。

ログから以下の操作を検知する。

- SSH / console logout
- WebUI authentication
- VM console access
- login failure (攻撃検知)

例:

```bash
journalctl -u pvedaemon --since "24 hours ago"
```

ログ解析により最後のアクセス時間を取得する。

---

### `pve-idle-shutdown-manager.sh`

systemd service / timer を簡単に **インストール / アンインストール**する管理スクリプト。

---

# ⚙️ Configuration

`pve-idle-shutdown.sh`

```bash
IDLE_LIMIT_MIN=1440
MAX_LOGIN_FAIL=20
FAIL_WINDOW=300
DRY_RUN=false
```

| Setting          | Description           |
| ---------------- | --------------------- |
| `IDLE_LIMIT_MIN` | アイドル時間 (分)     |
| `MAX_LOGIN_FAIL` | ログイン失敗許容回数  |
| `FAIL_WINDOW`    | 失敗カウント時間 (秒) |
| `DRY_RUN`        | trueでテストモード    |

---

# 🚀 Installation

### 1️⃣ リポジトリ配置

```bash
git clone https://github.com/kyusumya/pve-idle-shutdown
cd pve-idle-shutdown-manager
```

---

### 2️⃣ インストール

```bash
sudo ./pve-idle-shutdown-manager.sh install
```

実行すると

- スクリプト配置
- systemd service作成
- systemd timer有効化

が自動で行われる。

---

# 🔄 Timer

デフォルトでは **5分ごとにチェック**。

```ini
OnUnitActiveSec=5min
```

変更したい場合:

```
/etc/systemd/system/pve-idle-shutdown.timer
```

---

# 📊 Status

```bash
./pve-idle-shutdown-manager.sh status
```

または

```bash
systemctl status pve-idle-shutdown.timer
```

---

# 🧪 Debug Mode

シャットダウンせず動作確認する場合

```bash
DRY_RUN=true
```

実行例

```
[DEBUG] login failures: 4
[DEBUG] active users: 1
[DEBUG] idle seconds: 181
```

---

# 🗑 Uninstall

```bash
sudo ./pve-idle-shutdown-manager.sh uninstall
```

削除されるもの

- systemd service
- systemd timer
- `/usr/local/bin/pve-idle-shutdown.sh`

---

# ⚠️ Notes

- Proxmox VE 環境専用
- `journalctl` ログ解析を使用
- root 権限で実行が必要

---

# 📜 License

MIT
