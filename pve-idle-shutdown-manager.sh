#!/usr/bin/env bash

SERVICE="pve-idle-shutdown"
SCRIPT_PATH="/usr/local/bin/pve-idle-shutdown.sh"

SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"
TIMER_FILE="/etc/systemd/system/${SERVICE}.timer"

install_service() {

echo "Installing service..."

# スクリプト配置
install -m 755 pve-idle-shutdown.sh "$SCRIPT_PATH"

# service作成
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Proxmox Idle Shutdown Monitor

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# timer作成
cat <<EOF > "$TIMER_FILE"
[Unit]
Description=Run Proxmox Idle Shutdown check every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=${SERVICE}.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE}.timer

echo "Installed successfully"
}

uninstall_service() {

echo "Uninstalling service..."

systemctl disable --now ${SERVICE}.timer 2>/dev/null

rm -f "$SERVICE_FILE"
rm -f "$TIMER_FILE"
rm -f "$SCRIPT_PATH"

systemctl daemon-reload

echo "Uninstalled successfully"
}

status_service() {

systemctl status ${SERVICE}.timer
}

case "$1" in
install)
install_service
;;

uninstall)
uninstall_service
;;

status)
status_service
;;

*)
echo "Usage: $0 {install|uninstall|status}"
exit 1
;;

esac
