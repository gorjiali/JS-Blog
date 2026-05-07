set -euo pipefail
IMAGE='ghcr.io/therealaleph/mhrv-tunnel-node:latest'
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO=sudo; fi
$SUDO docker rm -f mhrv-tunnel 2>/dev/null || true
_IDS=$($SUDO docker ps -aq --filter ancestor="$IMAGE" 2>/dev/null) || true
for _id in $_IDS; do
  $SUDO docker rm -f "$_id" 2>/dev/null || true
done
$SUDO systemctl stop mhrv-tunnel-node 2>/dev/null || true
$SUDO systemctl disable mhrv-tunnel-node 2>/dev/null || true
$SUDO rm -f /etc/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO rm -f /lib/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO rm -f /usr/lib/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO systemctl daemon-reload 2>/dev/null || true
echo "cleanup complete: tunnel deployment removed from this VPS."
