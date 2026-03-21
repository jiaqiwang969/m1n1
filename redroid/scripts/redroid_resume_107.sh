#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

HOST="${REDROID_HOST:-192.168.1.107}"
USER="${REDROID_USER:-wjq}"
PASS="${REDROID_PASS:-}"
ROOTFS="${REDROID_ROOTFS:-/home/wjq/redroid-artifacts/rootfs}"
IMAGE="${IMAGE:-localhost/redroid16k-root:latest}"
CONTAINER="${CONTAINER:-redroid16k-root}"
ART_DIR="${ART_DIR:-${REPO_ROOT}/tmp/redroid-unpatched-artifacts}"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/tmp/redroid-resume-logs}"

mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/run-$STAMP.log"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

trap 'rc=$?; log "resume job exit rc=$rc"' EXIT

require_remote_pass() {
  if [[ -z "$PASS" ]]; then
    printf 'REDROID_PASS is required for the sshpass-based resume workflow.\n' >&2
    exit 1
  fi
}

remote() {
  require_remote_pass
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$USER@$HOST" "$@"
}

remote_sudo() {
  local cmd="$1"
  local qcmd
  qcmd=$(printf '%q' "$cmd")
  remote "printf '%s\n' '$PASS' | sudo -S sh -lc $qcmd"
}

wait_for_host() {
  while true; do
    if remote "echo alive" >/dev/null 2>&1; then
      log "host reachable: $HOST"
      break
    fi
    log "host offline, retry in 10s"
    sleep 10
  done
}

copy_artifacts() {
  log "syncing unpatched minigbm artifacts"
  sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
    "$ART_DIR/android.hardware.graphics.allocator-service.minigbm.unpatched" \
    "$USER@$HOST:$ROOTFS/vendor/bin/hw/android.hardware.graphics.allocator-service.minigbm"
  sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
    "$ART_DIR/mapper.minigbm.so.unpatched" \
    "$USER@$HOST:$ROOTFS/vendor/lib64/hw/mapper.minigbm.so"
  sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
    "$ART_DIR/libminigbm_gralloc.so.unpatched" \
    "$USER@$HOST:$ROOTFS/vendor/lib64/libminigbm_gralloc.so"
  sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
    "$ART_DIR/libminigbm_gralloc4_utils.so.unpatched" \
    "$USER@$HOST:$ROOTFS/vendor/lib64/libminigbm_gralloc4_utils.so"
}

reimport_image() {
  log "reimporting rootful image"
  remote_sudo "podman rm -f $CONTAINER >/dev/null 2>&1 || true"
  remote_sudo "tar -C '$ROOTFS' -c . | podman import - '$IMAGE'"
}

start_container() {
  log "starting rootful container"
  remote_sudo "podman run -d --name $CONTAINER --pull=never --privileged --network host --security-opt label=disable --device /dev/kvm --device /dev/dri/renderD128 --device /dev/dri/card1 --device /dev/dri/card2 --device /dev/dri/card3 -v redroid16k-data-root:/data --entrypoint /system/bin/sh $IMAGE -c 'mkdir -p /dev/binderfs && mount -t binder binder /dev/binderfs && exec /init qemu=1 androidboot.hardware=redroid redroid.gpu.mode=host redroid.gpu.node=/dev/dri/renderD128'" | tee -a "$LOG_FILE"
}

collect_status() {
  log "waiting for boot state"
  sleep 6
  remote_sudo "podman inspect $CONTAINER --format 'status={{.State.Status}} exit={{.State.ExitCode}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} error={{printf \"%q\" .State.Error}}'" | tee -a "$LOG_FILE"
  remote_sudo "podman logs --tail 200 $CONTAINER" | tee -a "$LOG_FILE"
  remote_sudo "podman exec $CONTAINER /system/bin/sh -c '/system/bin/getprop sys.boot_completed; /system/bin/getprop init.svc.adbd; /system/bin/getprop init.svc.surfaceflinger; /system/bin/getprop init.svc.vendor.hwcomposer-3; /system/bin/getprop init.svc.vendor.graphics.allocator; /system/bin/getprop sys.init.updatable_crashing_process_name'" | tee -a "$LOG_FILE" || true
  remote_sudo "podman exec $CONTAINER /system/bin/sh -c 'ps -A | grep -E \"(surfaceflinger|allocator|composer|adbd)\" || true'" | tee -a "$LOG_FILE" || true
}

main() {
  log "resume job started"
  wait_for_host
  copy_artifacts
  reimport_image
  start_container
  collect_status
  log "resume job finished"
}

main "$@"
