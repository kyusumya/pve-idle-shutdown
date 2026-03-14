#!/usr/bin/env bash

############################
# Configuration
############################

IDLE_LIMIT_MIN=1440 # Idle timeout in minutes (24 hours)
MAX_LOGIN_FAIL=20   # Maximum allowed login failures
FAIL_WINDOW=300     # Time window for counting failures (seconds) = 5 minutes
DRY_RUN=false       # true = debug mode (do not actually shutdown)

############################

IDLE_LIMIT=$((IDLE_LIMIT_MIN * 60))

shutdown_host() {

    if [ "$DRY_RUN" = true ]; then
        echo "[DEBUG] shutdown would be executed"
        return
    fi

    echo "requesting proxmox shutdown"

    pvesh create /nodes/$(hostname -s)/status -command shutdown &

    timeout=180
    start=$(date +%s)

    while sleep 5; do

        now=$(date +%s)
        elapsed=$((now - start))

        if [ "$elapsed" -ge "$timeout" ]; then
            echo "shutdown timeout reached"
            echo "forcing poweroff"
            systemctl poweroff -i
            break
        fi

    done
}

############################
# Log retrieval functions
############################

# SSH / console logout
get_last_console_logout() {

journalctl -u systemd-logind --since "24 hours ago" --no-pager -o short-unix \
| grep "session closed for user" \
| tail -n1 \
| awk '{print $1}' \
| cut -d. -f1

}

# WebUI session activity
get_last_web_auth() {

journalctl -u pvedaemon --since "24 hours ago" --no-pager -o short-unix \
| grep "successful auth for user" \
| tail -n1 \
| awk '{print $1}' \
| cut -d. -f1

}

# VM console access (noVNC / SPICE)
get_last_vm_console() {

journalctl -u pvedaemon --since "24 hours ago" --no-pager -o short-unix \
| grep -iE "starting vnc proxy|termproxy" \
| tail -n1 \
| awk '{print $1}' \
| cut -d. -f1

}

# brute force detection
count_login_failures() {

since=$(date --date="$FAIL_WINDOW seconds ago" "+%Y-%m-%d %H:%M:%S")

journalctl --since "$since" \
| grep -iE "authentication failure|failed password|login failed" \
| wc -l

}

############################
# startup protection
############################

MIN_UPTIME=900  # 15 minutes

uptime_sec=$(cut -d. -f1 /proc/uptime)

echo "[DEBUG] uptime: $uptime_sec"

if [ "$uptime_sec" -lt "$MIN_UPTIME" ]; then
echo "startup grace period"
exit 0
fi

############################
# brute force detection
############################

fail_count=$(count_login_failures)

echo "[DEBUG] login failures: $fail_count"

if [ "$fail_count" -ge "$MAX_LOGIN_FAIL" ]; then
echo "SECURITY: login attack detected ($fail_count attempts)"
shutdown_host
exit 0
fi

############################
# active user check
############################

active=$(who | wc -l)

echo "[DEBUG] active users: $active"

if [ "$active" -gt 0 ]; then
    echo "active user detected"
    if [ "$DRY_RUN" = false ]; then
        exit 0
    fi
fi

############################
# Retrieve last access timestamps
############################

console_logout=$(get_last_console_logout)
web_auth=$(get_last_web_auth)
vm_console=$(get_last_vm_console)

console_logout=${console_logout:-0}
web_auth=${web_auth:-0}
vm_console=${vm_console:-0}

echo "[DEBUG] console_logout: $console_logout"
echo "[DEBUG] web_auth: $web_auth"
echo "[DEBUG] vm_console: $vm_console"

last_access=$console_logout

if [ "$web_auth" -gt "$last_access" ]; then
last_access=$web_auth
fi

if [ "$vm_console" -gt "$last_access" ]; then
last_access=$vm_console
fi

if [ "$last_access" -eq 0 ]; then
echo "no access history"
exit 0
fi

############################
# Calculate idle time
############################

now=$(date +%s)
idle=$((now - last_access))

echo "[DEBUG] idle seconds: $idle"
echo "[DEBUG] idle limit: $IDLE_LIMIT"

############################
# idle shutdown
############################

if [ "$idle" -ge "$IDLE_LIMIT" ]; then
echo "idle timeout reached"
shutdown_host
fi
