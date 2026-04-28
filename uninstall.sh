#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: please run as root (sudo bash uninstall.sh)"
  exit 1
fi

exec 3<>/dev/tty

echo "========================================="
echo "  wdog uninstaller"
echo "========================================="
echo ""
echo "This will remove:"
echo "  - systemd service"
echo "  - /opt/wdog/"
echo "  - /etc/wdog/"
echo "  - /usr/local/bin/wdog symlink"
echo "  - /var/log/wdog.log"
echo "  - /var/run/wdog.pid"
echo ""

read -rp "Proceed with uninstall? [y/N] " confirm <&3
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo "Stopping wdog service..."
systemctl stop wdog 2>/dev/null || true
systemctl disable wdog 2>/dev/null || true

echo "Removing systemd service..."
rm -f /etc/systemd/system/wdog.service
systemctl daemon-reload

echo "Removing files..."
rm -rf /opt/wdog
rm -rf /etc/wdog
rm -f /usr/local/bin/wdog
rm -f /var/log/wdog.log
rm -f /var/run/wdog.pid

echo ""
echo "wdog has been uninstalled."
