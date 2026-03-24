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
DEFAULT_IMAGE="${DEFAULT_IMAGE:-localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322}"
LEGACY_IMAGE="${LEGACY_IMAGE:-localhost/redroid4k-root:alsa-hal-ranchu-exp2}"
IMAGE="${IMAGE:-${DEFAULT_IMAGE}}"
CONTAINER="${CONTAINER:-redroid16kguestprobe}"
VOLUME_NAME="${VOLUME_NAME:-redroid16kguestprobe-data}"
VIRGL_SRCBUILD_IMAGE="${VIRGL_SRCBUILD_IMAGE:-${DEFAULT_IMAGE}}"
VIRGL_SRCBUILD_CONTROL_CONTAINER="${VIRGL_SRCBUILD_CONTROL_CONTAINER:-redroid16kguestprobe-virgl-renderable-gralloc4trace}"
VIRGL_SRCBUILD_PROBE_CONTAINER="${VIRGL_SRCBUILD_PROBE_CONTAINER:-redroid16kguestprobe-virgl-renderable-srcbuildgralloc}"
VIRGL_SRCBUILD_PROBE_SECONDS="${VIRGL_SRCBUILD_PROBE_SECONDS:-90}"
VIRGL_SRCBUILD_LONGRUN_CONTAINER="${VIRGL_SRCBUILD_LONGRUN_CONTAINER:-redroid16kguestprobe-virgl-renderable-srcbuildlongrun}"
VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS="${VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS:-30 60 120 180}"
VIRGL_SRCBUILD_ROLLOUT_CONTAINER="${VIRGL_SRCBUILD_ROLLOUT_CONTAINER:-redroid16kguestprobe-virgl-renderable-srcbuildrollout}"
VIRGL_SRCBUILD_ROLLOUT_RETRY_SECONDS="${VIRGL_SRCBUILD_ROLLOUT_RETRY_SECONDS:-30}"
VIRGL_SRCBUILD_IMPORT_IMAGE="${VIRGL_SRCBUILD_IMPORT_IMAGE:-localhost/redroid4k-root:virgl-srcbuild-imported}"
VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG="${VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG:-/home/wjq/redroid-artifacts/guest4k-srcbuild-import/system.img}"
VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG="${VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG:-/home/wjq/redroid-artifacts/guest4k-srcbuild-import/vendor.img}"
VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG="${VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG:-}"
VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG="${VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG:-}"
VIRGL_SRCBUILD_IMPORT_GUEST_DIR="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR:-/var/tmp/guest4k-srcbuild-import}"
VIRGL_SRCBUILD_IMPORT_COMPAT_REF_IMAGE="${VIRGL_SRCBUILD_IMPORT_COMPAT_REF_IMAGE:-}"
VIRGL_SRCBUILD_IMPORT_COMPAT_OVERLAY_FILES="${VIRGL_SRCBUILD_IMPORT_COMPAT_OVERLAY_FILES:-/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu /vendor/lib64/hw/gralloc.minigbm.so /vendor/lib64/hw/mapper.minigbm.so}"
VIRGL_FINGERPRINT_PROBE_CONTAINER="${VIRGL_FINGERPRINT_PROBE_CONTAINER:-redroid16kguestprobe-virgl-fingerprint-srcbuild}"
VIRGL_FINGERPRINT_SECONDS="${VIRGL_FINGERPRINT_SECONDS:-90}"
DOUYIN_PACKAGE="${DOUYIN_PACKAGE:-com.ss.android.ugc.aweme}"
DOUYIN_ACTIVITY="${DOUYIN_ACTIVITY:-com.ss.android.ugc.aweme/.splash.SplashActivity}"
LOCAL_DOUYIN_APK_PATH="${LOCAL_DOUYIN_APK_PATH:-}"
REMOTE_DOUYIN_APK_PATH="${REMOTE_DOUYIN_APK_PATH:-/tmp/douyin.apk}"
DOUYIN_AUDIO_STATUS_LINES="${DOUYIN_AUDIO_STATUS_LINES:-40}"
DOUYIN_LOGCAT_LINES="${DOUYIN_LOGCAT_LINES:-60}"
DOUYIN_LOGCAT_FILTER="${DOUYIN_LOGCAT_FILTER:-aweme|AudioFlinger|audio_hw_primary|android\\.hardware\\.audio|pcm|tinyalsa|libttmplayer|AndroidRuntime|FATAL EXCEPTION|crash}"
PERF_TOP_LINES="${PERF_TOP_LINES:-20}"
PERF_DISPLAY_LINES="${PERF_DISPLAY_LINES:-80}"
PERF_LOG_LINES="${PERF_LOG_LINES:-120}"
LEGACY_GUEST_CONTAINERS="${LEGACY_GUEST_CONTAINERS:-redroid16kbridgeprobe}"
VIEWER_MODE="${VIEWER_MODE:-vnc}"
GUEST4K_PERF_PRESET="${GUEST4K_PERF_PRESET:-powersave}"
GUEST4K_TIGERVNC_PROFILE="${GUEST4K_TIGERVNC_PROFILE:-}"
GUEST4K_TIGERVNC_FLAGS="${GUEST4K_TIGERVNC_FLAGS:-}"
LOCAL_VIEWER_PATH="${LOCAL_VIEWER_PATH:-${REPO_ROOT}/redroid/tools/redroid_viewer.py}"
REMOTE_VIEWER_PATH="${REMOTE_VIEWER_PATH:-/tmp/redroid_viewer.py}"
LOCAL_PHONE_PROFILE_PATH="${LOCAL_PHONE_PROFILE_PATH:-${REPO_ROOT}/redroid/profiles/china-phone.env}"
REMOTE_PHONE_PROFILE_DIR="${REMOTE_PHONE_PROFILE_DIR:-/tmp/redroid-phone-profile}"
REMOTE_PHONE_SYSTEM_PROP="${REMOTE_PHONE_SYSTEM_PROP:-${REMOTE_PHONE_PROFILE_DIR}/system.build.prop}"
REMOTE_PHONE_VENDOR_PROP="${REMOTE_PHONE_VENDOR_PROP:-${REMOTE_PHONE_PROFILE_DIR}/vendor.build.prop}"
REMOTE_PHONE_XBIN_DIR="${REMOTE_PHONE_XBIN_DIR:-${REMOTE_PHONE_PROFILE_DIR}/system_xbin}"
REMOTE_PHONE_ADB_KEYS="${REMOTE_PHONE_ADB_KEYS:-${REMOTE_PHONE_PROFILE_DIR}/adb_keys}"
REMOTE_ADB_KEY_SOURCE="${REMOTE_ADB_KEY_SOURCE:-/home/${REMOTE_USER}/.android/adbkey.pub}"
GUEST_PHONE_ADB_KEY_STAGE="${GUEST_PHONE_ADB_KEY_STAGE:-/tmp/redroid-phone-host-adbkey.pub}"
GRAPHICS_PROFILE="${GRAPHICS_PROFILE:-guest-all-dri}"
VKMS_CARD_NODE="${VKMS_CARD_NODE:-/dev/dri/card1}"
GUEST_DRI_CARD_NODE="${GUEST_DRI_CARD_NODE:-/dev/dri/card0}"
GUEST_DRI_RULE_PATH="${GUEST_DRI_RULE_PATH:-/etc/udev/rules.d/99-redroid-dri.rules}"
GUEST_SND_RULE_PATH="${GUEST_SND_RULE_PATH:-/etc/udev/rules.d/99-redroid-snd.rules}"
ANDROID_AUDIO_GID="${ANDROID_AUDIO_GID:-1005}"
REDROID_GPU_MODE="${REDROID_GPU_MODE:-guest}"
REDROID_GPU_NODE="${REDROID_GPU_NODE:-/dev/dri/card0}"
REDROID_VNC_BOOT="${REDROID_VNC_BOOT:-1}"
REDROID_BOOT_HARDWARE_EGL="${REDROID_BOOT_HARDWARE_EGL:-}"
REDROID_BOOT_HARDWARE_VULKAN="${REDROID_BOOT_HARDWARE_VULKAN:-}"
REDROID_BOOT_CPU_VULKAN_VERSION="${REDROID_BOOT_CPU_VULKAN_VERSION:-}"
REDROID_BOOT_OPENGLES_VERSION="${REDROID_BOOT_OPENGLES_VERSION:-}"
REDROID_BOOT_DEBUG_HWUI_RENDERER="${REDROID_BOOT_DEBUG_HWUI_RENDERER:-}"
REDROID_BOOT_DEBUG_RENDERENGINE_BACKEND="${REDROID_BOOT_DEBUG_RENDERENGINE_BACKEND:-}"
GUEST4K_DRM_REFRESH_PROFILE="${GUEST4K_DRM_REFRESH_PROFILE:-}"
GUEST4K_ANDROID_DISPLAY_PROFILE="${GUEST4K_ANDROID_DISPLAY_PROFILE:-}"
REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP="${REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP:-}"
REDROID_BOOT_USE_DMABUFHEAPS="${REDROID_BOOT_USE_DMABUFHEAPS:-auto}"
DRY_RUN=0

if [[ ! -f "${LOCAL_PHONE_PROFILE_PATH}" ]]; then
  printf 'Missing phone profile: %s\n' "${LOCAL_PHONE_PROFILE_PATH}" >&2
  exit 1
fi

source "${LOCAL_PHONE_PROFILE_PATH}"

usage() {
  cat <<'EOF'
Usage: zsh redroid/scripts/redroid_guest4k_107.sh [--dry-run] <vm-start|vm-stop|vm-status|restart|restart-preserve-data|phone-mode|restart-legacy|restart-legacy-preserve-data|status|verify|viewer|douyin-install|douyin-start|douyin-diagnose|audio-diagnose|perf-diagnose|virgl-srcbuild-probe|virgl-srcbuild-longrun|virgl-srcbuild-import|virgl-srcbuild-rollout|virgl-srcbuild-rollback|virgl-fingerprint-compare>

Actions:
  vm-start   Start the 4 KB Ubuntu microVM on the remote Asahi host
  vm-stop    Stop the 4 KB Ubuntu microVM on the remote Asahi host
  vm-status  Show the current microVM state on the remote Asahi host
  restart    Restart the default virgl-srcbuild Redroid container inside the 4 KB guest
  restart-preserve-data  Recreate the default virgl-srcbuild guest Redroid container without deleting its /data volume
  phone-mode  Restart the default virgl-srcbuild guest Redroid runtime with a phone-like China persona surface
  restart-legacy  Restart the legacy alsa-hal-ranchu-exp2 Redroid container inside the 4 KB guest
  restart-legacy-preserve-data  Recreate the legacy guest Redroid container without deleting its /data volume
  status     Show VM state, guest page size, and guest container status
  verify     Verify guest SSH plus host-visible ADB and VNC endpoints
  viewer     Launch the Guest4K viewer on the remote KDE desktop (default: TigerVNC adaptive under the default powersave preset, lossless via GUEST4K_TIGERVNC_PROFILE=lossless, fallback: VIEWER_MODE=python)
  douyin-install   Install the staged Douyin APK onto the Guest4K runtime
  douyin-start     Force-stop and launch Douyin on the Guest4K runtime
  douyin-diagnose  Print Guest4K Douyin app, audio, and filtered log surfaces
  audio-diagnose   Print Guest4K guest ALSA, Android audio, and host PipeWire surfaces
  perf-diagnose    Print Guest4K host/guest CPU, display, codec, and filtered graphics/video logs
  virgl-srcbuild-probe  Run the bounded source-consistent virgl probe in a portless temporary runtime with bounded mainline handoff
  virgl-srcbuild-longrun  Run the source-consistent virgl long-run probe in a portless temporary runtime with periodic checkpoints and bounded mainline handoff
  virgl-srcbuild-import  Import a staged Guest4K system/vendor image pair into a new guest-rootful Podman image tag
  virgl-srcbuild-rollout  Roll out the source-consistent virgl image onto the standard path with explicit rollback support
  virgl-srcbuild-rollback  Restore the preserved virgl control container after a source-consistent rollout attempt
  virgl-fingerprint-compare  Compare control-vs-probe virgl runtime fingerprints with sequential portless temporary runtimes under bounded mainline handoff
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

validate_local_virgl_import_payload() {
  local has_local_system=0
  local has_local_vendor=0

  if [[ -n "${VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG}" ]]; then
    has_local_system=1
  fi
  if [[ -n "${VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG}" ]]; then
    has_local_vendor=1
  fi

  if (( has_local_system != has_local_vendor )); then
    printf 'VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG and VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG must be set together.\n' >&2
    return 1
  fi

  if (( has_local_system )) && (( ! DRY_RUN )); then
    require_local_file "${VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG}" "local virgl import system image"
    require_local_file "${VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG}" "local virgl import vendor image"
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

require_supported_perf_preset() {
  case "${GUEST4K_PERF_PRESET}" in
    balanced|lowcpu|powersave|'')
      ;;
    *)
      printf 'Unsupported GUEST4K_PERF_PRESET: %s\n' "${GUEST4K_PERF_PRESET}" >&2
      return 1
      ;;
  esac
}

require_supported_tigervnc_profile() {
  case "${GUEST4K_TIGERVNC_PROFILE}" in
    lossless|adaptive|'')
      ;;
    *)
      printf 'Unsupported GUEST4K_TIGERVNC_PROFILE: %s\n' "${GUEST4K_TIGERVNC_PROFILE}" >&2
      return 1
      ;;
  esac
}

require_supported_android_display_profile() {
  case "${GUEST4K_ANDROID_DISPLAY_PROFILE}" in
    native|lowcpu|powersave|playback|streaming|'')
      ;;
    *)
      printf 'Unsupported GUEST4K_ANDROID_DISPLAY_PROFILE: %s\n' "${GUEST4K_ANDROID_DISPLAY_PROFILE}" >&2
      return 1
      ;;
  esac
}

redroid_vnc_boot_enabled() {
  [[ "${REDROID_VNC_BOOT}" != "0" ]]
}

apply_perf_preset_defaults() {
  local preset_android_display_profile
  local preset_drm_refresh_profile
  local preset_tigervnc_profile

  require_supported_perf_preset

  case "${GUEST4K_PERF_PRESET}" in
    balanced|'')
      preset_android_display_profile="native"
      preset_drm_refresh_profile="balanced"
      preset_tigervnc_profile="lossless"
      ;;
    lowcpu)
      preset_android_display_profile="lowcpu"
      preset_drm_refresh_profile="lowcpu"
      preset_tigervnc_profile="adaptive"
      ;;
    powersave)
      preset_android_display_profile="powersave"
      preset_drm_refresh_profile="powersave"
      preset_tigervnc_profile="adaptive"
      ;;
  esac

  if [[ -z "${GUEST4K_ANDROID_DISPLAY_PROFILE}" ]]; then
    GUEST4K_ANDROID_DISPLAY_PROFILE="${preset_android_display_profile}"
  fi
  if [[ -z "${GUEST4K_DRM_REFRESH_PROFILE}" ]]; then
    GUEST4K_DRM_REFRESH_PROFILE="${preset_drm_refresh_profile}"
  fi
  if [[ -z "${GUEST4K_TIGERVNC_PROFILE}" ]]; then
    GUEST4K_TIGERVNC_PROFILE="${preset_tigervnc_profile}"
  fi
}

resolve_qemu_scanout_size() {
  require_supported_android_display_profile

  case "${GUEST4K_ANDROID_DISPLAY_PROFILE}" in
    native|'')
      printf '800 1280'
      ;;
    lowcpu)
      printf '720 1152'
      ;;
    powersave)
      printf '640 1024'
      ;;
    playback)
      printf '540 864'
      ;;
    streaming)
      printf '480 768'
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
  local ssh_cmd="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR ${REMOTE_SSH_TARGET} ${(qqq)cmd}"

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

  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR "${REMOTE_SSH_TARGET}" "$cmd"
}

guest_ssh_transport_cmd() {
  if [[ -n "${GUEST_SSH_PASSWORD}" ]]; then
    printf "sshpass -p %q ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 -p %q %q@127.0.0.1" \
      "${GUEST_SSH_PASSWORD}" "${GUEST_SSH_PORT}" "${GUEST_USER}"
  else
    printf "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -i %q -p %q %q@127.0.0.1" \
      "${GUEST_SSH_KEY}" "${GUEST_SSH_PORT}" "${GUEST_USER}"
  fi
}

guest_scp_transport_cmd() {
  if [[ -n "${GUEST_SSH_PASSWORD}" ]]; then
    printf "sshpass -p %q scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 -P %q" \
      "${GUEST_SSH_PASSWORD}" "${GUEST_SSH_PORT}"
  else
    printf "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -i %q -P %q" \
      "${GUEST_SSH_KEY}" "${GUEST_SSH_PORT}"
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
  local -a qemu_scanout_size

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

  qemu_scanout_size=("${(@s: :)$(resolve_qemu_scanout_size)}")
  env_prefix+="QEMU_XRES=${(q)qemu_scanout_size[1]} "
  env_prefix+="QEMU_YRES=${(q)qemu_scanout_size[2]} "

  printf '%s' "${env_prefix}"
}

sync_local_file_to_remote() {
  local local_path="$1"
  local remote_path="$2"
  local remote_target="${REMOTE_SSH_TARGET}:${remote_path}"
  local scp_cmd="scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR ${(qqq)local_path} ${(qqq)remote_target}"

  run_local "$scp_cmd"
}

stage_local_virgl_import_payload_to_remote() {
  local remote_system_dir="${VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG:h}"
  local remote_vendor_dir="${VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG:h}"
  local remote_mkdir_cmd="mkdir -p ${(qqq)remote_system_dir}"

  validate_local_virgl_import_payload

  if [[ -z "${VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG}" ]]; then
    return 0
  fi

  if [[ "${remote_vendor_dir}" != "${remote_system_dir}" ]]; then
    remote_mkdir_cmd+=" ${(qqq)remote_vendor_dir}"
  fi

  log "staging local Guest4K images onto ${REMOTE_HOST}"
  run_remote "${remote_mkdir_cmd}"
  sync_local_file_to_remote "${VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG}" "${VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG}"
  sync_local_file_to_remote "${VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG}" "${VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG}"
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
deadline=\$((\$(date +%s) + 30))
last_state=unknown
while [ \$(date +%s) -lt "\$deadline" ]; do
  adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
  state=\$(timeout 5 adb -s ${ADB_SERIAL} get-state 2>/dev/null | tr -d '\r')
  if [ -n "\$state" ]; then
    last_state="\$state"
  fi
  if [ "\$state" = "device" ]; then
    printf 'ADB_READY %s %s\n' '${ADB_SERIAL}' "\$state"
    exit 0
  fi
  sleep 2
done
echo "Timed out waiting for adb device state on ${ADB_SERIAL}; last_state=\${last_state}" >&2
exit 1
EOF
)

  log "connecting adb to ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)cmd}"
}

wait_for_boot() {
  local wait_cmd
  local vnc_probe_cmd

  if redroid_vnc_boot_enabled; then
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
  else
    wait_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
deadline=\$((\$(date +%s) + 120))
while [ \$(date +%s) -lt "\$deadline" ]; do
  boot=\$(timeout 5 adb -s ${ADB_SERIAL} shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  if [ "\$boot" = "1" ]; then
    exit 0
  fi
  sleep 2
done
echo "Timed out waiting for Android boot on ${ADB_SERIAL}" >&2
exit 1
EOF
)

    log "waiting for Android boot on ${ADB_SERIAL}"
  fi

  run_remote "bash -lc ${(qqq)wait_cmd}"
}

normalize_android_display_cmd() {
  cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
profile="${GUEST4K_ANDROID_DISPLAY_PROFILE}"
adb -s ${ADB_SERIAL} shell wm size reset >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell wm density reset >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell settings delete global display_size_forced >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell settings delete secure display_density_forced >/dev/null 2>&1 || true
resolve_default_density() {
  default_density=\$(adb -s ${ADB_SERIAL} shell wm density 2>/dev/null | tr -d '\r' | sed -n 's/.*Physical density: \\([0-9][0-9]*\\).*/\\1/p' | head -n 1)
  if ! printf '%s' "\${default_density}" | grep -Eq '^[0-9]+$'; then
    default_density=\$(adb -s ${ADB_SERIAL} shell getprop ro.sf.lcd_density 2>/dev/null | tr -d '\r' | sed -n '1s/[^0-9].*$//p')
  fi
  if ! printf '%s' "\${default_density}" | grep -Eq '^[0-9]+$'; then
    default_density=320
  fi
}
case "\${profile}" in
  native|'')
    ;;
  lowcpu)
    resolve_default_density
    target_density=\$((default_density * 90 / 100))
    adb -s ${ADB_SERIAL} shell wm size 720x1152 >/dev/null 2>&1 || true
    adb -s ${ADB_SERIAL} shell wm density "\${target_density}" >/dev/null 2>&1 || true
    ;;
  powersave)
    resolve_default_density
    target_density=\$((default_density * 80 / 100))
    adb -s ${ADB_SERIAL} shell wm size 640x1024 >/dev/null 2>&1 || true
    adb -s ${ADB_SERIAL} shell wm density "\${target_density}" >/dev/null 2>&1 || true
    ;;
  playback)
    resolve_default_density
    target_density=\$((default_density * 27 / 40))
    adb -s ${ADB_SERIAL} shell wm size 540x864 >/dev/null 2>&1 || true
    adb -s ${ADB_SERIAL} shell wm density "\${target_density}" >/dev/null 2>&1 || true
    ;;
  streaming)
    resolve_default_density
    target_density=\$((default_density * 3 / 5))
    adb -s ${ADB_SERIAL} shell wm size 480x768 >/dev/null 2>&1 || true
    adb -s ${ADB_SERIAL} shell wm density "\${target_density}" >/dev/null 2>&1 || true
    ;;
esac
adb -s ${ADB_SERIAL} shell wm size 2>/dev/null || true
adb -s ${ADB_SERIAL} shell wm density 2>/dev/null || true
EOF
}

normalize_android_display() {
  local cmd

  require_supported_android_display_profile
  cmd="$(normalize_android_display_cmd)"
  log "applying Android display profile ${GUEST4K_ANDROID_DISPLAY_PROFILE} on ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)cmd}"
}

repair_guest_vnc_after_surfaceflinger_restart_cmd() {
  local banner_probe_cmd

  banner_probe_cmd="$(vnc_banner_probe_cmd)"
  cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
vnc_boottime=\$(adb -s ${ADB_SERIAL} shell getprop ro.boottime.vncserver 2>/dev/null | tr -d '\r')
sf_boottime=\$(adb -s ${ADB_SERIAL} shell getprop ro.boottime.surfaceflinger 2>/dev/null | tr -d '\r')
if printf '%s' "\${vnc_boottime}" | grep -Eq '^[0-9]+\$' && printf '%s' "\${sf_boottime}" | grep -Eq '^[0-9]+\$' && [ "\${vnc_boottime}" -lt "\${sf_boottime}" ]; then
  adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
  sleep 1
  adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
  adb -s ${ADB_SERIAL} shell stop vncserver >/dev/null 2>&1 || true
  sleep 1
  adb -s ${ADB_SERIAL} shell start vncserver >/dev/null 2>&1 || true
  deadline=\$((\$(date +%s) + 15))
  while [ \$(date +%s) -lt "\${deadline}" ]; do
    vnc_state=\$(adb -s ${ADB_SERIAL} shell getprop init.svc.vncserver 2>/dev/null | tr -d '\r')
    if [ "\${vnc_state}" = "running" ] && bash -lc ${(qqq)banner_probe_cmd} >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi
EOF
}

repair_guest_vnc_after_surfaceflinger_restart() {
  local cmd

  if ! redroid_vnc_boot_enabled; then
    return 0
  fi

  cmd="$(repair_guest_vnc_after_surfaceflinger_restart_cmd)"
  log "repairing guest VNC if surfaceflinger restarted after vncserver"
  run_remote "bash -lc ${(qqq)cmd}"
}

post_boot_prepare() {
  normalize_android_display
  repair_guest_vnc_after_surfaceflinger_restart
  recover_host_audio_stream
}

ensure_android_ready() {
  wait_for_guest_ssh
  connect_adb
  wait_for_boot
  post_boot_prepare
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

resolve_hwcomposer_drm_refresh_rate_cap() {
  if [[ -n "${REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP}" ]]; then
    printf '%s' "${REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP}"
    return 0
  fi

  case "${GUEST4K_DRM_REFRESH_PROFILE}" in
    balanced|'')
      printf '60'
      ;;
    lowcpu)
      printf '45'
      ;;
    powersave)
      printf '30'
      ;;
    *)
      printf 'Unsupported GUEST4K_DRM_REFRESH_PROFILE: %s\n' "${GUEST4K_DRM_REFRESH_PROFILE}" >&2
      return 1
      ;;
  esac
}

android_boot_graphics_args() {
  local args=()
  local hwcomposer_drm_refresh_rate_cap

  if [[ -n "${REDROID_BOOT_HARDWARE_EGL}" ]]; then
    args+=("androidboot.hardwareegl=${REDROID_BOOT_HARDWARE_EGL}")
  fi

  if [[ -n "${REDROID_BOOT_HARDWARE_VULKAN}" ]]; then
    args+=("androidboot.hardware.vulkan=${REDROID_BOOT_HARDWARE_VULKAN}")
  fi

  if [[ -n "${REDROID_BOOT_CPU_VULKAN_VERSION}" ]]; then
    args+=("androidboot.cpuvulkan.version=${REDROID_BOOT_CPU_VULKAN_VERSION}")
  fi

  if [[ -n "${REDROID_BOOT_OPENGLES_VERSION}" ]]; then
    args+=("androidboot.opengles.version=${REDROID_BOOT_OPENGLES_VERSION}")
  fi

  if [[ -n "${REDROID_BOOT_DEBUG_HWUI_RENDERER}" ]]; then
    args+=("androidboot.debug.hwui.renderer=${REDROID_BOOT_DEBUG_HWUI_RENDERER}")
  fi

  if [[ -n "${REDROID_BOOT_DEBUG_RENDERENGINE_BACKEND}" ]]; then
    args+=("androidboot.debug.renderengine.backend=${REDROID_BOOT_DEBUG_RENDERENGINE_BACKEND}")
  fi

  hwcomposer_drm_refresh_rate_cap="$(resolve_hwcomposer_drm_refresh_rate_cap)"
  if [[ -n "${hwcomposer_drm_refresh_rate_cap}" ]]; then
    args+=("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=${hwcomposer_drm_refresh_rate_cap}")
  fi

  printf '%s' "${(j: :)args}"
}

default_android_boot_args() {
  local args="qemu=1 androidboot.hardware=redroid androidboot.use_redroid_vnc=${REDROID_VNC_BOOT} androidboot.redroid_gpu_mode=${REDROID_GPU_MODE} androidboot.redroid_gpu_node=${REDROID_GPU_NODE}"
  local graphics_args

  graphics_args="$(android_boot_graphics_args)"
  if [[ -n "${graphics_args}" ]]; then
    args+=" ${graphics_args}"
  fi

  printf '%s' "${args}"
}

guest_container_binderfs_root_path() {
  local container_name="$1"

  printf '/tmp/%s-binderfs' "${container_name}"
}

restore_virgl_srcbuild_rollout() {
  local guest_cmd

  guest_cmd=$(cat <<EOF
set -euo pipefail
podman stop -t 10 ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} >/dev/null 2>&1 || true
podman start ${CONTAINER} >/dev/null 2>&1 || true
state=\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || true)
echo "AUTO_RESTORED \${state}"
test "\${state%%|*}" = "running"
EOF
)

  run_guest_sudo "${guest_cmd}"
}

guest_container_logcat_clear_cmd() {
  local container_name="$1"
  local attempts="${2:-5}"

  cat <<EOF
logcat_cleared=0
for _ in \$(seq 1 ${attempts}); do
  if podman exec ${container_name} /system/bin/logcat -c >/dev/null 2>&1; then
    logcat_cleared=1
    break
  fi
  sleep 1
done
if [ "\${logcat_cleared}" != "1" ]; then
  podman exec ${container_name} /system/bin/logcat -c >/dev/null 2>&1 || true
fi
EOF
}

guest_container_runtime_guard_helper_cmd() {
  cat <<'EOF'
container_runtime_state() {
  container_name="$1"
  podman container inspect "${container_name}" --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}' 2>/dev/null || printf 'missing||'
}

podman_exec_if_running() {
  container_name="$1"
  skip_label="$2"
  shift 2
  state="$(container_runtime_state "${container_name}")"
  if [ "${state%%|*}" = "running" ]; then
    podman exec "${container_name}" "$@" || true
  else
    echo "${skip_label} ${state}"
  fi
}

clear_container_logcat_if_running() {
  container_name="$1"
  attempts="${2:-5}"
  state=""
  for _ in $(seq 1 "${attempts}"); do
    state="$(container_runtime_state "${container_name}")"
    if [ "${state%%|*}" != "running" ]; then
      echo "LOGCAT_CLEAR_SKIPPED ${state}"
      return 0
    fi
    if podman exec "${container_name}" /system/bin/logcat -c >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  state="$(container_runtime_state "${container_name}")"
  if [ "${state%%|*}" != "running" ]; then
    echo "LOGCAT_CLEAR_SKIPPED ${state}"
    return 0
  fi

  podman exec "${container_name}" /system/bin/logcat -c >/dev/null 2>&1 || true
}
EOF
}

guest_container_logcat_clear_if_running_cmd() {
  local container_name="$1"
  local attempts="${2:-5}"

  cat <<EOF
clear_container_logcat_if_running ${container_name} ${attempts}
EOF
}

guest_container_mainline_handoff_helper_cmd() {
  cat <<EOF
mainline_was_running=0

stop_standard_mainline_if_running() {
  mainline_state="\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || printf 'missing|')"
  echo "MAINLINE_STATE_BEFORE \${mainline_state}"
  if [ "\${mainline_state%%|*}" = "running" ]; then
    podman stop -t 10 ${CONTAINER} >/dev/null 2>&1 || true
    mainline_state="\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || printf 'missing|')"
    if [ "\${mainline_state%%|*}" != "exited" ] && [ "\${mainline_state%%|*}" != "stopped" ]; then
      echo "MAINLINE_STOP_FAILED \${mainline_state}"
      return 1
    fi
    mainline_was_running=1
    echo "MAINLINE_STOPPED ${CONTAINER}"
  fi
}

restore_standard_mainline_if_needed() {
  if [ "\${mainline_was_running}" != "1" ]; then
    return 0
  fi

  podman start ${CONTAINER} >/dev/null 2>&1 || true
  mainline_state="\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || printf 'missing|')"
  if [ "\${mainline_state%%|*}" != "running" ]; then
    echo "MAINLINE_RESTORE_FAILED \${mainline_state}"
    return 1
  fi
  echo "MAINLINE_RESTORED \${mainline_state}"
}
EOF
}

guest_container_gpu_config_bootstrap_helper_cmd() {
  cat <<'EOF'
bootstrap_gpu_config_if_running() {
  container_name="$1"
  skip_label="$2"
  attempts="${3:-5}"
  state=""
  for _ in $(seq 1 "${attempts}"); do
    state="$(container_runtime_state "${container_name}")"
    if [ "${state%%|*}" != "running" ]; then
      echo "${skip_label} ${state}"
      return 0
    fi
    if podman exec "${container_name}" /system/bin/sh -lc '/vendor/bin/gpu_config.sh' 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  state="$(container_runtime_state "${container_name}")"
  if [ "${state%%|*}" != "running" ]; then
    echo "${skip_label} ${state}"
    return 0
  fi

  podman exec "${container_name}" /system/bin/sh -lc '/vendor/bin/gpu_config.sh' || true
}
EOF
}

guest_container_gpu_config_bootstrap_if_running_cmd() {
  local container_name="$1"
  local skip_label="$2"
  local attempts="${3:-5}"

  cat <<EOF
bootstrap_gpu_config_if_running ${container_name} ${skip_label} ${attempts}
EOF
}

guest_container_portless_runtime_helper_cmd() {
  cat <<'EOF'
create_portless_runtime_from_template() {
  source_container="$1"
  target_container="$2"
  target_binder_root="$3"
  target_image="${4:-}"
  inspect_file=$(mktemp)
  args_file=$(mktemp)
  pending_mode=""
  pending_option=""
  found_image=0
  saw_podman=0
  saw_run=0
  wrote_target_binder_mounts=0

  cleanup_portless_runtime_files() {
    rm -f "${inspect_file}" "${args_file}"
  }

  cleanup_target_binder_root() {
    if [ -z "${target_binder_root}" ]; then
      return 0
    fi

    umount "${target_binder_root}" >/dev/null 2>&1 || true
    rmdir "${target_binder_root}" >/dev/null 2>&1 || true
  }

  prepare_target_binder_root() {
    if [ -z "${target_binder_root}" ]; then
      return 0
    fi

    umount "${target_binder_root}" >/dev/null 2>&1 || true
    mkdir -p "${target_binder_root}"
    mountpoint -q "${target_binder_root}" || mount -t binder binder "${target_binder_root}"
    chmod 666 "${target_binder_root}"/* || true
  }

  write_portless_arg() {
    printf '%s\0' "$1" >> "${args_file}"
  }

  binder_mount_value_isolated() {
    case "$1" in
      *:/dev/binder|*:/dev/binder:*|*:/dev/hwbinder|*:/dev/hwbinder:*|*:/dev/vndbinder|*:/dev/vndbinder:*)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }

  maybe_write_mount_arg() {
    mount_option="$1"
    mount_value="$2"

    if [ -n "${target_binder_root}" ] && binder_mount_value_isolated "${mount_value}"; then
      return 0
    fi

    write_portless_arg "${mount_option}"
    write_portless_arg "${mount_value}"
  }

  maybe_write_inline_mount_arg() {
    mount_option="$1"
    mount_value="$2"

    if [ -n "${target_binder_root}" ] && binder_mount_value_isolated "${mount_value}"; then
      return 0
    fi

    write_portless_arg "${mount_option}=${mount_value}"
  }

  write_target_binder_mount_args() {
    if [ -z "${target_binder_root}" ] || [ "${wrote_target_binder_mounts}" = "1" ]; then
      return 0
    fi

    write_portless_arg "-v"
    write_portless_arg "${target_binder_root}/binder:/dev/binder"
    write_portless_arg "-v"
    write_portless_arg "${target_binder_root}/hwbinder:/dev/hwbinder"
    write_portless_arg "-v"
    write_portless_arg "${target_binder_root}/vndbinder:/dev/vndbinder"
    wrote_target_binder_mounts=1
  }

  prepare_target_binder_root
  podman container inspect "${source_container}" --format '{{range .Config.CreateCommand}}{{println .}}{{end}}' > "${inspect_file}"
  : > "${args_file}"
  write_portless_arg "--name"
  write_portless_arg "${target_container}"

  while IFS= read -r arg || [ -n "${arg}" ]; do
    if [ "${saw_podman}" != "1" ]; then
      if [ "${arg}" = "podman" ]; then
        saw_podman=1
      fi
      continue
    fi

    if [ "${saw_run}" != "1" ]; then
      if [ "${arg}" = "run" ]; then
        saw_run=1
      fi
      continue
    fi

    if [ -n "${pending_mode}" ]; then
      case "${pending_mode}" in
        copy)
          write_portless_arg "${pending_option}"
          write_portless_arg "${arg}"
          ;;
        mount)
          maybe_write_mount_arg "${pending_option}" "${arg}"
          ;;
        skip)
          ;;
      esac
      pending_mode=""
      pending_option=""
      continue
    fi

    if [ -z "${arg}" ]; then
      continue
    fi

    if [ "${found_image}" = "1" ]; then
      write_portless_arg "${arg}"
      continue
    fi

    case "${arg}" in
      -d|--detach)
        ;;
      --name|-p|--publish)
        pending_mode="skip"
        ;;
      --name=*|--publish=*)
        ;;
      -v|--volume|--mount)
        pending_mode="mount"
        pending_option="${arg}"
        ;;
      -v=*|--volume=*|--mount=*)
        maybe_write_inline_mount_arg "${arg%%=*}" "${arg#*=}"
        ;;
      --entrypoint|--security-opt|--device|-e|--env|--annotation|--label|--add-host|--tmpfs|--sysctl|--ulimit|--shm-size|--workdir|-w|--user|-u|--hostname|--network|--ipc|--pid|--uts|--arch|--platform|--pull|--authfile|--cidfile|--cgroup-parent|--cpus|--cpuset-cpus|--cpuset-mems|--memory|--memory-swap|--pids-limit|--restart|--runtime|--stop-signal|--stop-timeout|--health-cmd|--health-interval|--health-retries|--health-start-period|--health-timeout|--log-driver|--log-opt|--gpus|--device-cgroup-rule|--group-add)
        pending_mode="copy"
        pending_option="${arg}"
        ;;
      --entrypoint=*|--security-opt=*|--device=*|-e=*|--env=*|--annotation=*|--label=*|--add-host=*|--tmpfs=*|--sysctl=*|--ulimit=*|--shm-size=*|--workdir=*|-w=*|--user=*|-u=*|--hostname=*|--network=*|--ipc=*|--pid=*|--uts=*|--arch=*|--platform=*|--pull=*|--authfile=*|--cidfile=*|--cgroup-parent=*|--cpus=*|--cpuset-cpus=*|--cpuset-mems=*|--memory=*|--memory-swap=*|--pids-limit=*|--restart=*|--runtime=*|--stop-signal=*|--stop-timeout=*|--health-cmd=*|--health-interval=*|--health-retries=*|--health-start-period=*|--health-timeout=*|--log-driver=*|--log-opt=*|--gpus=*|--device-cgroup-rule=*|--group-add=*)
        write_portless_arg "${arg}"
        ;;
      --*)
        write_portless_arg "${arg}"
        ;;
      -*)
        write_portless_arg "${arg}"
        ;;
      *)
        write_target_binder_mount_args
        if [ -n "${target_image}" ]; then
          write_portless_arg "${target_image}"
        else
          write_portless_arg "${arg}"
        fi
        found_image=1
        ;;
    esac
  done < "${inspect_file}"

  if [ "${found_image}" != "1" ]; then
    cleanup_target_binder_root
    cleanup_portless_runtime_files
    echo "Unable to derive image position from ${source_container} CreateCommand" >&2
    return 1
  fi

  if ! xargs -0 podman create < "${args_file}" >/dev/null; then
    cleanup_target_binder_root
    cleanup_portless_runtime_files
    return 1
  fi

  cleanup_portless_runtime_files
}
EOF
}

rollout_health_capture_cmd() {
  local begin_marker="$1"
  local end_marker="$2"
  local sleep_seconds="${3:-0}"

  cat <<EOF
set -euo pipefail
if [ "${sleep_seconds}" -gt 0 ]; then
  sleep ${sleep_seconds}
fi
echo '${begin_marker}'
podman exec ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} /system/bin/sh -lc '
sf_pid=\$(/system/bin/pidof surfaceflinger 2>/dev/null || true)
printf "ro.hardware.gralloc="
/system/bin/getprop ro.hardware.gralloc
printf "sys.boot_completed="
/system/bin/getprop sys.boot_completed
printf "init.svc.surfaceflinger="
/system/bin/getprop init.svc.surfaceflinger
printf "surfaceflinger.pid=%s\n" "\${sf_pid}"
' || true
podman exec ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} /system/bin/sh -lc '/system/bin/logcat -d | grep -E "Using gralloc0 CrOS API|Using fallback gralloc implementation|failed to create DRI image from FD|eglCreateImageKHR failed|Failed to create a valid texture" || true' || true
echo '${end_marker}'
EOF
}

rollout_health_has_required_properties() {
  local output="$1"

  [[ "${output}" == *"ro.hardware.gralloc=minigbm"* ]] &&
    [[ "${output}" == *"sys.boot_completed=1"* ]] &&
    [[ "${output}" == *"init.svc.surfaceflinger=running"* ]] &&
    printf '%s\n' "${output}" | grep -Eq '^surfaceflinger\.pid=.+'
}

rollout_health_has_positive_marker() {
  local output="$1"

  [[ "${output}" == *"Using gralloc0 CrOS API"* ]]
}

rollout_health_has_negative_markers() {
  local output="$1"

  [[ "${output}" == *"Using fallback gralloc implementation"* ]] || \
    [[ "${output}" == *"failed to create DRI image from FD"* ]] || \
    [[ "${output}" == *"eglCreateImageKHR failed"* ]] || \
    [[ "${output}" == *"Failed to create a valid texture"* ]]
}

rollout_health_gate_passes() {
  local output="$1"

  rollout_health_has_required_properties "${output}" &&
    rollout_health_has_positive_marker "${output}" &&
    ! rollout_health_has_negative_markers "${output}"
}

rollout_health_needs_retry() {
  local output="$1"

  rollout_health_has_required_properties "${output}" &&
    ! rollout_health_has_positive_marker "${output}" &&
    ! rollout_health_has_negative_markers "${output}"
}

prepare_phone_profile() {
  local stage_host_key_cmd
  local guest_transport_cmd
  local guest_stage_inner_cmd
  local guest_cmd

  guest_transport_cmd="$(guest_ssh_transport_cmd)"
  guest_stage_inner_cmd="mkdir -p ${REMOTE_PHONE_PROFILE_DIR} && cat > ${GUEST_PHONE_ADB_KEY_STAGE} && chmod 644 ${GUEST_PHONE_ADB_KEY_STAGE}"
  stage_host_key_cmd=$(cat <<EOF
set -euo pipefail
if [ ! -s '${REMOTE_ADB_KEY_SOURCE}' ]; then
  echo 'Missing host adb public key: ${REMOTE_ADB_KEY_SOURCE}' >&2
  exit 1
fi
${guest_transport_cmd} ${(qqq)guest_stage_inner_cmd} < ${(qqq)REMOTE_ADB_KEY_SOURCE}
EOF
)

  guest_cmd=$(cat <<EOF
set -euo pipefail

profile_dir='${REMOTE_PHONE_PROFILE_DIR}'
system_prop='${REMOTE_PHONE_SYSTEM_PROP}'
vendor_prop='${REMOTE_PHONE_VENDOR_PROP}'
xbin_dir='${REMOTE_PHONE_XBIN_DIR}'
adb_keys='${REMOTE_PHONE_ADB_KEYS}'
staged_adb_key='${GUEST_PHONE_ADB_KEY_STAGE}'
image_container=''

rm -rf "\${profile_dir}"
mkdir -p "\${profile_dir}" "\${xbin_dir}"

if [ ! -s "\${staged_adb_key}" ]; then
  echo 'Missing staged guest adb public key: ${GUEST_PHONE_ADB_KEY_STAGE}' >&2
  exit 1
fi

cleanup_image_container() {
  if [ -n "\${image_container}" ]; then
    podman rm -f "\${image_container}" >/dev/null 2>&1 || true
  fi
}
trap cleanup_image_container EXIT

image_container=\$(podman create --pull=never ${IMAGE})
podman cp "\${image_container}:/system/build.prop" "\${system_prop}"
podman cp "\${image_container}:/vendor/build.prop" "\${vendor_prop}"
if podman cp "\${image_container}:/system/xbin/overlay_remounter" "\${xbin_dir}/overlay_remounter" >/dev/null 2>&1; then
  chmod 755 "\${xbin_dir}/overlay_remounter"
fi
cp "\${staged_adb_key}" "\${adb_keys}"
chmod 644 "\${adb_keys}"
rm -f "\${xbin_dir}/su"

set_prop() {
  file="\$1"
  key="\$2"
  value="\$3"
  tmp=\$(mktemp)
  awk -v key="\$key" -v value="\$value" '
    BEGIN { done = 0 }
    index(\$0, key "=") == 1 {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print key "=" value
      }
    }
  ' "\$file" > "\$tmp"
  mv "\$tmp" "\$file"
}

set_prop "\$system_prop" "ro.product.brand" '${PHONE_BRAND}'
set_prop "\$system_prop" "ro.product.manufacturer" '${PHONE_MANUFACTURER}'
set_prop "\$system_prop" "ro.product.model" '${PHONE_MODEL}'
set_prop "\$system_prop" "ro.product.device" '${PHONE_DEVICE}'
set_prop "\$system_prop" "ro.product.name" '${PHONE_NAME}'
set_prop "\$system_prop" "ro.product.system.brand" '${PHONE_BRAND}'
set_prop "\$system_prop" "ro.product.system.manufacturer" '${PHONE_MANUFACTURER}'
set_prop "\$system_prop" "ro.product.system.model" '${PHONE_MODEL}'
set_prop "\$system_prop" "ro.product.system.device" '${PHONE_DEVICE}'
set_prop "\$system_prop" "ro.product.system.name" '${PHONE_NAME}'

set_prop "\$vendor_prop" "ro.product.vendor.brand" '${PHONE_BRAND}'
set_prop "\$vendor_prop" "ro.product.vendor.manufacturer" '${PHONE_MANUFACTURER}'
set_prop "\$vendor_prop" "ro.product.vendor.model" '${PHONE_MODEL}'
set_prop "\$vendor_prop" "ro.product.vendor.device" '${PHONE_DEVICE}'
set_prop "\$vendor_prop" "ro.product.vendor.name" '${PHONE_NAME}'
set_prop "\$vendor_prop" "ro.product.odm.brand" '${PHONE_BRAND}'
set_prop "\$vendor_prop" "ro.product.odm.manufacturer" '${PHONE_MANUFACTURER}'
set_prop "\$vendor_prop" "ro.product.odm.model" '${PHONE_MODEL}'
set_prop "\$vendor_prop" "ro.product.odm.device" '${PHONE_DEVICE}'
set_prop "\$vendor_prop" "ro.product.odm.name" '${PHONE_NAME}'

trap - EXIT
cleanup_image_container
EOF
)

  log "staging host adb public key into guest"
  run_remote "bash -lc ${(qqq)stage_host_key_cmd}"
  log "preparing guest phone profile ${PHONE_PROFILE_ID} (${PHONE_BRAND} ${PHONE_DEVICE_NAME})"
  run_guest_sudo "${guest_cmd}"
}

show_runtime_mode() {
  local guest_cmd

  guest_cmd=$(cat <<EOF
if podman inspect ${CONTAINER} --format '{{range .Mounts}}{{println .Destination}}{{end}}' 2>/dev/null | grep -qx '/system/build.prop'; then
  echo "phone-mode (${PHONE_PROFILE_ID})"
else
  echo 'baseline'
fi
EOF
)

  run_guest_sudo "bash -lc ${(qqq)guest_cmd}"
}

set_device_name() {
  local cmd

  cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell "settings put global device_name '${PHONE_DEVICE_NAME}'"
EOF
)

  log "setting device_name to ${PHONE_DEVICE_NAME}"
  run_remote "bash -lc ${(qqq)cmd}"
}

activate_phone_mode() {
  vm_start
  wait_for_guest_ssh
  prepare_phone_profile
  restart_redroid "${IMAGE}" 0 phone
  set_device_name
  verify_runtime
}

restart_redroid() {
  local image="${1:-${IMAGE}}"
  local preserve_data="${2:-0}"
  local runtime_mode="${3:-baseline}"
  local binder_root
  local guest_cmd
  local graphics_prep_cmd
  local graphics_mounts
  local phone_mounts=""
  local runtime_mounts
  local audio_prep_cmd
  local volume_reset_cmd="podman volume rm -f ${VOLUME_NAME} >/dev/null 2>&1 || true"
  local android_boot_args

  require_supported_graphics_profile
  vm_start
  wait_for_guest_ssh
  graphics_prep_cmd="$(graphics_prepare_cmd)"
  graphics_mounts="$(graphics_mount_args)"
  audio_prep_cmd="$(audio_prepare_cmd)"
  binder_root="$(guest_container_binderfs_root_path "${CONTAINER}")"
  android_boot_args="$(default_android_boot_args)"
  if [[ "${runtime_mode}" == "phone" ]]; then
    phone_mounts=$(cat <<EOF
  -v ${REMOTE_PHONE_SYSTEM_PROP}:/system/build.prop:ro \\
  -v ${REMOTE_PHONE_VENDOR_PROP}:/vendor/build.prop:ro \\
  -v ${REMOTE_PHONE_XBIN_DIR}:/system/xbin:ro \\
  -v ${REMOTE_PHONE_ADB_KEYS}:/product/etc/security/adb_keys:ro \\
EOF
)
  fi
  if [[ "${preserve_data}" == "1" ]]; then
    volume_reset_cmd=":"
  fi
  runtime_mounts="${graphics_mounts}"$'\n'
  if [[ -n "${phone_mounts}" ]]; then
    runtime_mounts+="${phone_mounts}"$'\n'
  fi

  guest_cmd=$(cat <<EOF
set -euo pipefail
setenforce 0 || true
for legacy_container in ${LEGACY_GUEST_CONTAINERS}; do
  podman rm -f "\${legacy_container}" >/dev/null 2>&1 || true
  podman volume rm -f "\${legacy_container}-data" >/dev/null 2>&1 || true
done
podman rm -f ${CONTAINER} >/dev/null 2>&1 || true
for standard_port_container in ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} ${VIRGL_SRCBUILD_CONTROL_CONTAINER}; do
  podman stop -t 10 "\${standard_port_container}" >/dev/null 2>&1 || true
done
${volume_reset_cmd}
umount ${binder_root} >/dev/null 2>&1 || true
mkdir -p ${binder_root}
mountpoint -q ${binder_root} || mount -t binder binder ${binder_root}
chmod 666 ${binder_root}/* || true
runtime_android_boot_args=${(qqq)android_boot_args}
if [ "${REDROID_BOOT_USE_DMABUFHEAPS}" = "auto" ]; then
  if [ -c /dev/dma_heap/system ]; then
    runtime_android_boot_args="\${runtime_android_boot_args} androidboot.use_dmabufheaps=1"
  fi
elif [ -n "${REDROID_BOOT_USE_DMABUFHEAPS}" ]; then
  runtime_android_boot_args="\${runtime_android_boot_args} androidboot.use_dmabufheaps=${REDROID_BOOT_USE_DMABUFHEAPS}"
fi
${graphics_prep_cmd}
${audio_prep_cmd}
podman run -d --name ${CONTAINER} --pull=never --privileged --security-opt label=disable --security-opt unmask=all \\
  -p 5555:5555/tcp -p 5900:5900/tcp \\
  -v ${VOLUME_NAME}:/data \\
${runtime_mounts}  -v ${binder_root}/binder:/dev/binder \\
  -v ${binder_root}/hwbinder:/dev/hwbinder \\
  -v ${binder_root}/vndbinder:/dev/vndbinder \\
  --entrypoint /init ${image} \\
  \${runtime_android_boot_args}
podman ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'
EOF
)

  log "graphics profile: ${GRAPHICS_PROFILE}"
  log "runtime mode: ${runtime_mode}"
  log "restarting guest Redroid container ${CONTAINER} with image ${image}"
  run_guest_sudo "${guest_cmd}"
  connect_adb
  wait_for_boot
  post_boot_prepare
}

show_status() {
  require_supported_graphics_profile
  log "showing VM status"
  vm_status

  log "showing guest page size"
  run_guest "getconf PAGE_SIZE"

  log "configured graphics profile: ${GRAPHICS_PROFILE}"
  log "runtime mode"
  show_runtime_mode
  log "showing guest container status"
  run_guest_sudo "podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
}

verify_runtime() {
  local guest_ssh_cmd
  local host_vnc_cmd
  local boot_cmd
  local app_props_cmd
  local su_visibility_cmd
  local device_name_cmd

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
  post_boot_prepare

  app_props_cmd=$(cat <<EOF
for p in ro.product.brand ro.product.manufacturer ro.product.model ro.product.device ro.build.fingerprint ro.build.type ro.build.tags ro.debuggable; do
  printf '%s=' "\$p"
  getprop "\$p"
done
EOF
  )
  su_visibility_cmd=$(cat <<'EOF'
ls -l /system/xbin/su 2>/dev/null || echo /system/xbin/su hidden
EOF
  )
  device_name_cmd=$(cat <<'EOF'
settings get global device_name
EOF
  )
  boot_cmd=$(cat <<EOF
timeout 5 adb -s ${ADB_SERIAL} shell getprop sys.boot_completed 2>&1
EOF
  )
  log "runtime mode"
  show_runtime_mode
  log "verifying Android boot properties on ${ADB_SERIAL}"
  run_remote "bash -lc ${(qqq)boot_cmd}"
  log "app-facing device props"
  run_remote "adb -s ${ADB_SERIAL} shell ${(qqq)app_props_cmd}"
  log "su visibility"
  run_remote "adb -s ${ADB_SERIAL} shell ${(qqq)su_visibility_cmd}"
  log "device_name"
  run_remote "adb -s ${ADB_SERIAL} shell ${(qqq)device_name_cmd}"

  if redroid_vnc_boot_enabled; then
    host_vnc_cmd="$(vnc_banner_probe_cmd)"
    log "verifying VNC banner on ${VNC_HOST}:${VNC_PORT}"
    run_remote "bash -lc ${(qqq)host_vnc_cmd}"
  fi
}

probe_virgl_srcbuild() {
  local guest_cmd
  local logcat_clear_cmd
  local gpu_config_bootstrap_cmd
  local gpu_config_bootstrap_helper_cmd
  local mainline_handoff_helper_cmd
  local portless_runtime_helper_cmd
  local runtime_guard_helper_cmd

  wait_for_guest_ssh
  logcat_clear_cmd="$(guest_container_logcat_clear_if_running_cmd "${VIRGL_SRCBUILD_PROBE_CONTAINER}")"
  gpu_config_bootstrap_cmd="$(guest_container_gpu_config_bootstrap_if_running_cmd "${VIRGL_SRCBUILD_PROBE_CONTAINER}" "GPU_CONFIG_BOOTSTRAP_SKIPPED")"
  gpu_config_bootstrap_helper_cmd="$(guest_container_gpu_config_bootstrap_helper_cmd)"
  mainline_handoff_helper_cmd="$(guest_container_mainline_handoff_helper_cmd)"
  portless_runtime_helper_cmd="$(guest_container_portless_runtime_helper_cmd)"
  runtime_guard_helper_cmd="$(guest_container_runtime_guard_helper_cmd)"

  guest_cmd=$(cat <<EOF
set -euo pipefail
${portless_runtime_helper_cmd}
${runtime_guard_helper_cmd}
${mainline_handoff_helper_cmd}
${gpu_config_bootstrap_helper_cmd}
cleanup() {
  cleanup_status=0
  set +e
  podman stop -t 10 ${VIRGL_SRCBUILD_PROBE_CONTAINER} >/dev/null 2>&1 || true
  podman rm -f ${VIRGL_SRCBUILD_PROBE_CONTAINER} >/dev/null 2>&1 || true
  restore_standard_mainline_if_needed || cleanup_status=\$?
  return "\${cleanup_status}"
}
trap cleanup EXIT
stop_standard_mainline_if_running
podman rm -f ${VIRGL_SRCBUILD_PROBE_CONTAINER} >/dev/null 2>&1 || true
create_portless_runtime_from_template ${VIRGL_SRCBUILD_CONTROL_CONTAINER} ${VIRGL_SRCBUILD_PROBE_CONTAINER} "" ${VIRGL_SRCBUILD_IMAGE}
echo "PORTLESS_CREATE \$(podman container inspect ${VIRGL_SRCBUILD_PROBE_CONTAINER} --format '{{.Name}}|{{.ImageName}}|{{.HostConfig.PortBindings}}')"
podman start ${VIRGL_SRCBUILD_PROBE_CONTAINER} >/dev/null
echo "PROBE started"
echo 'GPU_CONFIG_BOOTSTRAP_BEGIN'
${gpu_config_bootstrap_cmd}
echo 'GPU_CONFIG_BOOTSTRAP_END'
sleep 10
echo "PROBE_STATE \$(podman container inspect ${VIRGL_SRCBUILD_PROBE_CONTAINER} --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}')"
${logcat_clear_cmd}
sleep ${VIRGL_SRCBUILD_PROBE_SECONDS}
echo 'PROPS_BEGIN'
podman_exec_if_running ${VIRGL_SRCBUILD_PROBE_CONTAINER} PROPS_SKIPPED /system/bin/sh -lc '/system/bin/getprop ro.hardware.gralloc; /system/bin/getprop sys.boot_completed; /system/bin/getprop init.svc.surfaceflinger'
echo 'PROPS_END'
echo 'FILES_BEGIN'
podman_exec_if_running ${VIRGL_SRCBUILD_PROBE_CONTAINER} FILES_SKIPPED /system/bin/sh -lc 'ls -l /vendor/lib64/hw/gralloc.cros.so /vendor/lib64/hw/gralloc.minigbm.so 2>/dev/null || true'
echo 'FILES_END'
echo 'LOGS_BEGIN'
podman_exec_if_running ${VIRGL_SRCBUILD_PROBE_CONTAINER} LOGS_SKIPPED /system/bin/sh -lc '/system/bin/logcat -d | grep -E "Using gralloc0 CrOS API|Using fallback gralloc implementation|failed to create DRI image from FD|eglCreateImageKHR failed|Failed to create a valid texture" || true'
echo 'LOGS_END'
echo "FINAL_STATE \$(podman container inspect ${VIRGL_SRCBUILD_PROBE_CONTAINER} --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}')"
trap - EXIT
cleanup
EOF
)

  log "running virgl-srcbuild-probe from ${VIRGL_SRCBUILD_CONTROL_CONTAINER} onto ${VIRGL_SRCBUILD_IMAGE}"
  run_guest_sudo "${guest_cmd}"
}

probe_virgl_srcbuild_longrun() {
  local guest_cmd
  local checkpoint_cmds=""
  local checkpoint=0
  local previous_checkpoint=0
  local delta=0
  local logcat_clear_cmd
  local gpu_config_bootstrap_cmd
  local gpu_config_bootstrap_helper_cmd
  local mainline_handoff_helper_cmd
  local portless_runtime_helper_cmd
  local runtime_guard_helper_cmd

  wait_for_guest_ssh
  logcat_clear_cmd="$(guest_container_logcat_clear_if_running_cmd "${VIRGL_SRCBUILD_LONGRUN_CONTAINER}")"
  gpu_config_bootstrap_cmd="$(guest_container_gpu_config_bootstrap_if_running_cmd "${VIRGL_SRCBUILD_LONGRUN_CONTAINER}" "GPU_CONFIG_BOOTSTRAP_SKIPPED")"
  gpu_config_bootstrap_helper_cmd="$(guest_container_gpu_config_bootstrap_helper_cmd)"
  mainline_handoff_helper_cmd="$(guest_container_mainline_handoff_helper_cmd)"
  portless_runtime_helper_cmd="$(guest_container_portless_runtime_helper_cmd)"
  runtime_guard_helper_cmd="$(guest_container_runtime_guard_helper_cmd)"

  for checkpoint in ${(z)VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS}; do
    if (( checkpoint < previous_checkpoint )); then
      printf 'VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS must be ascending: %s\n' "${VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS}" >&2
      return 1
    fi
    delta=$((checkpoint - previous_checkpoint))
    checkpoint_cmds+=$(cat <<EOF
sleep ${delta}
echo 'CHECKPOINT_T${checkpoint}_BEGIN'
podman_exec_if_running ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} CHECKPOINT_T${checkpoint}_PROPS_SKIPPED /system/bin/sh -lc '
sf_pid=\$(/system/bin/pidof surfaceflinger 2>/dev/null || true)
printf "ro.hardware.gralloc="
/system/bin/getprop ro.hardware.gralloc
printf "sys.boot_completed="
/system/bin/getprop sys.boot_completed
printf "init.svc.surfaceflinger="
/system/bin/getprop init.svc.surfaceflinger
printf "surfaceflinger.pid=%s\n" "\${sf_pid}"
'
podman_exec_if_running ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} CHECKPOINT_T${checkpoint}_LOGS_SKIPPED /system/bin/sh -lc '/system/bin/logcat -d | grep -E "Using gralloc0 CrOS API|Using fallback gralloc implementation|failed to create DRI image from FD|eglCreateImageKHR failed|Failed to create a valid texture" || true'
echo 'CHECKPOINT_T${checkpoint}_END'
EOF
)
    checkpoint_cmds+=$'\n'
    previous_checkpoint=${checkpoint}
  done

  guest_cmd=$(cat <<EOF
set -euo pipefail
${portless_runtime_helper_cmd}
${runtime_guard_helper_cmd}
${mainline_handoff_helper_cmd}
${gpu_config_bootstrap_helper_cmd}
cleanup() {
  cleanup_status=0
  set +e
  podman stop -t 10 ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} >/dev/null 2>&1 || true
  podman rm -f ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} >/dev/null 2>&1 || true
  restore_standard_mainline_if_needed || cleanup_status=\$?
  return "\${cleanup_status}"
}
trap cleanup EXIT
stop_standard_mainline_if_running
podman rm -f ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} >/dev/null 2>&1 || true
create_portless_runtime_from_template ${VIRGL_SRCBUILD_CONTROL_CONTAINER} ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} "" ${VIRGL_SRCBUILD_IMAGE}
echo "PORTLESS_CREATE \$(podman container inspect ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} --format '{{.Name}}|{{.ImageName}}|{{.HostConfig.PortBindings}}')"
podman start ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} >/dev/null
echo "PROBE started"
echo 'GPU_CONFIG_BOOTSTRAP_BEGIN'
${gpu_config_bootstrap_cmd}
echo 'GPU_CONFIG_BOOTSTRAP_END'
sleep 10
echo "PROBE_STATE \$(podman container inspect ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}')"
${logcat_clear_cmd}
${checkpoint_cmds}
echo 'FINAL_FILES_BEGIN'
podman_exec_if_running ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} FINAL_FILES_SKIPPED /system/bin/sh -lc '
for path in /vendor/lib64/hw/gralloc.cros.so /vendor/lib64/hw/gralloc.minigbm.so; do
  echo "FILE \$path"
  if [ -e "\$path" ]; then
    ls -l "\$path"
  else
    echo "MISSING \$path"
  fi
done
'
echo 'FINAL_FILES_END'
echo "FINAL_STATE \$(podman container inspect ${VIRGL_SRCBUILD_LONGRUN_CONTAINER} --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}')"
trap - EXIT
cleanup
EOF
)

  log "running virgl-srcbuild-longrun from ${VIRGL_SRCBUILD_CONTROL_CONTAINER} onto ${VIRGL_SRCBUILD_IMAGE}"
  run_guest_sudo "${guest_cmd}"
}

import_virgl_srcbuild_image() {
  local copy_cmd
  local guest_cmd
  local guest_mkdir_cmd
  local guest_mkdir_path_cmd="mkdir -p ${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}"
  local guest_merged_root="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}/merged-root"
  local guest_merged_vendor="${guest_merged_root}/vendor"
  local guest_mnt_system="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}/mnt-system"
  local guest_mnt_vendor="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}/mnt-vendor"
  local guest_mnt_vendor_subdir="${guest_mnt_vendor}/vendor"
  local guest_compat_commit_image="${VIRGL_SRCBUILD_IMPORT_IMAGE}-compat-overlay-tmp"
  local guest_compat_overlay_files="${VIRGL_SRCBUILD_IMPORT_COMPAT_OVERLAY_FILES}"
  local guest_compat_ref_image="${VIRGL_SRCBUILD_IMPORT_COMPAT_REF_IMAGE}"
  local guest_scp_cmd
  local guest_system_copy_cmd
  local guest_system_img="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}/system.img"
  local guest_system_target="${GUEST_USER}@127.0.0.1:${guest_system_img}"
  local guest_vendor_copy_cmd
  local guest_vendor_img="${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}/vendor.img"
  local guest_vendor_target="${GUEST_USER}@127.0.0.1:${guest_vendor_img}"

  validate_local_virgl_import_payload
  vm_start
  wait_for_guest_ssh
  stage_local_virgl_import_payload_to_remote

  guest_mkdir_cmd="$(guest_ssh_transport_cmd) ${(qqq)guest_mkdir_path_cmd}"
  guest_scp_cmd="$(guest_scp_transport_cmd)"
  guest_system_copy_cmd="${guest_scp_cmd} ${(qqq)VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG} ${(qqq)guest_system_target}"
  guest_vendor_copy_cmd="${guest_scp_cmd} ${(qqq)VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG} ${(qqq)guest_vendor_target}"

  copy_cmd=$(cat <<EOF
set -euo pipefail
echo 'IMPORT_COPY_BEGIN'
test -f ${(qqq)VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG}
test -f ${(qqq)VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG}
${guest_mkdir_cmd}
${guest_system_copy_cmd}
${guest_vendor_copy_cmd}
echo 'IMPORT_COPY_DONE'
EOF
)

  log "copying staged Guest4K images into ${VIRGL_SRCBUILD_IMPORT_GUEST_DIR}"
  run_remote "bash -lc ${(qqq)copy_cmd}"

  guest_cmd=$(cat <<EOF
set -euo pipefail
workdir=${(qqq)VIRGL_SRCBUILD_IMPORT_GUEST_DIR}
system_img=${(qqq)guest_system_img}
vendor_img=${(qqq)guest_vendor_img}
mnt_system=${(qqq)guest_mnt_system}
mnt_vendor=${(qqq)guest_mnt_vendor}
merged_root=${(qqq)guest_merged_root}
compat_ref_cid=""
compat_new_cid=""
compat_ref_image=${(qqq)guest_compat_ref_image}
compat_commit_image=${(qqq)guest_compat_commit_image}
compat_overlay_files=${(qqq)guest_compat_overlay_files}
cleanup() {
  set +e
  if [ -n "\${compat_ref_cid}" ]; then
    podman umount "\${compat_ref_cid}" >/dev/null 2>&1 || true
  fi
  if [ -n "\${compat_new_cid}" ]; then
    podman umount "\${compat_new_cid}" >/dev/null 2>&1 || true
  fi
  if [ -n "\${compat_ref_cid}" ] || [ -n "\${compat_new_cid}" ]; then
    podman rm -f "\${compat_ref_cid}" "\${compat_new_cid}" >/dev/null 2>&1 || true
  fi
  if mountpoint -q "\${mnt_vendor}" >/dev/null 2>&1; then
    umount "\${mnt_vendor}" >/dev/null 2>&1 || true
  fi
  if mountpoint -q "\${mnt_system}" >/dev/null 2>&1; then
    umount "\${mnt_system}" >/dev/null 2>&1 || true
  fi
  rm -rf "\${mnt_system}" "\${mnt_vendor}" "\${merged_root}"
}
trap cleanup EXIT
echo 'IMPORT_BEGIN'
mkdir -p "\${workdir}"
rm -rf "\${mnt_system}" "\${mnt_vendor}" "\${merged_root}"
mkdir -p "\${mnt_system}" "\${mnt_vendor}" "\${merged_root}"
test -f "\${system_img}"
test -f "\${vendor_img}"
mount -o loop,ro ${(qqq)guest_system_img} ${(qqq)guest_mnt_system}
mount -o loop,ro ${(qqq)guest_vendor_img} ${(qqq)guest_mnt_vendor}
tar --xattrs -C ${(qqq)guest_mnt_system} -cf - . | tar --xattrs -C ${(qqq)guest_merged_root} -xf -
mkdir -p ${(qqq)guest_merged_vendor}
if [ -d ${(qqq)guest_mnt_vendor_subdir} ]; then
  tar --xattrs -C ${(qqq)guest_mnt_vendor} -cf - vendor | tar --xattrs -C ${(qqq)guest_merged_root} -xf -
else
  tar --xattrs -C ${(qqq)guest_mnt_vendor} -cf - . | tar --xattrs -C ${(qqq)guest_merged_vendor} -xf -
fi
podman image rm -f ${VIRGL_SRCBUILD_IMPORT_IMAGE} >/dev/null 2>&1 || true
tar --xattrs -C "\${merged_root}" -cf - . | podman import \\
  -c 'ENTRYPOINT ["/init"]' \\
  -c 'CMD ["qemu=1","androidboot.hardware=redroid","androidboot.use_redroid_vnc=1","redroid_gpu_mode=guest","redroid_gpu_node=/dev/dri/card0"]' \\
  - ${VIRGL_SRCBUILD_IMPORT_IMAGE} >/dev/null
if [ -n "\${compat_ref_image}" ]; then
  echo 'IMPORT_COMPAT_OVERLAY_BEGIN'
  compat_ref_cid=\$(podman create "\${compat_ref_image}")
  compat_new_cid=\$(podman create ${VIRGL_SRCBUILD_IMPORT_IMAGE})
  compat_ref_mnt=\$(podman mount "\${compat_ref_cid}")
  compat_new_mnt=\$(podman mount "\${compat_new_cid}")
  for overlay_path in \${compat_overlay_files}; do
    rel_path=\${overlay_path#/}
    install -D -m 0644 /dev/null "\${compat_new_mnt}/\${rel_path}"
    cp -a "\${compat_ref_mnt}/\${rel_path}" "\${compat_new_mnt}/\${rel_path}"
    echo "IMPORT_COMPAT_OVERLAY \${overlay_path}"
  done
  podman umount "\${compat_ref_cid}" >/dev/null 2>&1 || true
  compat_ref_cid=""
  podman umount "\${compat_new_cid}" >/dev/null 2>&1 || true
  podman image rm -f "\${compat_commit_image}" >/dev/null 2>&1 || true
  podman commit "\${compat_new_cid}" "\${compat_commit_image}" >/dev/null
  podman rm -f "\${compat_new_cid}" >/dev/null 2>&1 || true
  compat_new_cid=""
  podman image rm -f ${VIRGL_SRCBUILD_IMPORT_IMAGE} >/dev/null 2>&1 || true
  podman tag "\${compat_commit_image}" ${VIRGL_SRCBUILD_IMPORT_IMAGE}
  podman image rm -f "\${compat_commit_image}" >/dev/null 2>&1 || true
  echo 'IMPORT_COMPAT_OVERLAY_END'
fi
inspect_state=\$(podman image inspect ${VIRGL_SRCBUILD_IMPORT_IMAGE} --format '{{json .Config.Entrypoint}}|{{json .Config.Cmd}}')
echo "IMPORT_READY ${VIRGL_SRCBUILD_IMPORT_IMAGE}|\${inspect_state}"
trap - EXIT
cleanup
echo "IMPORT_ROLLOUT_HINT VIRGL_SRCBUILD_IMAGE=${VIRGL_SRCBUILD_IMPORT_IMAGE} zsh redroid/scripts/redroid_guest4k_107.sh virgl-srcbuild-rollout"
EOF
)

  log "importing Guest4K image tag ${VIRGL_SRCBUILD_IMPORT_IMAGE} from staged system/vendor payload"
  run_guest_sudo "${guest_cmd}"
}

rollout_virgl_srcbuild() {
  local guest_cmd
  local health_cmd
  local health_output
  local health_retry_cmd
  local health_retry_output=""
  local combined_health_output
  local logcat_clear_cmd

  require_supported_graphics_profile
  vm_start
  wait_for_guest_ssh
  logcat_clear_cmd="$(guest_container_logcat_clear_cmd "${VIRGL_SRCBUILD_ROLLOUT_CONTAINER}")"

  guest_cmd=$(cat <<EOF
set -euo pipefail
handoff_started=0
auto_restore() {
  set +e
  if [ "\${handoff_started}" != "1" ]; then
    return
  fi
  echo 'ROLLOUT_FAILED'
  podman stop -t 10 ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} >/dev/null 2>&1 || true
  podman start ${CONTAINER} >/dev/null 2>&1 || true
  state=\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || true)
  echo "AUTO_RESTORED \${state}"
}
echo 'ROLLOUT_PRECHECK_BEGIN'
podman container exists ${VIRGL_SRCBUILD_CONTROL_CONTAINER}
podman container exists ${CONTAINER}
echo 'ROLLOUT_PRECHECK_END'
trap auto_restore EXIT
podman rm -f ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} >/dev/null 2>&1 || true
echo 'ROLLOUT_CLONE_BEGIN'
podman container clone ${VIRGL_SRCBUILD_CONTROL_CONTAINER} ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} ${VIRGL_SRCBUILD_IMAGE} >/dev/null
echo "ROLLOUT_CLONED \$(podman container inspect ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} --format '{{.ImageName}}|{{range .Mounts}}{{if eq .Destination "/data"}}{{if .Name}}{{.Name}}{{else}}{{.Source}}{{end}}{{end}}{{end}}')"
echo 'ROLLOUT_STOP_CONTROL'
handoff_started=1
podman stop -t 10 ${CONTAINER} >/dev/null 2>&1 || true
podman stop -t 10 ${VIRGL_SRCBUILD_CONTROL_CONTAINER} >/dev/null 2>&1 || true
podman start ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} >/dev/null
${logcat_clear_cmd}
echo "ROLLOUT_STARTED \$(podman container inspect ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} --format '{{.State.Status}}|{{.ImageName}}')"
trap - EXIT
EOF
)

  log "running virgl-srcbuild-rollout from ${VIRGL_SRCBUILD_CONTROL_CONTAINER} onto ${VIRGL_SRCBUILD_IMAGE}"
  if ! run_guest_sudo "${guest_cmd}"; then
    return 1
  fi

  if ! connect_adb || ! wait_for_boot || ! post_boot_prepare; then
    log "rollout boot preparation failed; restoring preserved control container"
    printf 'ROLLOUT_FAILED\n'
    restore_virgl_srcbuild_rollout
    return 1
  fi

  health_cmd="$(rollout_health_capture_cmd ROLLOUT_HEALTH_BEGIN ROLLOUT_HEALTH_END)"
  health_retry_cmd="$(rollout_health_capture_cmd ROLLOUT_HEALTH_RETRY_BEGIN ROLLOUT_HEALTH_RETRY_END "${VIRGL_SRCBUILD_ROLLOUT_RETRY_SECONDS}")"

  if ! health_output="$(run_guest_sudo_capture "${health_cmd}")"; then
    printf '%s\n' "${health_output}"
    log "rollout health capture failed; restoring preserved control container"
    printf 'ROLLOUT_FAILED\n'
    restore_virgl_srcbuild_rollout
    return 1
  fi
  printf '%s\n' "${health_output}"

  if (( DRY_RUN )); then
    health_retry_output="$(run_guest_sudo_capture "${health_retry_cmd}")"
    printf '%s\n' "${health_retry_output}"
    printf 'ROLLOUT_ACTIVE dry-run\n'
    return 0
  fi

  combined_health_output="${health_output}"
  if rollout_health_needs_retry "${health_output}"; then
    if ! health_retry_output="$(run_guest_sudo_capture "${health_retry_cmd}")"; then
      printf '%s\n' "${health_retry_output}"
      log "rollout health retry capture failed; restoring preserved control container"
      printf 'ROLLOUT_FAILED\n'
      restore_virgl_srcbuild_rollout
      return 1
    fi
    printf '%s\n' "${health_retry_output}"
    combined_health_output+=$'\n'"${health_retry_output}"
  fi

  if ! rollout_health_gate_passes "${combined_health_output}"; then
    log "rollout health gate failed; restoring preserved control container"
    printf 'ROLLOUT_FAILED\n'
    restore_virgl_srcbuild_rollout
    return 1
  fi

  printf 'ROLLOUT_ACTIVE %s\n' "${VIRGL_SRCBUILD_ROLLOUT_CONTAINER}"
}

rollback_virgl_srcbuild_rollout() {
  local guest_cmd

  wait_for_guest_ssh

  guest_cmd=$(cat <<EOF
set -euo pipefail
echo 'ROLLBACK_BEGIN'
podman stop -t 10 ${VIRGL_SRCBUILD_ROLLOUT_CONTAINER} >/dev/null 2>&1 || true
state=\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || true)
if [ "\${state%%|*}" != "running" ]; then
  podman start ${CONTAINER} >/dev/null 2>&1 || true
  state=\$(podman container inspect ${CONTAINER} --format '{{.State.Status}}|{{.ImageName}}' 2>/dev/null || true)
fi
echo "ROLLBACK_RESTORED \${state}"
test "\${state%%|*}" = "running"
EOF
)

  log "running virgl-srcbuild-rollback back to ${CONTAINER}"
  run_guest_sudo "${guest_cmd}"
}

compare_virgl_fingerprints() {
  local guest_cmd
  local logcat_clear_cmd
  local control_runtime_container="${VIRGL_SRCBUILD_CONTROL_CONTAINER}-fingerprintcontrol"
  local control_logcat_clear_cmd
  local control_gpu_config_bootstrap_cmd
  local gpu_config_bootstrap_helper_cmd
  local mainline_handoff_helper_cmd
  local portless_runtime_helper_cmd
  local probe_gpu_config_bootstrap_cmd
  local runtime_guard_helper_cmd

  wait_for_guest_ssh
  logcat_clear_cmd="$(guest_container_logcat_clear_if_running_cmd "${VIRGL_FINGERPRINT_PROBE_CONTAINER}")"
  control_logcat_clear_cmd="$(guest_container_logcat_clear_if_running_cmd "${control_runtime_container}")"
  control_gpu_config_bootstrap_cmd="$(guest_container_gpu_config_bootstrap_if_running_cmd "${control_runtime_container}" "CONTROL_GPU_CONFIG_BOOTSTRAP_SKIPPED")"
  probe_gpu_config_bootstrap_cmd="$(guest_container_gpu_config_bootstrap_if_running_cmd "${VIRGL_FINGERPRINT_PROBE_CONTAINER}" "PROBE_GPU_CONFIG_BOOTSTRAP_SKIPPED")"
  gpu_config_bootstrap_helper_cmd="$(guest_container_gpu_config_bootstrap_helper_cmd)"
  mainline_handoff_helper_cmd="$(guest_container_mainline_handoff_helper_cmd)"
  portless_runtime_helper_cmd="$(guest_container_portless_runtime_helper_cmd)"
  runtime_guard_helper_cmd="$(guest_container_runtime_guard_helper_cmd)"

  guest_cmd=$(cat <<EOF
set -euo pipefail
${portless_runtime_helper_cmd}
${runtime_guard_helper_cmd}
${mainline_handoff_helper_cmd}
${gpu_config_bootstrap_helper_cmd}
fingerprint_container() {
  state_label="\$1"
  props_begin="\$2"
  props_end="\$3"
  props_skip="\$4"
  libs_begin="\$5"
  libs_end="\$6"
  libs_skip="\$7"
  logs_begin="\$8"
  logs_end="\$9"
  logs_skip="\${10}"
  display_logs_begin="\${11}"
  display_logs_end="\${12}"
  display_logs_skip="\${13}"
  container="\${14}"
  echo "\${state_label} \$(podman container inspect "\${container}" --format '{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}|{{.ImageName}}')"
  echo "\${props_begin}"
  podman_exec_if_running "\${container}" "\${props_skip}" /system/bin/sh -lc '
for prop in \
  ro.hardware.egl \
  ro.hardware.vulkan \
  ro.hardware.gralloc \
  sys.boot_completed \
  init.svc.surfaceflinger \
  init.svc.vendor.hwcomposer-3 \
  init.svc.vendor.graphics.allocator \
  sys.init.updatable_crashing_process_name
do
  printf "%s=" "\$prop"
  /system/bin/getprop "\$prop"
done
ps -A | grep -E "(surfaceflinger|allocator|composer)" || true
'
  echo "\${props_end}"
  echo "\${libs_begin}"
  podman_exec_if_running "\${container}" "\${libs_skip}" /system/bin/sh -lc '
for path in \
  /system/lib64/libEGL.so \
  /vendor/lib64/egl/libEGL_mesa.so \
  /vendor/lib64/egl/libGLESv2_mesa.so \
  /vendor/lib64/dri/libgallium_dri.so \
  /vendor/lib64/libgbm.so.1 \
  /vendor/lib64/hw/gralloc.cros.so \
  /vendor/lib64/hw/gralloc.minigbm.so \
  /vendor/lib64/hw/mapper.minigbm.so
do
  echo "LIB \$path"
  if [ -e "\$path" ]; then
    ls -l "\$path"
    /system/bin/toybox sha256sum "\$path" || true
  else
    echo "MISSING \$path"
  fi
done
'
  echo "\${libs_end}"
  echo "\${logs_begin}"
  podman_exec_if_running "\${container}" "\${logs_skip}" /system/bin/sh -lc '/system/bin/logcat -d | grep -E "Using gralloc0 CrOS API|Using fallback gralloc implementation|failed to create DRI image from FD|eglCreateImageKHR failed|Failed to create a valid texture" || true'
  echo "\${logs_end}"
  echo "\${display_logs_begin}"
  podman_exec_if_running "\${container}" "\${display_logs_skip}" /system/bin/sh -lc '/system/bin/logcat -d | grep -Ei "SurfaceFlinger|hotplug|composer|hwc|HWC|drm_hwcomposer|allocator" | tail -n 120 || true'
  echo "\${display_logs_end}"
}
cleanup() {
  cleanup_status=0
  set +e
  podman stop -t 10 ${control_runtime_container} >/dev/null 2>&1 || true
  podman rm -f ${control_runtime_container} >/dev/null 2>&1 || true
  podman stop -t 10 ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null 2>&1 || true
  podman rm -f ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null 2>&1 || true
  restore_standard_mainline_if_needed || cleanup_status=\$?
  return "\${cleanup_status}"
}
trap cleanup EXIT
stop_standard_mainline_if_running
echo 'CONTROL_CAPTURE_BEGIN'
podman rm -f ${control_runtime_container} >/dev/null 2>&1 || true
create_portless_runtime_from_template ${VIRGL_SRCBUILD_CONTROL_CONTAINER} ${control_runtime_container} ""
echo "CONTROL_PORTLESS_CREATE \$(podman container inspect ${control_runtime_container} --format '{{.Name}}|{{.ImageName}}|{{.HostConfig.PortBindings}}')"
podman start ${control_runtime_container} >/dev/null
echo "CONTROL started"
echo 'CONTROL_GPU_CONFIG_BOOTSTRAP_BEGIN'
${control_gpu_config_bootstrap_cmd}
echo 'CONTROL_GPU_CONFIG_BOOTSTRAP_END'
sleep 10
${control_logcat_clear_cmd}
sleep ${VIRGL_FINGERPRINT_SECONDS}
fingerprint_container CONTROL_STATE CONTROL_PROPS_BEGIN CONTROL_PROPS_END CONTROL_PROPS_SKIPPED CONTROL_LIBS_BEGIN CONTROL_LIBS_END CONTROL_LIBS_SKIPPED CONTROL_LOGS_BEGIN CONTROL_LOGS_END CONTROL_LOGS_SKIPPED CONTROL_DISPLAY_LOGS_BEGIN CONTROL_DISPLAY_LOGS_END CONTROL_DISPLAY_LOGS_SKIPPED ${control_runtime_container}
podman stop -t 10 ${control_runtime_container} >/dev/null 2>&1 || true
podman rm -f ${control_runtime_container} >/dev/null 2>&1 || true
echo 'CONTROL_CAPTURE_END'
echo 'PROBE_CAPTURE_BEGIN'
podman rm -f ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null 2>&1 || true
create_portless_runtime_from_template ${VIRGL_SRCBUILD_CONTROL_CONTAINER} ${VIRGL_FINGERPRINT_PROBE_CONTAINER} "" ${VIRGL_SRCBUILD_IMAGE}
echo "PROBE_PORTLESS_CREATE \$(podman container inspect ${VIRGL_FINGERPRINT_PROBE_CONTAINER} --format '{{.Name}}|{{.ImageName}}|{{.HostConfig.PortBindings}}')"
podman start ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null
echo "PROBE started"
echo 'PROBE_GPU_CONFIG_BOOTSTRAP_BEGIN'
${probe_gpu_config_bootstrap_cmd}
echo 'PROBE_GPU_CONFIG_BOOTSTRAP_END'
sleep 10
${logcat_clear_cmd}
sleep ${VIRGL_FINGERPRINT_SECONDS}
fingerprint_container PROBE_STATE PROBE_PROPS_BEGIN PROBE_PROPS_END PROBE_PROPS_SKIPPED PROBE_LIBS_BEGIN PROBE_LIBS_END PROBE_LIBS_SKIPPED PROBE_LOGS_BEGIN PROBE_LOGS_END PROBE_LOGS_SKIPPED PROBE_DISPLAY_LOGS_BEGIN PROBE_DISPLAY_LOGS_END PROBE_DISPLAY_LOGS_SKIPPED ${VIRGL_FINGERPRINT_PROBE_CONTAINER}
podman stop -t 10 ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null 2>&1 || true
podman rm -f ${VIRGL_FINGERPRINT_PROBE_CONTAINER} >/dev/null 2>&1 || true
echo 'PROBE_CAPTURE_END'
trap - EXIT
cleanup
EOF
)

  log "running virgl-fingerprint-compare from ${VIRGL_SRCBUILD_CONTROL_CONTAINER} onto ${VIRGL_SRCBUILD_IMAGE}"
  run_guest_sudo "${guest_cmd}"
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

diagnose_perf() {
  local guest_cmd
  local host_cmd

  wait_for_guest_ssh
  connect_adb
  wait_for_boot

  guest_cmd=$(cat <<EOF
echo '=== guest-podman-ps ==='
podman ps -a --format 'table {{.Names}}\\t{{.Status}}\\t{{.Image}}'
echo '=== guest-podman-stats ==='
podman stats --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.MemPerc}}\\t{{.PIDs}}' ${CONTAINER} 2>/dev/null || true
echo '=== guest-c2-nodes ==='
ls -l /dev/dma_heap/system /dev/ion 2>/dev/null || true
echo '=== guest-container-top ==='
podman top ${CONTAINER} pid hpid pcpu pmem comm args 2>/dev/null || true
EOF
)

  host_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
echo '=== host-qemu-cpu ==='
qemu_pid=\$(ps -eo pid=,command= | awk '/[q]emu-system-aarch64/ && /hostfwd=tcp::2222-:22/ { print \$1; exit }')
if [ -z "\${qemu_pid}" ]; then
  qemu_pid=\$(ps -eo pid=,command= | awk '/[q]emu-system-aarch64/ && /-name guest4k/ { print \$1; exit }')
fi
if [ -z "\${qemu_pid}" ]; then
  qemu_pid=\$(ps -eo pid=,command= | awk '/[q]emu-system-aarch64/ && /vm4k/ { print \$1; exit }')
fi
if [ -n "\${qemu_pid}" ]; then
  echo "QEMU_PID \${qemu_pid}"
  ps -p "\${qemu_pid}" -o pid=,ppid=,pcpu=,pmem=,etime=,args=
  ps -L -p "\${qemu_pid}" -o pid=,tid=,psr=,pcpu=,stat=,comm= --sort=-pcpu | head -n 15
else
  echo 'QEMU_PID missing'
fi
echo '=== host-viewer-cpu ==='
viewer_pid=\$(ps -eo pid=,command= | awk '/[v]ncviewer/ && /${VNC_HOST//./\\.}::${VNC_PORT}/ { print \$1; exit }')
if [ -n "\${viewer_pid}" ]; then
  echo "VIEWER_PID \${viewer_pid}"
  ps -p "\${viewer_pid}" -o pid=,ppid=,pcpu=,pmem=,etime=,args=
  ps -L -p "\${viewer_pid}" -o pid=,tid=,psr=,pcpu=,stat=,comm= --sort=-pcpu | head -n 15
else
  echo 'VIEWER_PID missing'
fi
echo '=== android-props ==='
for prop in \
  ro.vendor.hwcomposer.drm_refresh_rate_cap \
  debug.stagefright.ccodec \
  debug.stagefright.c2inputsurface \
  debug.c2.use_dmabufheaps \
  init.svc.android-hardware-media-c2-goldfish-hal-1-0 \
  debug.hwui.renderer \
  debug.renderengine.backend \
  ro.hardware.egl \
  ro.hardware.vulkan \
  ro.hardware.gralloc
do
  printf '%s=' "\$prop"
  adb -s ${ADB_SERIAL} shell getprop "\$prop" 2>/dev/null | tr -d '\r'
done
echo '=== android-vnc ==='
printf 'init.svc.vncserver='
adb -s ${ADB_SERIAL} shell getprop init.svc.vncserver 2>/dev/null | tr -d '\r'
adb -s ${ADB_SERIAL} shell ps -A 2>/dev/null | grep -i 'vncserver' || true
echo '=== android-c2-nodes ==='
adb -s ${ADB_SERIAL} shell ls -l /dev/dma_heap/system /dev/ion 2>/dev/null || true
echo '=== android-wm ==='
adb -s ${ADB_SERIAL} shell wm size 2>/dev/null || true
adb -s ${ADB_SERIAL} shell wm density 2>/dev/null || true
echo '=== android-display ==='
adb -s ${ADB_SERIAL} shell dumpsys display 2>/dev/null | grep -E 'mDisplayId=|DisplayDeviceInfo|activeModeId|refreshRate|fps|modeId|supportedModes|colorMode' | tail -n ${PERF_DISPLAY_LINES} || true
echo '=== android-top ==='
adb -s ${ADB_SERIAL} shell top -b -n 1 2>/dev/null | grep -E 'PID|surfaceflinger|composer|media\\.codec|mediaserver|system_server|com\\.ss\\.android\\.ugc\\.aweme|android\\.hardware\\.graphics\\.composer|vendor\\.hwcomposer' | tail -n ${PERF_TOP_LINES} || true
echo '=== android-services ==='
adb -s ${ADB_SERIAL} shell service list 2>/dev/null | grep -i 'media\\.c2\\|codec' || true
echo '=== android-media-codec ==='
adb -s ${ADB_SERIAL} shell dumpsys media.codec 2>/dev/null | grep -Ei 'goldfish|codec2|c2\\.|omx|avc|hevc|vp9|video/' | tail -n ${PERF_LOG_LINES} || true
echo '=== android-gfxinfo ==='
adb -s ${ADB_SERIAL} shell dumpsys gfxinfo ${DOUYIN_PACKAGE} framestats 2>/dev/null | tail -n ${PERF_LOG_LINES} || true
echo '=== android-logcat-gfx ==='
adb -s ${ADB_SERIAL} shell logcat -d 2>/dev/null | grep -Ei 'drm_hwcomposer|hwc|SurfaceFlinger|gralloc|codec2|CCodec|MediaCodec|goldfish|lock_ycbcr|AHardwareBuffer|BufferQueue|frame drop|jank' | tail -n ${PERF_LOG_LINES} || true
EOF
)

  log "diagnosing Guest4K perf surfaces on ${ADB_SERIAL}"
  run_guest_sudo "bash -lc ${(qqq)guest_cmd}"
  run_remote "bash -lc ${(qqq)host_cmd}"
}

launch_viewer() {
  local display_env
  local kill_python_cmd
  local kill_screencap_cmd
  local kill_vnc_cmd
  local launch_cmd
  local vncviewer_flags

  require_supported_viewer_mode
  require_supported_tigervnc_profile
  display_env="XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* 2>/dev/null | head -1)"
  kill_python_cmd="pkill -f '/tmp/[r]edroid_viewer.py' 2>/dev/null || true"
  kill_screencap_cmd="pkill -f 'adb -s ${ADB_SERIAL} exec-out sh -c while true; do [s]creencap; done' 2>/dev/null || true"
  kill_vnc_cmd="pkill -f '[v]ncviewer .*${VNC_HOST}::${VNC_PORT}' 2>/dev/null || true"
  if [[ -n "${GUEST4K_TIGERVNC_FLAGS}" ]]; then
    vncviewer_flags="${GUEST4K_TIGERVNC_FLAGS}"
  else
    case "${GUEST4K_TIGERVNC_PROFILE}" in
      lossless|'')
        vncviewer_flags="-AutoSelect=0 -PreferredEncoding=Raw -NoJPEG=1 -CustomCompressLevel=1 -CompressLevel=0 -FullColor=1"
        ;;
      adaptive)
        vncviewer_flags="-AutoSelect=1 -FullColor=1"
        ;;
    esac
  fi

  if [[ "${VIEWER_MODE}" = "python" ]]; then
    require_local_file "${LOCAL_VIEWER_PATH}" "local viewer helper"
    sync_local_file_to_remote "${LOCAL_VIEWER_PATH}" "${REMOTE_VIEWER_PATH}"
    launch_cmd="bash -lc \"export REDROID_VIEWER_ADB_SERIAL=${ADB_SERIAL} ${display_env}; nohup python3 ${REMOTE_VIEWER_PATH} > /tmp/redroid_guest4k_viewer.log 2>&1 < /dev/null &\""
  else
    launch_cmd="bash -lc \"export ${display_env}; nohup vncviewer ${vncviewer_flags} ${VNC_HOST}::${VNC_PORT} > /tmp/redroid_guest4k_tigervnc.log 2>&1 < /dev/null &\""
  fi

  if (( DRY_RUN )); then
    repair_guest_vnc_after_surfaceflinger_restart
    run_remote_capture "${kill_python_cmd}"
    run_remote_capture "${kill_screencap_cmd}"
    run_remote_capture "${kill_vnc_cmd}"
    run_remote_capture "${launch_cmd}"
  else
    repair_guest_vnc_after_surfaceflinger_restart >/dev/null
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
      vm-start|vm-stop|vm-status|restart|restart-preserve-data|phone-mode|restart-legacy|restart-legacy-preserve-data|status|verify|viewer|douyin-install|douyin-start|douyin-diagnose|audio-diagnose|perf-diagnose|virgl-srcbuild-probe|virgl-srcbuild-longrun|virgl-srcbuild-import|virgl-srcbuild-rollout|virgl-srcbuild-rollback|virgl-fingerprint-compare)
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

  apply_perf_preset_defaults

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
      restart_redroid "${IMAGE}" 0
      ;;
    restart-preserve-data)
      restart_redroid "${IMAGE}" 1
      ;;
    phone-mode)
      activate_phone_mode
      ;;
    restart-legacy)
      restart_redroid "${LEGACY_IMAGE}" 0
      ;;
    restart-legacy-preserve-data)
      restart_redroid "${LEGACY_IMAGE}" 1
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
    perf-diagnose)
      diagnose_perf
      ;;
    virgl-srcbuild-probe)
      probe_virgl_srcbuild
      ;;
    virgl-srcbuild-longrun)
      probe_virgl_srcbuild_longrun
      ;;
    virgl-srcbuild-import)
      import_virgl_srcbuild_image
      ;;
    virgl-srcbuild-rollout)
      rollout_virgl_srcbuild
      ;;
    virgl-srcbuild-rollback)
      rollback_virgl_srcbuild_rollout
      ;;
    virgl-fingerprint-compare)
      compare_virgl_fingerprints
      ;;
  esac
}

main "$@"
