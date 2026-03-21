#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REMOTE_HOST="${REDROID_HOST:-192.168.1.107}"
REMOTE_USER="${REDROID_USER:-wjq}"
REMOTE_SSH_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
SUDO_PASS="${SUDO_PASS:-}"
VM_DIR="${VM_DIR:-/home/wjq/vm4k/ubuntu24k}"
VM_LAUNCH_SCRIPT="${VM_LAUNCH_SCRIPT:-${VM_DIR}/launch.sh}"
VM_STOP_SCRIPT="${VM_STOP_SCRIPT:-${VM_DIR}/stop.sh}"
VM_STATUS_SCRIPT="${VM_STATUS_SCRIPT:-${VM_DIR}/status.sh}"
VM_PIPEWIRE_QUANTUM="${VM_PIPEWIRE_QUANTUM:-}"
VM_PIPEWIRE_LATENCY="${VM_PIPEWIRE_LATENCY:-}"
VM_AUDIO_OUT_LATENCY_US="${VM_AUDIO_OUT_LATENCY_US:-}"
VM_AUDIO_TIMER_PERIOD_US="${VM_AUDIO_TIMER_PERIOD_US:-}"
VM_AUDIO_OUT_MIXING_ENGINE="${VM_AUDIO_OUT_MIXING_ENGINE:-}"
VM_AUDIO_OUT_FIXED_SETTINGS="${VM_AUDIO_OUT_FIXED_SETTINGS:-}"
VM_QEMU_SMP="${VM_QEMU_SMP:-}"
HOST_AUDIO_SINK_INPUT_VOLUME="${HOST_AUDIO_SINK_INPUT_VOLUME:-120%}"
HOST_AUDIO_TARGET_SINK="${HOST_AUDIO_TARGET_SINK:-}"
HOST_AUDIO_MOVE_TO_TARGET="${HOST_AUDIO_MOVE_TO_TARGET:-1}"
GUEST_USER="${GUEST_USER:-wjq}"
GUEST_SSH_PORT="${GUEST_SSH_PORT:-2222}"
GUEST_SSH_KEY="${GUEST_SSH_KEY:-${VM_DIR}/guest_key}"
GUEST_SSH_PASSWORD="${GUEST_SSH_PASSWORD:-}"
ADB_SERIAL="${ADB_SERIAL:-127.0.0.1:5556}"
VNC_HOST="${VNC_HOST:-127.0.0.1}"
VNC_PORT="${VNC_PORT:-5901}"
IMAGE="${IMAGE:-localhost/redroid4k-root:alsa-hal-ranchu-exp2}"
CONTAINER="${CONTAINER:-redroid16kguestprobe}"
VOLUME_NAME="${VOLUME_NAME:-redroid16kguestprobe-data}"
DOUYIN_PACKAGE="${DOUYIN_PACKAGE:-com.ss.android.ugc.aweme}"
DOUYIN_ACTIVITY="${DOUYIN_ACTIVITY:-com.ss.android.ugc.aweme/.splash.SplashActivity}"
LOCAL_DOUYIN_APK_PATH="${LOCAL_DOUYIN_APK_PATH:-}"
REMOTE_DOUYIN_APK_PATH="${REMOTE_DOUYIN_APK_PATH:-/tmp/douyin.apk}"
DOUYIN_AUDIO_STATUS_LINES="${DOUYIN_AUDIO_STATUS_LINES:-40}"
DOUYIN_LOGCAT_LINES="${DOUYIN_LOGCAT_LINES:-60}"
DOUYIN_LOGCAT_FILTER="${DOUYIN_LOGCAT_FILTER:-aweme|AudioFlinger|audio_hw_primary|android\\.hardware\\.audio|pcm|tinyalsa|libttmplayer|AndroidRuntime|FATAL EXCEPTION|crash}"
LEGACY_GUEST_CONTAINERS="${LEGACY_GUEST_CONTAINERS:-redroid16kbridgeprobe}"
VIEWER_MODE="${VIEWER_MODE:-vnc}"
LOCAL_VIEWER_PATH="${LOCAL_VIEWER_PATH:-${REPO_ROOT}/redroid/tools/redroid_viewer.py}"
REMOTE_VIEWER_PATH="${REMOTE_VIEWER_PATH:-/tmp/redroid_viewer.py}"
GRAPHICS_PROFILE="${GRAPHICS_PROFILE:-guest-all-dri}"
VKMS_CARD_NODE="${VKMS_CARD_NODE:-/dev/dri/card1}"
GUEST_DRI_CARD_NODE="${GUEST_DRI_CARD_NODE:-/dev/dri/card0}"
GUEST_DRI_RULE_PATH="${GUEST_DRI_RULE_PATH:-/etc/udev/rules.d/99-redroid-dri.rules}"
GUEST_SND_RULE_PATH="${GUEST_SND_RULE_PATH:-/etc/udev/rules.d/99-redroid-snd.rules}"
ANDROID_AUDIO_GID="${ANDROID_AUDIO_GID:-1005}"
REDROID_GPU_MODE="${REDROID_GPU_MODE:-guest}"
REDROID_GPU_NODE="${REDROID_GPU_NODE:-/dev/dri/card0}"
REDROID_VNC_BOOT="${REDROID_VNC_BOOT:-1}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: zsh redroid/scripts/redroid_guest4k_107.sh [--dry-run] <vm-start|vm-stop|vm-status|restart|restart-preserve-data|status|verify|viewer|douyin-install|douyin-start|douyin-diagnose|audio-diagnose>

Actions:
  vm-start   Start the 4 KB Ubuntu microVM on the remote Asahi host
  vm-stop    Stop the 4 KB Ubuntu microVM on the remote Asahi host
  vm-status  Show the current microVM state on the remote Asahi host
  restart    Restart the known-good Redroid container inside the 4 KB guest
  restart-preserve-data  Recreate the guest Redroid container without deleting its /data volume
  status     Show VM state, guest page size, and guest container status
  verify     Verify guest SSH plus host-visible ADB and VNC endpoints
  viewer     Launch the Guest4K viewer on the remote KDE desktop (default: TigerVNC, fallback: VIEWER_MODE=python)
  douyin-install   Install the staged Douyin APK onto the Guest4K runtime
  douyin-start     Force-stop and launch Douyin on the Guest4K runtime
  douyin-diagnose  Print Guest4K Douyin app, audio, and filtered log surfaces
  audio-diagnose   Print Guest4K guest ALSA, Android audio, and host PipeWire surfaces
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_sudo_pass() {
  if (( DRY_RUN )); then
    return 0
  fi

  if [[ -z "${SUDO_PASS}" ]]; then
    printf 'SUDO_PASS is required for guest sudo commands.\n' >&2
    return 1
  fi
}

require_local_file() {
  local path="$1"
  local label="$2"

  if [[ ! -f "${path}" ]]; then
    printf 'Missing %s: %s\n' "${label}" "${path}" >&2
    return 1
  fi
}

require_supported_graphics_profile() {
  case "${GRAPHICS_PROFILE}" in
    guest-all-dri|guest-vkms)
      ;;
    *)
      printf 'Unsupported GRAPHICS_PROFILE: %s\n' "${GRAPHICS_PROFILE}" >&2
      return 1
      ;;
  esac
}

require_supported_viewer_mode() {
  case "${VIEWER_MODE}" in
    vnc|python)
      ;;
    *)
      printf 'Unsupported VIEWER_MODE: %s\n' "${VIEWER_MODE}" >&2
      return 1
      ;;
  esac
}

run_local() {
  local cmd="$1"

  if (( DRY_RUN )); then
    printf 'DRY-RUN local: %s\n' "$cmd"
    return 0
  fi

  eval "$cmd"
}

run_remote() {
  local cmd="$1"
  local ssh_cmd="ssh -o StrictHostKeyChecking=no ${REMOTE_SSH_TARGET} ${(qqq)cmd}"

  if (( DRY_RUN )); then
    printf 'DRY-RUN ssh: %s\n' "${REMOTE_SSH_TARGET}"
    printf 'DRY-RUN remote: %s\n' "$cmd"
    return 0
  fi

  run_local "$ssh_cmd"
}

run_remote_capture() {
  local cmd="$1"

  if (( DRY_RUN )); then
    printf 'DRY-RUN ssh: %s\n' "${REMOTE_SSH_TARGET}"
    printf 'DRY-RUN remote: %s\n' "$cmd"
    return 0
  fi

  ssh -o StrictHostKeyChecking=no "${REMOTE_SSH_TARGET}" "$cmd"
}

guest_ssh_transport_cmd() {
  if [[ -n "${GUEST_SSH_PASSWORD}" ]]; then
    printf "sshpass -p %q ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 -p %q %q@127.0.0.1" \
      "${GUEST_SSH_PASSWORD}" "${GUEST_SSH_PORT}" "${GUEST_USER}"
  else
    printf "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=5 -i %q -p %q %q@127.0.0.1" \
      "${GUEST_SSH_KEY}" "${GUEST_SSH_PORT}" "${GUEST_USER}"
  fi
}

log_guest_ssh_mode() {
  if [[ -n "${GUEST_SSH_PASSWORD}" ]]; then
    printf 'DRY-RUN guest ssh: %s@127.0.0.1:%s using password auth\n' "${GUEST_USER}" "${GUEST_SSH_PORT}"
  else
    printf 'DRY-RUN guest ssh: %s@127.0.0.1:%s using %s\n' "${GUEST_USER}" "${GUEST_SSH_PORT}" "${GUEST_SSH_KEY}"
  fi
}

run_guest() {
  local cmd="$1"
  local guest_ssh_cmd="$(guest_ssh_transport_cmd) ${(qqq)cmd}"

  if (( DRY_RUN )); then
    printf 'DRY-RUN host ssh: %s\n' "${REMOTE_SSH_TARGET}"
    log_guest_ssh_mode
    printf 'DRY-RUN guest: %s\n' "$cmd"
    return 0
  fi

  run_remote "$guest_ssh_cmd"
}

run_guest_capture() {
  local cmd="$1"
  local guest_ssh_cmd="$(guest_ssh_transport_cmd) ${(qqq)cmd}"

  if (( DRY_RUN )); then
    printf 'DRY-RUN host ssh: %s\n' "${REMOTE_SSH_TARGET}"
    log_guest_ssh_mode
    printf 'DRY-RUN guest: %s\n' "$cmd"
    return 0
  fi

  run_remote_capture "$guest_ssh_cmd"
}

run_guest_sudo() {
  local cmd="$1"
  local wrapped

  require_sudo_pass

  if (( DRY_RUN )); then
    printf 'DRY-RUN host ssh: %s\n' "${REMOTE_SSH_TARGET}"
    log_guest_ssh_mode
    printf 'DRY-RUN guest sudo: %s\n' "$cmd"
    return 0
  fi

  wrapped=$(printf "printf '%%s\\n' %q | sudo -S -p '' sh -lc %q" "${SUDO_PASS}" "${cmd}")
  run_guest "${wrapped}"
}

run_guest_sudo_capture() {
  local cmd="$1"
  local wrapped

  require_sudo_pass

  if (( DRY_RUN )); then
    printf 'DRY-RUN host ssh: %s\n' "${REMOTE_SSH_TARGET}"
    log_guest_ssh_mode
    printf 'DRY-RUN guest sudo: %s\n' "$cmd"
    return 0
  fi

  wrapped=$(printf "printf '%%s\\n' %q | sudo -S -p '' sh -lc %q" "${SUDO_PASS}" "${cmd}")
  run_guest_capture "${wrapped}"
}

remote_script_cmd() {
  local script_path="$1"
  local env_prefix="${2:-}"
  local script_dir="${script_path:h}"
  local script_name="${script_path:t}"

  if [[ -n "${env_prefix}" ]]; then
    printf 'cd %s && %s./%s' "${(qqq)script_dir}" "${env_prefix}" "${script_name}"
  else
    printf 'cd %s && ./%s' "${(qqq)script_dir}" "${script_name}"
  fi
}

vm_launch_env_prefix() {
  local env_prefix=""

  if [[ -n "${VM_PIPEWIRE_QUANTUM}" ]]; then
    env_prefix+="PIPEWIRE_QUANTUM=${(q)VM_PIPEWIRE_QUANTUM} "
  fi

  if [[ -n "${VM_PIPEWIRE_LATENCY}" ]]; then
    env_prefix+="PIPEWIRE_LATENCY=${(q)VM_PIPEWIRE_LATENCY} "
  fi

  if [[ -n "${VM_AUDIO_OUT_LATENCY_US}" ]]; then
    env_prefix+="QEMU_AUDIO_OUT_LATENCY_US=${(q)VM_AUDIO_OUT_LATENCY_US} "
  fi

  if [[ -n "${VM_AUDIO_TIMER_PERIOD_US}" ]]; then
    env_prefix+="QEMU_AUDIO_TIMER_PERIOD_US=${(q)VM_AUDIO_TIMER_PERIOD_US} "
  fi

  if [[ -n "${VM_AUDIO_OUT_MIXING_ENGINE}" ]]; then
    env_prefix+="QEMU_AUDIO_OUT_MIXING_ENGINE=${(q)VM_AUDIO_OUT_MIXING_ENGINE} "
  fi

  if [[ -n "${VM_AUDIO_OUT_FIXED_SETTINGS}" ]]; then
    env_prefix+="QEMU_AUDIO_OUT_FIXED_SETTINGS=${(q)VM_AUDIO_OUT_FIXED_SETTINGS} "
  fi

  if [[ -n "${VM_QEMU_SMP}" ]]; then
    env_prefix+="QEMU_SMP=${(q)VM_QEMU_SMP} "
  fi

  printf '%s' "${env_prefix}"
}

sync_local_file_to_remote() {
  local local_path="$1"
  local remote_path="$2"
  local remote_target="${REMOTE_SSH_TARGET}:${remote_path}"
  local scp_cmd="scp -o StrictHostKeyChecking=no ${(qqq)local_path} ${(qqq)remote_target}"

  run_local "$scp_cmd"
}

vm_start() {
  log "starting 4 KB microVM from ${VM_LAUNCH_SCRIPT:h}"
  run_remote "$(remote_script_cmd "${VM_LAUNCH_SCRIPT}" "$(vm_launch_env_prefix)")"
}

vm_stop() {
  log "stopping 4 KB microVM from ${VM_STOP_SCRIPT:h}"
  run_remote "$(remote_script_cmd "${VM_STOP_SCRIPT}")"
}

vm_status() {
  log "showing 4 KB microVM status from ${VM_STATUS_SCRIPT:h}"
  run_remote "$(remote_script_cmd "${VM_STATUS_SCRIPT}")"
}

wait_for_guest_ssh() {
  local wait_cmd
  local guest_probe_cmd

  guest_probe_cmd="$(guest_ssh_transport_cmd) 'echo guest-ssh-ok'"
  wait_cmd=$(cat <<EOF
for _ in \$(seq 1 30); do
  if ${guest_probe_cmd} >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done
echo "Timed out waiting for guest SSH on 127.0.0.1:${GUEST_SSH_PORT}" >&2
exit 1
EOF
)

  log "waiting for guest SSH on 127.0.0.1:${GUEST_SSH_PORT}"
  run_remote "bash -lc ${(qqq)wait_cmd}"
}

connect_adb() {
  local cmd

  cmd=$(cat <<EOF
adb disconnect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb connect ${ADB_SERIAL}
adb devices
EOF
)

  log "connecting adb to ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)cmd}"
}

wait_for_boot() {
  local wait_cmd
  local vnc_probe_cmd

  vnc_probe_cmd="$(vnc_banner_probe_cmd)"

  wait_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
deadline=\$((\$(date +%s) + 120))
while [ \$(date +%s) -lt "\$deadline" ]; do
  boot=\$(timeout 5 adb -s ${ADB_SERIAL} shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  if [ "\$boot" = "1" ] && bash -lc ${(qqq)vnc_probe_cmd} >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done
echo "Timed out waiting for Android boot on ${ADB_SERIAL}" >&2
exit 1
EOF
)

  log "waiting for Android boot and VNC banner on ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)wait_cmd}"
}

ensure_android_ready() {
  wait_for_guest_ssh
  connect_adb
  wait_for_boot
  recover_host_audio_stream
}

vnc_banner_probe_cmd() {
  cat <<EOF
python3 - <<'PY'
import socket
import sys

s = socket.create_connection(("${VNC_HOST}", ${VNC_PORT}), timeout=5)
banner = s.recv(32)
s.close()
print(banner.decode("ascii", "replace").strip())
if not banner.startswith(b"RFB"):
    sys.exit(1)
PY
EOF
}

pipewire_qemu_node_probe_cmd() {
  cat <<'EOF'
qemu_node_id=$(
  pw-cli ls Node 2>/dev/null | awk '
    /^[[:space:]]*id [0-9]+, type PipeWire:Interface:Node\/3/ {
      id=$2
      sub(/,/, "", id)
    }
    /node.name = "qemu-system-aarch64"/ {
      print id
      exit
    }
  '
)
if [ -n "${qemu_node_id}" ]; then
  pw-cli info "${qemu_node_id}" 2>/dev/null || true
else
  echo 'no qemu pipewire node'
fi
EOF
}

host_qemu_sink_input_recover_cmd() {
  cat <<EOF
qemu_sink_input_id=\$(
  pactl list sink-inputs 2>/dev/null | awk '
    BEGIN { RS=""; FS="\\n" }
    /media.name = "audio0"/ || /node.name = "qemu-system-aarch64"/ {
      for (i = 1; i <= NF; i++) {
        if (\$i ~ /^Sink Input #[0-9]+/) {
          sub(/^Sink Input #/, "", \$i)
          print \$i
          exit
        }
        if (\$i ~ /^信宿输入 #[0-9]+/) {
          sub(/^信宿输入 #/, "", \$i)
          print \$i
          exit
        }
      }
    }
  '
)
if [ -n "\${qemu_sink_input_id}" ]; then
  if [ "${HOST_AUDIO_MOVE_TO_TARGET}" = "1" ]; then
    target_sink="${HOST_AUDIO_TARGET_SINK}"
    if [ -z "\${target_sink}" ]; then
      target_sink=\$(LC_ALL=C pactl info 2>/dev/null | awk -F': ' '/^Default Sink: / { print \$2; exit }')
    fi
    target_sink_id=''
    if [ -n "\${target_sink}" ]; then
      if printf '%s' "\${target_sink}" | grep -Eq '^[0-9]+\$'; then
        target_sink_id="\${target_sink}"
      else
        target_sink_id=\$(pactl list short sinks 2>/dev/null | awk -v sink="\${target_sink}" '\$2 == sink { print \$1; exit }')
      fi
    fi
    if [ -n "\${target_sink_id}" ]; then
      pactl move-sink-input "\${qemu_sink_input_id}" "\${target_sink_id}" >/dev/null 2>&1 || true
    fi
  fi
  pactl set-sink-input-mute "\${qemu_sink_input_id}" 0 >/dev/null 2>&1 || true
  pactl set-sink-input-volume "\${qemu_sink_input_id}" "${HOST_AUDIO_SINK_INPUT_VOLUME}" >/dev/null 2>&1 || true
  current_sink_id=\$(pactl list short sink-inputs 2>/dev/null | awk -v id="\${qemu_sink_input_id}" '\$1 == id { print \$2; exit }')
  echo "host-audio-recovered:\${qemu_sink_input_id}:${HOST_AUDIO_SINK_INPUT_VOLUME}:sink=\${current_sink_id:-unknown}"
else
  echo 'host-audio-recovered:missing'
fi
EOF
}

recover_host_audio_stream() {
  local recover_cmd

  recover_cmd="$(host_qemu_sink_input_recover_cmd)"
  log "recovering host PipeWire state for qemu audio stream"
  run_remote "bash -lc ${(qqq)recover_cmd}"
}

graphics_prepare_cmd() {
  case "${GRAPHICS_PROFILE}" in
    guest-all-dri)
      cat <<EOF
mkdir -p ${GUEST_DRI_RULE_PATH:h}
cat > ${GUEST_DRI_RULE_PATH} <<'RULE'
SUBSYSTEM=="drm", KERNEL=="card0", MODE="0666"
RULE
udevadm control --reload >/dev/null 2>&1 || true
udevadm trigger ${GUEST_DRI_CARD_NODE} >/dev/null 2>&1 || true
chmod 666 ${GUEST_DRI_CARD_NODE} >/dev/null 2>&1 || true
EOF
      ;;
    guest-vkms)
      cat <<EOF
modprobe vkms >/dev/null 2>&1 || true
chmod 666 ${VKMS_CARD_NODE} >/dev/null 2>&1 || true
EOF
      ;;
  esac
}

graphics_mount_args() {
  case "${GRAPHICS_PROFILE}" in
    guest-all-dri)
      cat <<EOF
  -v /dev/dri:/dev/dri \\
EOF
      ;;
    guest-vkms)
      cat <<EOF
  -v ${VKMS_CARD_NODE}:/dev/dri/card0 \\
  -v ${VKMS_CARD_NODE}:/dev/dri/renderD128 \\
  -v /dev/null:/dev/dri/card1 \\
  -v /dev/null:/dev/dri/card2 \\
  -v /dev/null:/dev/dri/card3 \\
  -v /dev/null:/dev/dri/card4 \\
  -v /dev/null:/dev/dri/renderD129 \\
EOF
      ;;
  esac
}

audio_prepare_cmd() {
  cat <<EOF
mkdir -p ${GUEST_SND_RULE_PATH:h}
cat > ${GUEST_SND_RULE_PATH} <<'RULE'
SUBSYSTEM=="sound", GROUP="${ANDROID_AUDIO_GID}", MODE="0660"
RULE
udevadm control --reload >/dev/null 2>&1 || true
udevadm trigger --subsystem-match=sound >/dev/null 2>&1 || true
chgrp -R ${ANDROID_AUDIO_GID} /dev/snd >/dev/null 2>&1 || true
chmod 660 /dev/snd/* >/dev/null 2>&1 || true
EOF
}

restart_redroid() {
  local preserve_data="${1:-0}"
  local guest_cmd
  local graphics_prep_cmd
  local graphics_mounts
  local audio_prep_cmd
  local volume_reset_cmd="podman volume rm -f ${VOLUME_NAME} >/dev/null 2>&1 || true"

  require_supported_graphics_profile
  vm_start
  wait_for_guest_ssh
  graphics_prep_cmd="$(graphics_prepare_cmd)"
  graphics_mounts="$(graphics_mount_args)"
  audio_prep_cmd="$(audio_prepare_cmd)"
  if [[ "${preserve_data}" == "1" ]]; then
    volume_reset_cmd=":"
  fi

  guest_cmd=$(cat <<EOF
set -euo pipefail
setenforce 0 || true
for legacy_container in ${LEGACY_GUEST_CONTAINERS}; do
  podman rm -f "\${legacy_container}" >/dev/null 2>&1 || true
  podman volume rm -f "\${legacy_container}-data" >/dev/null 2>&1 || true
done
podman rm -f ${CONTAINER} >/dev/null 2>&1 || true
${volume_reset_cmd}
mkdir -p /dev/binderfs
mountpoint -q /dev/binderfs || mount -t binder binder /dev/binderfs
chmod 666 /dev/binderfs/* || true
${graphics_prep_cmd}
${audio_prep_cmd}
podman run -d --name ${CONTAINER} --pull=never --privileged --security-opt label=disable --security-opt unmask=all \\
  -p 5555:5555/tcp -p 5900:5900/tcp \\
  -v ${VOLUME_NAME}:/data \\
${graphics_mounts}
  -v /dev/binderfs/binder:/dev/binder \\
  -v /dev/binderfs/hwbinder:/dev/hwbinder \\
  -v /dev/binderfs/vndbinder:/dev/vndbinder \\
  --entrypoint /init ${IMAGE} \\
  qemu=1 androidboot.hardware=redroid androidboot.use_redroid_vnc=${REDROID_VNC_BOOT} androidboot.redroid_gpu_mode=${REDROID_GPU_MODE} androidboot.redroid_gpu_node=${REDROID_GPU_NODE}
podman ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'
EOF
)

  log "graphics profile: ${GRAPHICS_PROFILE}"
  log "restarting guest Redroid container ${CONTAINER}"
  run_guest_sudo "${guest_cmd}"
  connect_adb
  wait_for_boot
  recover_host_audio_stream
}

show_status() {
  require_supported_graphics_profile
  log "showing VM status"
  vm_status

  log "showing guest page size"
  run_guest "getconf PAGE_SIZE"

  log "configured graphics profile: ${GRAPHICS_PROFILE}"
  log "showing guest container status"
  run_guest_sudo "podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
}

verify_runtime() {
  local guest_ssh_cmd
  local host_vnc_cmd
  local boot_cmd

  wait_for_guest_ssh

  guest_ssh_cmd=$(cat <<EOF
echo guest-ssh-ok
getconf PAGE_SIZE
EOF
)
  log "verifying guest SSH"
  run_guest "bash -lc ${(qqq)guest_ssh_cmd}"

  connect_adb
  wait_for_boot
  recover_host_audio_stream

  boot_cmd=$(cat <<EOF
timeout 5 adb -s ${ADB_SERIAL} shell getprop sys.boot_completed 2>&1
EOF
)
  log "verifying Android boot properties on ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)boot_cmd}"

  host_vnc_cmd="$(vnc_banner_probe_cmd)"
  log "verifying VNC banner on ${VNC_HOST}:${VNC_PORT}"
  run_remote "bash -lc ${(qqq)host_vnc_cmd}"
}

install_douyin() {
  local cmd

  ensure_android_ready

  if [[ -n "${LOCAL_DOUYIN_APK_PATH}" ]]; then
    if (( ! DRY_RUN )); then
      require_local_file "${LOCAL_DOUYIN_APK_PATH}" "local Douyin APK"
    fi
    log "staging Douyin APK to ${REMOTE_HOST}:${REMOTE_DOUYIN_APK_PATH}"
    sync_local_file_to_remote "${LOCAL_DOUYIN_APK_PATH}" "${REMOTE_DOUYIN_APK_PATH}"
  else
    log "using pre-staged Douyin APK at ${REMOTE_HOST}:${REMOTE_DOUYIN_APK_PATH}"
  fi

  cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} install -r ${REMOTE_DOUYIN_APK_PATH}
adb -s ${ADB_SERIAL} shell pm path ${DOUYIN_PACKAGE} 2>/dev/null || true
EOF
)

  log "installing Douyin from ${REMOTE_DOUYIN_APK_PATH}"
  run_remote "bash -lc ${(qqq)cmd}"
}

start_douyin() {
  local cmd

  ensure_android_ready

  cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell am force-stop ${DOUYIN_PACKAGE} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell am start -W -n ${DOUYIN_ACTIVITY}
sleep 2
adb -s ${ADB_SERIAL} shell pidof ${DOUYIN_PACKAGE} || true
adb -s ${ADB_SERIAL} shell dumpsys activity activities 2>/dev/null | grep -m 1 'topResumedActivity' || true
EOF
)

  log "starting Douyin via ${DOUYIN_ACTIVITY}"
  run_remote "bash -lc ${(qqq)cmd}"
}

diagnose_douyin() {
  local cmd

  ensure_android_ready

  cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
echo '=== package ==='
adb -s ${ADB_SERIAL} shell pm path ${DOUYIN_PACKAGE} 2>/dev/null || true
echo '=== pid ==='
adb -s ${ADB_SERIAL} shell pidof ${DOUYIN_PACKAGE} || true
echo '=== top ==='
sleep 2
adb -s ${ADB_SERIAL} shell dumpsys activity activities 2>/dev/null | grep -m 1 'topResumedActivity' || true
echo '=== audioflinger ==='
adb -s ${ADB_SERIAL} shell dumpsys media.audio_flinger 2>/dev/null | grep -E 'Output thread|Frames written|Standby|HAL format' | tail -n ${DOUYIN_AUDIO_STATUS_LINES} || true
echo '=== audio ==='
adb -s ${ADB_SERIAL} shell dumpsys audio 2>/dev/null | grep -E 'state:started|pack:|device:|speaker|AUDIO_OUTPUT_FLAG' | tail -n ${DOUYIN_AUDIO_STATUS_LINES} || true
echo '=== logcat ==='
adb -s ${ADB_SERIAL} shell logcat -d 2>/dev/null | grep -iE "${DOUYIN_LOGCAT_FILTER}" | tail -n ${DOUYIN_LOGCAT_LINES} || true
echo '=== host-pipewire ==='
pactl list sink-inputs short 2>/dev/null | grep -i qemu || echo 'no qemu sink-inputs'
EOF
)

  log "diagnosing Douyin runtime on ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)cmd}"
}

diagnose_audio() {
  local guest_cmd
  local host_cmd
  local pipewire_probe_cmd

  ensure_android_ready

  guest_cmd=$(cat <<'EOF'
echo '=== guest-dev-snd ==='
ls -l /dev/snd 2>/dev/null || true
echo '=== guest-asound-cards ==='
cat /proc/asound/cards 2>/dev/null || true
echo '=== guest-aplay ==='
aplay -l 2>&1 || true
EOF
)

  pipewire_probe_cmd="$(pipewire_qemu_node_probe_cmd)"
  host_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
echo '=== android-audioflinger ==='
adb -s ${ADB_SERIAL} shell dumpsys media.audio_flinger 2>/dev/null | grep -E 'Output thread|Frames written|Standby|HAL format' | tail -n ${DOUYIN_AUDIO_STATUS_LINES} || true
echo '=== android-audio ==='
adb -s ${ADB_SERIAL} shell dumpsys audio 2>/dev/null | grep -E 'state:started|pack:|device:|speaker|AUDIO_OUTPUT_FLAG|FormatInfo' | tail -n ${DOUYIN_AUDIO_STATUS_LINES} || true
echo '=== host-sink-inputs ==='
pactl list sink-inputs 2>/dev/null || true
echo '=== host-pw-cli-qemu-node ==='
${pipewire_probe_cmd}
EOF
)

  log "diagnosing Guest4K audio surfaces on ${ADB_SERIAL}"
  run_guest "bash -lc ${(qqq)guest_cmd}"
  run_remote "bash -lc ${(qqq)host_cmd}"
}

launch_viewer() {
  local display_env
  local kill_python_cmd
  local kill_screencap_cmd
  local kill_vnc_cmd
  local launch_cmd

  require_supported_viewer_mode
  display_env="XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* 2>/dev/null | head -1)"
  kill_python_cmd="pkill -f '/tmp/[r]edroid_viewer.py' 2>/dev/null || true"
  kill_screencap_cmd="pkill -f 'adb -s ${ADB_SERIAL} exec-out sh -c while true; do [s]creencap; done' 2>/dev/null || true"
  kill_vnc_cmd="pkill -f '[v]ncviewer .*${VNC_HOST}::${VNC_PORT}' 2>/dev/null || true"

  if [[ "${VIEWER_MODE}" = "python" ]]; then
    require_local_file "${LOCAL_VIEWER_PATH}" "local viewer helper"
    sync_local_file_to_remote "${LOCAL_VIEWER_PATH}" "${REMOTE_VIEWER_PATH}"
    launch_cmd="bash -lc \"export REDROID_VIEWER_ADB_SERIAL=${ADB_SERIAL} ${display_env}; nohup python3 ${REMOTE_VIEWER_PATH} > /tmp/redroid_guest4k_viewer.log 2>&1 < /dev/null &\""
  else
    launch_cmd="bash -lc \"export ${display_env}; nohup vncviewer ${VNC_HOST}::${VNC_PORT} > /tmp/redroid_guest4k_tigervnc.log 2>&1 < /dev/null &\""
  fi

  if (( DRY_RUN )); then
    run_remote_capture "${kill_python_cmd}"
    run_remote_capture "${kill_screencap_cmd}"
    run_remote_capture "${kill_vnc_cmd}"
    run_remote_capture "${launch_cmd}"
  else
    run_remote_capture "${kill_python_cmd}" >/dev/null
    run_remote_capture "${kill_screencap_cmd}" >/dev/null
    run_remote_capture "${kill_vnc_cmd}" >/dev/null
    run_remote_capture "${launch_cmd}" >/dev/null
  fi

  log "viewer launched on ${REMOTE_HOST} for ${ADB_SERIAL} using ${VIEWER_MODE}"
}

main() {
  local action=""

  while (( $# )); do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      vm-start|vm-stop|vm-status|restart|restart-preserve-data|status|verify|viewer|douyin-install|douyin-start|douyin-diagnose|audio-diagnose)
        action="$1"
        shift
        break
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "${action}" ]] || (( $# )); then
    usage >&2
    exit 1
  fi

  case "${action}" in
    vm-start)
      vm_start
      ;;
    vm-stop)
      vm_stop
      ;;
    vm-status)
      vm_status
      ;;
    restart)
      restart_redroid
      ;;
    restart-preserve-data)
      restart_redroid 1
      ;;
    status)
      show_status
      ;;
    verify)
      verify_runtime
      ;;
    viewer)
      launch_viewer
      ;;
    douyin-install)
      install_douyin
      ;;
    douyin-start)
      start_douyin
      ;;
    douyin-diagnose)
      diagnose_douyin
      ;;
    audio-diagnose)
      diagnose_audio
      ;;
  esac
}

main "$@"
