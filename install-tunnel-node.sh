set -euo pipefail
TUNNEL_AUTH_KEY='510b02135c4baf91ddac35a9a3841897'
PUBLIC_HOST='45.95.173.114'
IMAGE='ghcr.io/therealaleph/mhrv-tunnel-node:latest'
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO=sudo; fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker missing: installing docker.io..."
  $SUDO apt-get update -y
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
fi
$SUDO systemctl enable --now containerd 2>/dev/null || true
$SUDO systemctl enable --now docker 2>/dev/null || true
READY=""
for i in $(seq 1 30); do
  if $SUDO docker info >/dev/null 2>&1; then
    READY=1
    break
  fi
  if [ "$i" -eq 10 ] || [ "$i" -eq 20 ]; then
    $SUDO systemctl restart containerd 2>/dev/null || true
    $SUDO systemctl restart docker 2>/dev/null || true
  fi
  sleep 2
done
if [ -z "${READY:-}" ]; then
  echo "error: docker is installed but not ready after waiting." >&2
  echo "check: sudo systemctl status containerd docker" >&2
  echo "logs: sudo journalctl -u containerd -u docker --no-pager | tail -n 120" >&2
  exit 1
fi
# Legacy native install (older wizard): stop, untrack, drop unit file.
$SUDO systemctl stop mhrv-tunnel-node 2>/dev/null || true
$SUDO systemctl disable mhrv-tunnel-node 2>/dev/null || true
$SUDO rm -f /etc/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO rm -f /lib/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO rm -f /usr/lib/systemd/system/mhrv-tunnel-node.service 2>/dev/null || true
$SUDO systemctl daemon-reload 2>/dev/null || true
# Prior Docker tunnel-node(s): standard name and any container from this image.
$SUDO docker rm -f mhrv-tunnel 2>/dev/null || true
_IDS=$($SUDO docker ps -aq --filter ancestor="$IMAGE" 2>/dev/null) || true
for _id in $_IDS; do
  $SUDO docker rm -f "$_id" 2>/dev/null || true
done
CHOSEN=""
for p in $(seq 18080 18199); do
  if ! ss -lntp 2>/dev/null | grep -qE ":${p}\b"; then
    CHOSEN=$p
    break
  fi
done
if [ -z "${CHOSEN:-}" ]; then
  echo "error: no free TCP port in 18080-18199 (ss -lntp)." >&2
  exit 1
fi
PULLED=""
for i in $(seq 1 6); do
  if $SUDO docker pull "$IMAGE"; then
    PULLED=1
    break
  fi
  echo "warn: docker pull failed (attempt $i/6). retrying in 5s..."
  sleep 5
done
if [ -z "${PULLED:-}" ]; then
  echo "error: failed to pull $IMAGE after retries (network/TLS issue)." >&2
  exit 1
fi
$SUDO docker run -d --name mhrv-tunnel --restart unless-stopped \
  --network host \
  -e "PORT=${CHOSEN}" \
  -e "TUNNEL_AUTH_KEY=${TUNNEL_AUTH_KEY}" \
  "$IMAGE"
sleep 2
set +e
HC=$(curl -fsS "http://127.0.0.1:${CHOSEN}/health" 2>/dev/null)
set -eu
if printf '%s' "$HC" | grep -q ok; then
  echo "ok: tunnel-node is up on port ${CHOSEN}."
else
  echo "warn: curl http://127.0.0.1:${CHOSEN}/health failed — docker logs mhrv-tunnel"
fi
echo ""
echo "========================================"
echo "  COPY THIS PORT INTO SHADE"
echo "  TUNNEL_PORT = ${CHOSEN}"
echo "========================================"
echo "TUNNEL_SERVER_URL=http://${PUBLIC_HOST}:${CHOSEN}"
echo "Open TCP ${CHOSEN} in your cloud firewall."
