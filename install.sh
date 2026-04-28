#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: please run as root (sudo bash install.sh)"
  exit 1
fi

REPO_URL="https://raw.githubusercontent.com/timshuang/wdog/main"
INSTALL_DIR="/opt/wdog"
CONF_DIR="/etc/wdog"
BIN_LINK="/usr/local/bin/wdog"

echo "========================================="
echo "  wdog installer"
echo "========================================="
echo ""

if ! command -v jq &>/dev/null; then
  echo "Installing jq..."
  apt-get update -qq && apt-get install -y -qq jq
fi

if ! command -v curl &>/dev/null; then
  echo "Installing curl..."
  apt-get install -y -qq curl
fi

echo "Checking dependencies: jq=$(command -v jq) curl=$(command -v curl)"
echo ""

echo "Downloading wdog..."
mkdir -p "$INSTALL_DIR/bin"
curl -sL "$REPO_URL/bin/wdog" -o "$INSTALL_DIR/bin/wdog"
chmod +x "$INSTALL_DIR/bin/wdog"
echo "  Downloaded: $INSTALL_DIR/bin/wdog"
echo ""

RESEND_KEY=""
while true; do
  read -rp "Enter your Resend API key (starts with re_): " RESEND_KEY
  if [[ "$RESEND_KEY" =~ ^re_ ]]; then
    break
  else
    echo "  Invalid: Resend API key must start with 're_'. Please try again."
  fi
done

ALERT_EMAIL=""
while true; do
  read -rp "Enter alert email address: " ALERT_EMAIL
  if [[ "$ALERT_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
    break
  else
    echo "  Invalid email format. Please try again."
  fi
done

CHECK_INTERVAL=""
while true; do
  read -rp "Enter check interval in minutes (1-1440) [5]: " CHECK_INTERVAL
  CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
  if [[ "$CHECK_INTERVAL" =~ ^[0-9]+$ ]] && [ "$CHECK_INTERVAL" -ge 1 ] && [ "$CHECK_INTERVAL" -le 1440 ]; then
    break
  else
    echo "  Invalid: must be an integer between 1 and 1440. Please try again."
  fi
done

echo ""
echo "Configuration:"
echo "  Resend API key: re_****${RESEND_KEY: -4}"
echo "  Alert email:    $ALERT_EMAIL"
echo "  Check interval: $CHECK_INTERVAL min"
echo ""

read -rp "Proceed with installation? [Y/n] " confirm
confirm="${confirm:-Y}"
[[ "$confirm" =~ ^[Yy] ]] || { echo "Cancelled."; exit 0; }

echo ""
echo "Installing config..."

mkdir -p "$CONF_DIR"

if [ -f "$CONF_DIR/config.json" ]; then
  echo "  Existing config.json found, updating mail and interval settings..."
  tmp=$(jq --arg e "$ALERT_EMAIL" --arg k "$RESEND_KEY" --argjson v "$CHECK_INTERVAL" \
    '.mail.to = $e | .mail.resendKey = $k | .checkIntervalMin = $v' "$CONF_DIR/config.json")
  echo "$tmp" > "$CONF_DIR/config.json"
else
  cat > "$CONF_DIR/config.json" <<EOF
{
  "checkIntervalMin": $CHECK_INTERVAL,
  "mail": {
    "to": "$ALERT_EMAIL",
    "resendKey": "$RESEND_KEY"
  }
}
EOF
fi

[ -f "$CONF_DIR/regs.json" ] || echo '[]' > "$CONF_DIR/regs.json"

touch /var/log/wdog.log

echo "Installing systemd service..."
cat > /etc/systemd/system/wdog.service <<EOF
[Unit]
Description=wdog process monitor
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bin/wdog daemon
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

ln -sf "$INSTALL_DIR/bin/wdog" "$BIN_LINK"

systemctl daemon-reload
systemctl enable wdog
systemctl start wdog

echo ""
echo "========================================="
echo "  Installation complete!"
echo "========================================="
echo ""
echo "  Daemon status: systemctl status wdog"
echo "  View log:      tail -f /var/log/wdog.log"
echo "  CLI:           wdog -h"
echo ""
echo "  Register:      wdog reg <name> [-m <pattern>]"
echo "  List:          wdog list"
echo ""
