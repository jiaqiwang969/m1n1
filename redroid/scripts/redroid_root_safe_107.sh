#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REMOTE_HOST="${REDROID_HOST:-192.168.1.107}"
REMOTE_USER="${REDROID_USER:-wjq}"
SUDO_PASS="${SUDO_PASS:-}"
IMAGE_16K="${IMAGE:-localhost/redroid16k-root:latest}"
CONTAINER_16K="${CONTAINER:-redroid16k-root-safe}"
ADB_SERIAL_16K="${ADB_SERIAL:-127.0.0.1:5555}"
PORT_BIND_16K="${PORT_BIND:-127.0.0.1:5555:5555}"
VNC_PORT_BIND_16K="${VNC_PORT_BIND:-127.0.0.1:5900:5900}"
VOLUME_NAME_16K="${VOLUME_NAME:-redroid16k-data-root}"
IMAGE_4K="${IMAGE_4K:-docker.io/redroid/redroid:16.0.0_64only-latest}"
CONTAINER_4K="${CONTAINER_4K:-redroid4k-root-safe}"
ADB_SERIAL_4K="${ADB_SERIAL_4K:-127.0.0.1:5556}"
PORT_BIND_4K="${PORT_BIND_4K:-127.0.0.1:5556:5555}"
VNC_PORT_BIND_4K="${VNC_PORT_BIND_4K:-127.0.0.1:5901:5900}"
VOLUME_NAME_4K="${VOLUME_NAME_4K:-redroid4k-data-root}"
RUNTIME_PROFILE_ID="16k"
IMAGE="${IMAGE_16K}"
CONTAINER="${CONTAINER_16K}"
ADB_SERIAL="${ADB_SERIAL_16K}"
PORT_BIND="${PORT_BIND_16K}"
VNC_PORT_BIND="${VNC_PORT_BIND_16K}"
VOLUME_NAME="${VOLUME_NAME_16K}"
LOCAL_VIEWER_PATH="${LOCAL_VIEWER_PATH:-${REPO_ROOT}/redroid/tools/redroid_viewer.py}"
REMOTE_VIEWER_PATH="${REMOTE_VIEWER_PATH:-/tmp/redroid_viewer.py}"
LOCAL_ELF_TOOL_PATH="${LOCAL_ELF_TOOL_PATH:-${REPO_ROOT}/redroid/tools/elf_relro16k.py}"
LOCAL_PHONE_PROFILE_PATH="${LOCAL_PHONE_PROFILE_PATH:-${REPO_ROOT}/redroid/profiles/china-phone.env}"
REMOTE_PHONE_PROFILE_DIR="${REMOTE_PHONE_PROFILE_DIR:-/tmp/redroid-phone-profile}"
REMOTE_PHONE_SYSTEM_PROP="${REMOTE_PHONE_SYSTEM_PROP:-${REMOTE_PHONE_PROFILE_DIR}/system.build.prop}"
REMOTE_PHONE_VENDOR_PROP="${REMOTE_PHONE_VENDOR_PROP:-${REMOTE_PHONE_PROFILE_DIR}/vendor.build.prop}"
REMOTE_PHONE_XBIN_DIR="${REMOTE_PHONE_XBIN_DIR:-${REMOTE_PHONE_PROFILE_DIR}/system_xbin}"
REMOTE_PHONE_ADB_KEYS="${REMOTE_PHONE_ADB_KEYS:-${REMOTE_PHONE_PROFILE_DIR}/adb_keys}"
REMOTE_ADB_KEY_SOURCE="${REMOTE_ADB_KEY_SOURCE:-/home/${REMOTE_USER}/.android/adbkey.pub}"
DOUYIN_PACKAGE="${DOUYIN_PACKAGE:-com.ss.android.ugc.aweme}"
TARGET_PAGE_SIZE_COMPAT="${TARGET_PAGE_SIZE_COMPAT:-36}"
LOCAL_DOUYIN_ORIGINAL_LIBTNET_PATH="${LOCAL_DOUYIN_ORIGINAL_LIBTNET_PATH:-${REPO_ROOT}/tmp/douyin/extract/lib/arm64-v8a/libtnet-3.1.14.so}"
LOCAL_DOUYIN_PATCHED_LIBTNET_PATH="${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH:-${REPO_ROOT}/tmp/douyin/patched/libtnet-3.1.14.so}"
REMOTE_DOUYIN_LIBTNET_STAGE_DIR="${REMOTE_DOUYIN_LIBTNET_STAGE_DIR:-/tmp/redroid-douyin-libtnet}"
REMOTE_DOUYIN_LIBTNET_STAGE_PATH="${REMOTE_DOUYIN_LIBTNET_STAGE_PATH:-${REMOTE_DOUYIN_LIBTNET_STAGE_DIR}/libtnet-3.1.14.so}"
GUEST_DOUYIN_LIBTNET_STAGE_DIR="${GUEST_DOUYIN_LIBTNET_STAGE_DIR:-/data/local/tmp/redroid-douyin-libtnet}"
GUEST_DOUYIN_LIBTNET_STAGE_PATH="${GUEST_DOUYIN_LIBTNET_STAGE_PATH:-${GUEST_DOUYIN_LIBTNET_STAGE_DIR}/libtnet-3.1.14.so}"
REMOTE_DOUYIN_LIBTNET_BACKUP_DIR="${REMOTE_DOUYIN_LIBTNET_BACKUP_DIR:-/tmp/redroid-douyin-libtnet-backups}"
REMOTE_DOUYIN_LIBTNET_BACKUP_PATH="${REMOTE_DOUYIN_LIBTNET_BACKUP_PATH:-${REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}/libtnet-3.1.14.so.original}"
REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH="${REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH:-${REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}/runtime-copies.manifest}"
REMOTE_DOUYIN_APK_METADATA_PATH="${REMOTE_DOUYIN_APK_METADATA_PATH:-${REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}/apk-copy.metadata}"
REMOTE_DOUYIN_LIVE_PULL_PATH="${REMOTE_DOUYIN_LIVE_PULL_PATH:-${REMOTE_DOUYIN_LIBTNET_STAGE_DIR}/libtnet-live.so}"
DRY_RUN_DOUYIN_APK_PATH="${DRY_RUN_DOUYIN_APK_PATH:-/data/app/~~example/com.ss.android.ugc.aweme-example/base.apk}"
DRY_RUN=0

if [[ ! -f "${LOCAL_PHONE_PROFILE_PATH}" ]]; then
  printf 'Missing phone profile: %s\n' "${LOCAL_PHONE_PROFILE_PATH}" >&2
  exit 1
fi

source "${LOCAL_PHONE_PROFILE_PATH}"

usage() {
  cat <<'EOF'
Usage: zsh redroid/scripts/redroid_root_safe_107.sh [--dry-run] <restart|status|verify|viewer|douyin-compat|douyin-libtnet-status|douyin-libtnet-install|douyin-libtnet-verify|douyin-libtnet-restore|phone-mode|restart-4k|status-4k|verify-4k|viewer-4k>

Actions:
  restart   Recreate the known-good redroid container on 192.168.1.107
  status    Show current container/image state
  verify    Check ADB visibility and boot-critical properties
  viewer    Launch interactive Redroid viewer on the KDE desktop
  douyin-compat  Apply the verified Douyin page-size compat workaround and restart
  douyin-libtnet-status  Show the live Douyin libtnet path and hash state
  douyin-libtnet-install  Install the configured patched libtnet into the live Douyin app dir
  douyin-libtnet-verify  Verify the live Douyin libtnet hash and ELF header shape
  douyin-libtnet-restore  Restore the original Douyin libtnet from backup
  phone-mode  Restart with a phone-like runtime profile for China-app testing
  restart-4k  Recreate the explicit 4 KB Redroid runtime path
  status-4k   Show current 4 KB container/image state
  verify-4k   Check ADB visibility and boot-critical properties on the 4 KB path
  viewer-4k   Launch the viewer against the 4 KB ADB endpoint
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
    printf 'SUDO_PASS is required for remote sudo commands.\n' >&2
    return 1
  fi
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
  local ssh_cmd="ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} ${(qqq)cmd}"
  if (( DRY_RUN )); then
    printf 'DRY-RUN ssh: %s@%s\n' "$REMOTE_USER" "$REMOTE_HOST"
    printf 'DRY-RUN remote: %s\n' "$cmd"
    return 0
  fi
  run_local "$ssh_cmd"
}

run_remote_capture() {
  local cmd="$1"
  if (( DRY_RUN )); then
    printf 'DRY-RUN ssh: %s@%s\n' "$REMOTE_USER" "$REMOTE_HOST"
    printf 'DRY-RUN remote: %s\n' "$cmd"
    return 0
  fi
  ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" "$cmd"
}

run_remote_sudo() {
  local cmd="$1"
  local wrapped
  require_sudo_pass
  if (( DRY_RUN )); then
    printf 'DRY-RUN ssh: %s@%s\n' "$REMOTE_USER" "$REMOTE_HOST"
    printf 'DRY-RUN sudo: %s\n' "$cmd"
    return 0
  fi
  wrapped=$(printf "printf '%%s\\\\n' %q | sudo -S -p '' sh -lc %q" "$SUDO_PASS" "$cmd")
  run_remote "$wrapped"
}

require_local_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "${path}" ]]; then
    printf 'Missing %s: %s\n' "${label}" "${path}" >&2
    return 1
  fi
}

sha256_local() {
  local path="$1"
  /usr/bin/python3 - "$path" <<'PY'
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
print(hashlib.sha256(path.read_bytes()).hexdigest())
PY
}

sync_local_file_to_remote() {
  local local_path="$1"
  local remote_path="$2"
  local remote_target="${REMOTE_USER}@${REMOTE_HOST}:${remote_path}"
  local scp_cmd="scp -o StrictHostKeyChecking=no ${(qqq)local_path} ${(qqq)remote_target}"
  run_local "$scp_cmd"
}

fetch_remote_file_to_local() {
  local remote_path="$1"
  local local_path="$2"
  local remote_target="${REMOTE_USER}@${REMOTE_HOST}:${remote_path}"
  local scp_cmd="scp -o StrictHostKeyChecking=no ${(qqq)remote_target} ${(qqq)local_path}"
  run_local "$scp_cmd"
}

select_runtime_profile() {
  local profile="${1:-16k}"

  case "${profile}" in
    16k)
      RUNTIME_PROFILE_ID="16k"
      IMAGE="${IMAGE_16K}"
      CONTAINER="${CONTAINER_16K}"
      ADB_SERIAL="${ADB_SERIAL_16K}"
      PORT_BIND="${PORT_BIND_16K}"
      VNC_PORT_BIND="${VNC_PORT_BIND_16K}"
      VOLUME_NAME="${VOLUME_NAME_16K}"
      ;;
    4k)
      RUNTIME_PROFILE_ID="4k"
      IMAGE="${IMAGE_4K}"
      CONTAINER="${CONTAINER_4K}"
      ADB_SERIAL="${ADB_SERIAL_4K}"
      PORT_BIND="${PORT_BIND_4K}"
      VNC_PORT_BIND="${VNC_PORT_BIND_4K}"
      VOLUME_NAME="${VOLUME_NAME_4K}"
      ;;
    *)
      printf 'Unknown runtime profile: %s\n' "${profile}" >&2
      return 1
      ;;
  esac
}

host_port_from_bind() {
  local bind="$1"
  local remainder="${bind#*:}"
  printf '%s\n' "${remainder%%:*}"
}

assert_runtime_profile_supported() {
  local page_size=""

  if [[ "${RUNTIME_PROFILE_ID}" != "4k" ]]; then
    return 0
  fi

  if (( DRY_RUN )); then
    printf 'DRY-RUN note: 4k runtime requires a 4096-byte host page size on %s\n' "${REMOTE_HOST}"
    return 0
  fi

  page_size="$(
    ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" "getconf PAGE_SIZE" 2>/dev/null | tr -d '\r'
  )"

  if [[ "${page_size}" != "4096" ]]; then
    printf '4k runtime requires a 4096-byte host page size, but %s reports %s. Redroid shares the host kernel page size, so this route is not supported on the current host.\n' "${REMOTE_HOST}" "${page_size:-unknown}" >&2
    return 1
  fi
}

connect_adb() {
  log "ensuring adb is connected to ${ADB_SERIAL}"
  run_remote "adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true"
}

wait_for_boot() {
  local wait_cmd
  wait_cmd=$(cat <<EOF
for _ in \$(seq 1 60); do
  boot=\$(adb -s ${ADB_SERIAL} shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  vnc=\$(adb -s ${ADB_SERIAL} shell getprop init.svc.vendor.vncserver 2>/dev/null | tr -d '\r')
  if [ "\$boot" = "1" ] && [ "\$vnc" = "running" ]; then
    exit 0
  fi
  sleep 2
done
echo "Timed out waiting for Android boot on ${ADB_SERIAL}" >&2
exit 1
EOF
)

  log "waiting for Android boot and VNC service"
  run_remote "bash -lc ${(qqq)wait_cmd}"
}

show_douyin_compat_state() {
  local compat_cmd
  compat_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
if adb -s ${ADB_SERIAL} shell pm path ${DOUYIN_PACKAGE} >/dev/null 2>&1; then
  adb -s ${ADB_SERIAL} shell dumpsys package ${DOUYIN_PACKAGE} | grep -i 'pageSizeCompat'
else
  echo "${DOUYIN_PACKAGE} not installed"
fi
EOF
)

  run_remote "bash -lc ${(qqq)compat_cmd}"
}

resolve_douyin_apk_path() {
  local resolve_cmd
  if (( DRY_RUN )); then
    printf '%s\n' "${DRY_RUN_DOUYIN_APK_PATH}"
    return 0
  fi

  resolve_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell pm path ${DOUYIN_PACKAGE} 2>/dev/null | tr -d '\r' | sed -n '1s/^package://p'
EOF
)

  run_remote_capture "bash -lc ${(qqq)resolve_cmd}" | tr -d '\r' | tail -n 1
}

resolve_douyin_libt_tnet_path() {
  local apk_path="$1"
  if [[ -z "${apk_path}" ]]; then
    return 1
  fi
  printf '%s\n' "$(dirname "${apk_path}")/lib/arm64/libtnet-3.1.14.so"
}

list_douyin_runtime_libt_tnet_paths() {
  local list_cmd
  if (( DRY_RUN )); then
    printf '%s\n' "/data/user/0/${DOUYIN_PACKAGE}/app_librarian/<version>/libtnet-3.1.14.so"
    printf '%s\n' "/data/data/${DOUYIN_PACKAGE}/app_librarian/<version>/libtnet-3.1.14.so"
    return 0
  fi

  list_cmd=$(cat <<EOF
set -euo pipefail
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell 'for f in /data/user/0/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so /data/data/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so; do [ -f "\$f" ] && echo "\$f"; done' 2>/dev/null | tr -d '\r'
EOF
)

  run_remote_capture "bash -lc ${(qqq)list_cmd}" | sed '/^$/d'
}

ensure_douyin_libt_tnet_stage_dir() {
  run_remote "mkdir -p ${(qqq)REMOTE_DOUYIN_LIBTNET_STAGE_DIR} ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}"
}

pull_live_douyin_libt_tnet_to_local() {
  local live_path="$1"
  local local_path="$2"
  local pull_cmd

  pull_cmd=$(cat <<EOF
set -euo pipefail
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
mkdir -p ${(qqq)REMOTE_DOUYIN_LIBTNET_STAGE_DIR}
adb -s ${ADB_SERIAL} pull ${(qqq)live_path} ${(qqq)REMOTE_DOUYIN_LIVE_PULL_PATH} >/dev/null
EOF
)

  run_remote "bash -lc ${(qqq)pull_cmd}"
  fetch_remote_file_to_local "${REMOTE_DOUYIN_LIVE_PULL_PATH}" "${local_path}"
}

print_live_libt_tnet_elf_summary() {
  local local_path="$1"
  log "live ELF summary (PT_LOAD / PT_GNU_RELRO)"
  run_local "/usr/bin/python3 ${(qqq)LOCAL_ELF_TOOL_PATH} summary ${(qqq)local_path}"
}

show_douyin_libt_tnet_state() {
  local apk_path=""
  local live_path=""
  local live_copy=""
  local original_hash=""
  local patch_hash=""
  local runtime_paths=""
  local audit_cmd=""

  require_local_file "${LOCAL_DOUYIN_ORIGINAL_LIBTNET_PATH}" "local original libtnet"
  require_local_file "${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}" "local patched libtnet"

  if (( DRY_RUN )); then
    original_hash="<local-original-sha256>"
    patch_hash="<local-patched-sha256>"
  else
    original_hash="$(sha256_local "${LOCAL_DOUYIN_ORIGINAL_LIBTNET_PATH}")"
    patch_hash="$(sha256_local "${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}")"
  fi

  connect_adb
  log "resolving Douyin install path"
  log "using pm path ${DOUYIN_PACKAGE} to resolve the active APK copy"
  apk_path="$(resolve_douyin_apk_path)"
  if [[ -z "${apk_path}" ]]; then
    printf '%s is not installed or no APK path was returned.\n' "${DOUYIN_PACKAGE}" >&2
    return 1
  fi
  live_path="$(resolve_douyin_libt_tnet_path "${apk_path}")"
  runtime_paths="$(list_douyin_runtime_libt_tnet_paths)"

  log "Douyin APK path"
  printf '%s\n' "${apk_path}"
  log "APK install-copy libtnet path"
  printf '%s\n' "${live_path}"
  log "observed app_librarian runtime-copy paths"
  if [[ -n "${runtime_paths}" ]]; then
    printf '%s\n' "${runtime_paths}"
  else
    printf '%s\n' "<none>"
  fi
  log "local original sha256"
  printf '%s  %s\n' "${original_hash}" "${LOCAL_DOUYIN_ORIGINAL_LIBTNET_PATH}"
  log "local patched sha256"
  printf '%s  %s\n' "${patch_hash}" "${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}"
  log "inode and sha256 audit for apk + app_librarian copies"
  audit_cmd=$(cat <<EOF
set -euo pipefail
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
echo "=== inode audit ==="
adb -s ${ADB_SERIAL} shell "ls -li ${(qqq)live_path}"
while IFS= read -r runtime_path; do
  [ -n "\$runtime_path" ] || continue
  adb -s ${ADB_SERIAL} shell "ls -li \"\$runtime_path\""
done < <(
  adb -s ${ADB_SERIAL} shell 'for f in /data/user/0/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so /data/data/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so; do [ -f "\$f" ] && echo "\$f"; done' 2>/dev/null | tr -d '\r'
)
echo "=== sha256 audit ==="
adb -s ${ADB_SERIAL} shell "sha256sum ${(qqq)live_path}"
while IFS= read -r runtime_path; do
  [ -n "\$runtime_path" ] || continue
  adb -s ${ADB_SERIAL} shell "sha256sum \"\$runtime_path\""
done < <(
  adb -s ${ADB_SERIAL} shell 'for f in /data/user/0/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so /data/data/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so; do [ -f "\$f" ] && echo "\$f"; done' 2>/dev/null | tr -d '\r'
)
EOF
)
  run_remote "bash -lc ${(qqq)audit_cmd}"

  if (( DRY_RUN )); then
    print_live_libt_tnet_elf_summary "/tmp/libtnet-live.so"
    return 0
  fi

  live_copy="$(mktemp -t libtnet-live)"
  pull_live_douyin_libt_tnet_to_local "${live_path}" "${live_copy}"
  print_live_libt_tnet_elf_summary "${live_copy}"
  rm -f "${live_copy}"
}

install_douyin_libt_tnet_patch() {
  local apk_path=""
  local live_path=""
  local install_cmd=""

  require_local_file "${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}" "local patched libtnet"
  ensure_douyin_libt_tnet_stage_dir
  connect_adb

  log "resolving Douyin install path"
  log "using pm path ${DOUYIN_PACKAGE} to resolve the active APK copy"
  apk_path="$(resolve_douyin_apk_path)"
  if [[ -z "${apk_path}" ]]; then
    printf '%s is not installed or no APK path was returned.\n' "${DOUYIN_PACKAGE}" >&2
    return 1
  fi
  live_path="$(resolve_douyin_libt_tnet_path "${apk_path}")"

  log "staging patched libtnet from ${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}"
  sync_local_file_to_remote "${LOCAL_DOUYIN_PATCHED_LIBTNET_PATH}" "${REMOTE_DOUYIN_LIBTNET_STAGE_PATH}"

  log "install workflow uses adb push into a guest staging path before cp -p fan-out"
  log "installing patched libtnet into apk + app_librarian runtime copies"
  install_cmd=$(cat <<EOF
set -euo pipefail
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
mkdir -p ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}
adb -s ${ADB_SERIAL} shell "mkdir -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_DIR}"
adb -s ${ADB_SERIAL} push ${(qqq)REMOTE_DOUYIN_LIBTNET_STAGE_PATH} ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} >/dev/null
if [ ! -f ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_PATH} ]; then
  adb -s ${ADB_SERIAL} pull ${(qqq)live_path} ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_PATH} >/dev/null
fi
apk_owner=\$(adb -s ${ADB_SERIAL} shell "stat -c '%u:%g' ${(qqq)live_path}" | tr -d '\r')
apk_mode=\$(adb -s ${ADB_SERIAL} shell "stat -c '%a' ${(qqq)live_path}" | tr -d '\r')
apk_ref_owner=\$(adb -s ${ADB_SERIAL} shell "stat -c '%u:%g' ${(qqq)apk_path}" | tr -d '\r')
if [ "\$apk_owner" = "0:0" ] && [ -n "\$apk_ref_owner" ]; then
  apk_owner="\$apk_ref_owner"
fi
printf '%s|%s\n' "\$apk_owner" "\$apk_mode" > ${(qqq)REMOTE_DOUYIN_APK_METADATA_PATH}
: > ${(qqq)REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH}
runtime_index=0
while IFS= read -r runtime_path; do
  [ -n "\$runtime_path" ] || continue
  runtime_index=\$((runtime_index + 1))
  backup_path="${REMOTE_DOUYIN_LIBTNET_BACKUP_DIR}/runtime-\${runtime_index}.libtnet-3.1.14.so.original"
  owner=\$(adb -s ${ADB_SERIAL} shell "stat -c '%u:%g' \"\$runtime_path\"" | tr -d '\r')
  mode=\$(adb -s ${ADB_SERIAL} shell "stat -c '%a' \"\$runtime_path\"" | tr -d '\r')
  if [ ! -f "\$backup_path" ]; then
    adb -s ${ADB_SERIAL} pull "\$runtime_path" "\$backup_path" >/dev/null
  fi
  printf '%s|%s|%s|%s\n' "\$runtime_path" "\$backup_path" "\$owner" "\$mode" >> ${(qqq)REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH}
done < <(
  adb -s ${ADB_SERIAL} shell 'for f in /data/user/0/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so /data/data/${DOUYIN_PACKAGE}/app_librarian/*/libtnet-3.1.14.so; do [ -f "\$f" ] && echo "\$f"; done' 2>/dev/null | tr -d '\r'
)
adb -s ${ADB_SERIAL} shell "cp -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} ${(qqq)live_path}"
adb -s ${ADB_SERIAL} shell "chown \$apk_owner ${(qqq)live_path}"
adb -s ${ADB_SERIAL} shell "chmod 755 ${(qqq)live_path}"
while IFS='|' read -r runtime_path backup_path owner mode; do
  [ -n "\$runtime_path" ] || continue
  adb -s ${ADB_SERIAL} shell "cp -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} \"\$runtime_path\""
  adb -s ${ADB_SERIAL} shell "chown \$owner \"\$runtime_path\""
  adb -s ${ADB_SERIAL} shell "chmod \$mode \"\$runtime_path\""
done < ${(qqq)REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH}
adb -s ${ADB_SERIAL} shell am force-stop ${DOUYIN_PACKAGE}
EOF
)

  log "installing patched libtnet into ${live_path}"
  run_remote "bash -lc ${(qqq)install_cmd}"
  show_douyin_libt_tnet_state
}

restore_douyin_libt_tnet() {
  local apk_path=""
  local live_path=""
  local restore_cmd=""

  connect_adb
  log "resolving Douyin install path"
  log "using pm path ${DOUYIN_PACKAGE} to resolve the active APK copy"
  apk_path="$(resolve_douyin_apk_path)"
  if [[ -z "${apk_path}" ]]; then
    printf '%s is not installed or no APK path was returned.\n' "${DOUYIN_PACKAGE}" >&2
    return 1
  fi
  live_path="$(resolve_douyin_libt_tnet_path "${apk_path}")"

  log "restore workflow for Douyin libtnet"
  log "restore workflow uses adb push into the guest staging path before cp -p restore"
  log "restoring original libtnet into apk + app_librarian runtime copies"
  restore_cmd=$(cat <<EOF
set -euo pipefail
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell "mkdir -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_DIR}"
test -f ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_PATH}
apk_owner=\$(adb -s ${ADB_SERIAL} shell "stat -c '%u:%g' ${(qqq)apk_path}" | tr -d '\r')
apk_mode=755
if [ -f ${(qqq)REMOTE_DOUYIN_APK_METADATA_PATH} ]; then
  IFS='|' read -r apk_owner apk_mode < ${(qqq)REMOTE_DOUYIN_APK_METADATA_PATH}
fi
adb -s ${ADB_SERIAL} push ${(qqq)REMOTE_DOUYIN_LIBTNET_BACKUP_PATH} ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} >/dev/null
adb -s ${ADB_SERIAL} shell "cp -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} ${(qqq)live_path}"
adb -s ${ADB_SERIAL} shell "chown \$apk_owner ${(qqq)live_path}"
adb -s ${ADB_SERIAL} shell "chmod \$apk_mode ${(qqq)live_path}"
if [ -f ${(qqq)REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH} ]; then
  while IFS='|' read -r runtime_path backup_path owner mode; do
    [ -n "\$runtime_path" ] || continue
    test -f "\$backup_path"
    runtime_dir=\$(dirname "\$runtime_path")
    if ! adb -s ${ADB_SERIAL} shell "test -d \"\$runtime_dir\""; then
      echo "Skipping missing runtime dir: \$runtime_dir"
      continue
    fi
    adb -s ${ADB_SERIAL} push "\$backup_path" ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} >/dev/null
    adb -s ${ADB_SERIAL} shell "cp -p ${(qqq)GUEST_DOUYIN_LIBTNET_STAGE_PATH} \"\$runtime_path\""
    adb -s ${ADB_SERIAL} shell "chown \$owner \"\$runtime_path\""
    adb -s ${ADB_SERIAL} shell "chmod \$mode \"\$runtime_path\""
  done < ${(qqq)REMOTE_DOUYIN_RUNTIME_MANIFEST_PATH}
fi
adb -s ${ADB_SERIAL} shell am force-stop ${DOUYIN_PACKAGE}
EOF
)

  log "restoring original libtnet from ${REMOTE_DOUYIN_LIBTNET_BACKUP_PATH}"
  run_remote "bash -lc ${(qqq)restore_cmd}"
  show_douyin_libt_tnet_state
}

repair_runtime_permissions() {
  local fix_cmd="
for _ in 1 2 3 4 5; do
  if podman exec ${CONTAINER} /system/bin/sh -c 'chmod 644 /system/etc/llndk.libraries.txt /system/etc/sanitizer.libraries.txt'; then
    podman exec ${CONTAINER} /system/bin/sh -c 'ls -l /system/etc/llndk.libraries.txt /system/etc/sanitizer.libraries.txt'
    exit 0
  fi
  sleep 2
done
exit 1
"

  log "repairing runtime library file permissions"
  run_remote_sudo "$fix_cmd"
}

prepare_phone_profile() {
  local prep_cmd
  prep_cmd=$(cat <<EOF
set -euo pipefail

profile_dir='${REMOTE_PHONE_PROFILE_DIR}'
system_prop='${REMOTE_PHONE_SYSTEM_PROP}'
vendor_prop='${REMOTE_PHONE_VENDOR_PROP}'
xbin_dir='${REMOTE_PHONE_XBIN_DIR}'
adb_keys='${REMOTE_PHONE_ADB_KEYS}'

mkdir -p "\$profile_dir" "\$xbin_dir"

if [ ! -s '${REMOTE_ADB_KEY_SOURCE}' ]; then
  echo 'Missing remote adb public key: ${REMOTE_ADB_KEY_SOURCE}' >&2
  exit 1
fi

podman run --rm --pull=never --entrypoint /system/bin/sh ${IMAGE} -c 'cat /system/build.prop' > "\$system_prop"
podman run --rm --pull=never --entrypoint /system/bin/sh ${IMAGE} -c 'cat /vendor/build.prop' > "\$vendor_prop"
podman run --rm --pull=never --entrypoint /system/bin/sh ${IMAGE} -c 'cat /system/xbin/overlay_remounter' > "\$xbin_dir/overlay_remounter"
cp '${REMOTE_ADB_KEY_SOURCE}' "\$adb_keys"
chmod 755 "\$xbin_dir/overlay_remounter"
chmod 644 "\$adb_keys"
rm -f "\$xbin_dir/su"

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
EOF
)

  log "preparing phone profile ${PHONE_PROFILE_ID} (${PHONE_BRAND} ${PHONE_DEVICE_NAME})"
  run_remote_sudo "$prep_cmd"
}

restart_container() {
  local mode="${1:-baseline}"
  local extra_mounts=""
  local run_cmd
  # Load vkms kernel module to provide a virtual DRM device that supports
  # dumb buffers.  The Asahi AGX render-only driver does NOT support
  # DRM_IOCTL_MODE_CREATE_DUMB, so minigbm inside Redroid cannot allocate
  # graphic buffers through it.  vkms exposes /dev/dri/card0 which does
  # support dumb buffers; we map it into the container as renderD128.
  log "ensuring vkms kernel module is loaded"
  run_remote_sudo "modprobe vkms 2>/dev/null || true"

  # --privileged is required for binderfs, but it exposes ALL host DRI devices.
  # The Asahi card1/card2/card3 and renderD128 must be masked with /dev/null
  # so minigbm only sees the vkms card0 (mapped as renderD128).
  if [[ "${mode}" == "phone" ]]; then
    extra_mounts=" -v ${REMOTE_PHONE_SYSTEM_PROP}:/system/build.prop:ro -v ${REMOTE_PHONE_VENDOR_PROP}:/vendor/build.prop:ro -v ${REMOTE_PHONE_XBIN_DIR}:/system/xbin:ro -v ${REMOTE_PHONE_ADB_KEYS}:/product/etc/security/adb_keys:ro"
  fi

  run_cmd="podman run -d --name ${CONTAINER} --pull=never --privileged --network bridge --security-opt label=disable --security-opt unmask=all -p ${PORT_BIND} -p ${VNC_PORT_BIND} -v ${VOLUME_NAME}:/data -v /dev/dri/card0:/dev/dri/renderD128 -v /dev/null:/dev/dri/card1 -v /dev/null:/dev/dri/card2 -v /dev/null:/dev/dri/card3 -v /dev/null:/dev/dri/card4 -v /dev/null:/dev/dri/renderD129${extra_mounts} --entrypoint /init ${IMAGE} qemu=1 androidboot.hardware=redroid redroid_gpu_mode=guest redroid_gpu_node=/dev/dri/renderD128"

  if [[ "${mode}" == "phone" ]]; then
    log "restarting ${CONTAINER} on ${REMOTE_HOST} in phone mode"
  else
    log "restarting ${CONTAINER} on ${REMOTE_HOST}"
  fi
  run_remote_sudo "podman rm -f ${CONTAINER} >/dev/null 2>&1 || true"
  run_remote_sudo "$run_cmd"
  repair_runtime_permissions
}

show_runtime_mode() {
  local mode_cmd
  mode_cmd=$(cat <<EOF
if podman inspect ${CONTAINER} --format '{{range .Mounts}}{{println .Destination}}{{end}}' 2>/dev/null | grep -qx '/system/build.prop'; then
  echo "${RUNTIME_PROFILE_ID} phone-mode (${PHONE_PROFILE_ID})"
else
  echo "${RUNTIME_PROFILE_ID} baseline"
fi
EOF
)

  run_remote_sudo "bash -lc ${(qqq)mode_cmd}"
}

set_device_name() {
  local device_cmd
  device_cmd=$(cat <<EOF
adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
adb -s ${ADB_SERIAL} shell settings put global device_name '${PHONE_DEVICE_NAME}'
EOF
)

  log "setting device_name to ${PHONE_DEVICE_NAME}"
  run_remote "bash -lc ${(qqq)device_cmd}"
}

show_status() {
  log "container status"
  run_remote_sudo "podman inspect ${CONTAINER} --format 'name={{.Name}} image={{.ImageName}} status={{.State.Status}} exit={{.State.ExitCode}} started={{.State.StartedAt}}'"
  log "runtime mode"
  show_runtime_mode
  log "port binding"
  run_remote_sudo "podman inspect ${CONTAINER} --format '{{json .HostConfig.PortBindings}}'"
  log "system library file modes"
  run_remote_sudo "podman exec ${CONTAINER} /system/bin/sh -c 'ls -l /system/etc/llndk.libraries.txt /system/etc/sanitizer.libraries.txt'"
}

verify_runtime() {
  local vnc_host_port
  vnc_host_port="$(host_port_from_bind "${VNC_PORT_BIND}")"
  connect_adb
  log "podman runtime properties"
  run_remote_sudo "podman exec ${CONTAINER} /system/bin/sh -c '/system/bin/getprop sys.boot_completed; /system/bin/getprop init.svc.adbd; /system/bin/getprop init.svc.surfaceflinger; /system/bin/getprop init.svc.vendor.graphics.allocator; /system/bin/getprop init.svc.vendor.hwcomposer-3'"
  log "runtime mode"
  show_runtime_mode
  log "adb visibility"
  run_remote "adb devices -l | sed -n '1,20p'"
  log "adb props"
  run_remote "adb -s ${ADB_SERIAL} shell getprop ro.product.model && adb -s ${ADB_SERIAL} shell getprop sys.boot_completed"
  log "app-facing device props"
  run_remote "adb -s ${ADB_SERIAL} shell 'for p in ro.product.brand ro.product.manufacturer ro.product.model ro.product.device ro.build.fingerprint ro.build.type ro.build.tags ro.debuggable; do printf \"%s=\" \"\$p\"; getprop \"\$p\"; done'"
  log "su visibility"
  run_remote "adb -s ${ADB_SERIAL} shell 'ls -l /system/xbin/su 2>/dev/null || echo /system/xbin/su hidden'"
  log "device_name"
  run_remote "adb -s ${ADB_SERIAL} shell settings get global device_name"
  log "vncserver status"
  run_remote "adb -s ${ADB_SERIAL} shell getprop init.svc.vendor.vncserver"
  log "vnc port ${vnc_host_port}"
  run_remote "timeout 2 bash -c 'cat < /dev/tcp/127.0.0.1/${vnc_host_port}' 2>/dev/null | head -c 12 || echo 'VNC not reachable'"
  log "system library file modes"
  run_remote_sudo "podman exec ${CONTAINER} /system/bin/sh -c 'ls -l /system/etc/llndk.libraries.txt /system/etc/sanitizer.libraries.txt'"
  log "douyin page-size compat state"
  show_douyin_compat_state
}

apply_douyin_compat() {
  local patch_cmd
  local patch_status

  connect_adb
  log "checking ${DOUYIN_PACKAGE} page-size compat state"
  patch_cmd=$(cat <<EOF
set -euo pipefail

adb connect ${ADB_SERIAL} >/dev/null 2>&1 || true
pkg_path=\$(adb -s ${ADB_SERIAL} shell pm path ${DOUYIN_PACKAGE} 2>/dev/null | tr -d '\r')
if [ -z "\$pkg_path" ]; then
  echo "${DOUYIN_PACKAGE} not installed; nothing to patch"
  exit 0
fi

current=\$(adb -s ${ADB_SERIAL} shell dumpsys package ${DOUYIN_PACKAGE} | grep -o 'pageSizeCompat=[0-9]*' | head -1 | cut -d= -f2 | tr -d '\r')
case "\$current" in
  ${TARGET_PAGE_SIZE_COMPAT})
    echo "${DOUYIN_PACKAGE} already has pageSizeCompat=${TARGET_PAGE_SIZE_COMPAT}"
    exit 0
    ;;
  4)
    ;;
  "")
    echo "Unable to read pageSizeCompat for ${DOUYIN_PACKAGE}" >&2
    exit 1
    ;;
  *)
    echo "Unexpected pageSizeCompat=\$current for ${DOUYIN_PACKAGE}" >&2
    exit 1
    ;;
esac

adb -s ${ADB_SERIAL} root >/dev/null 2>&1 || true
stamp=\$(date +%Y%m%d-%H%M%S)
adb -s ${ADB_SERIAL} shell 'abx2xml /data/system/packages.xml /data/local/tmp/packages.xml.txt >/dev/null 2>&1'
adb -s ${ADB_SERIAL} shell "cp /data/system/packages.xml /data/local/tmp/packages.xml.backup.\$stamp.abx"
adb -s ${ADB_SERIAL} shell "sed -i '/<package name=\\\\\\\"${DOUYIN_PACKAGE}\\\\\\\"/s/pageSizeCompat=\\\\\\\"4\\\\\\\"/pageSizeCompat=\\\\\\\"${TARGET_PAGE_SIZE_COMPAT}\\\\\\\"/' /data/local/tmp/packages.xml.txt"
adb -s ${ADB_SERIAL} shell 'xml2abx /data/local/tmp/packages.xml.txt /data/local/tmp/packages.xml.patched.abx >/dev/null 2>&1'
adb -s ${ADB_SERIAL} shell 'dd if=/data/local/tmp/packages.xml.patched.abx of=/data/system/packages.xml.new bs=4096 status=none'
adb -s ${ADB_SERIAL} shell "mv /data/system/packages.xml /data/system/packages.xml.replaced.\$stamp && mv /data/system/packages.xml.new /data/system/packages.xml && chown system:system /data/system/packages.xml && chmod 660 /data/system/packages.xml"
adb -s ${ADB_SERIAL} shell 'abx2xml /data/system/packages.xml /data/local/tmp/packages.verify.txt >/dev/null 2>&1'
adb -s ${ADB_SERIAL} shell "grep '<package name=\\\\\\\"${DOUYIN_PACKAGE}\\\\\\\"' /data/local/tmp/packages.verify.txt | head -1"
exit 10
EOF
)

  if (( DRY_RUN )); then
    run_remote "bash -lc ${(qqq)patch_cmd}"
    restart_container
    connect_adb
    wait_for_boot
    log "verifying ${DOUYIN_PACKAGE} page-size compat state after restart"
    show_douyin_compat_state
    return 0
  fi

  set +e
  run_remote "bash -lc ${(qqq)patch_cmd}"
  patch_status=$?
  set -e

  case "$patch_status" in
    0)
      return 0
      ;;
    10)
      ;;
    *)
      return "$patch_status"
      ;;
  esac

  restart_container
  connect_adb
  wait_for_boot
  log "verifying ${DOUYIN_PACKAGE} page-size compat state after restart"
  show_douyin_compat_state
}

sync_viewer_tool() {
  local remote_viewer_target="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_VIEWER_PATH}"
  local scp_cmd="scp -o StrictHostKeyChecking=no ${(qqq)LOCAL_VIEWER_PATH} ${(qqq)remote_viewer_target}"
  log "syncing Redroid Viewer helper to ${REMOTE_HOST}"
  run_local "$scp_cmd"
}

activate_phone_mode() {
  prepare_phone_profile
  restart_container "phone"
  connect_adb
  wait_for_boot
  set_device_name
  verify_runtime
}

launch_viewer() {
  sync_viewer_tool
  log "launching Redroid Viewer on ${REMOTE_HOST} KDE desktop"
  local viewer_cmd="export REDROID_VIEWER_ADB_SERIAL=${ADB_SERIAL} XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 XAUTHORITY=\$(ls /run/user/1000/xauth_* 2>/dev/null | head -1); nohup python3 ${REMOTE_VIEWER_PATH} > /tmp/redroid_viewer.log 2>&1 &"
  run_remote "$viewer_cmd"
  log "viewer launched — check the KDE desktop on ${REMOTE_HOST}"
}

main() {
  local action=""

  while (($#)); do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      restart|status|verify|viewer|douyin-compat|douyin-libtnet-status|douyin-libtnet-install|douyin-libtnet-verify|douyin-libtnet-restore|phone-mode|restart-4k|status-4k|verify-4k|viewer-4k)
        action="$1"
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        return 1
        ;;
    esac
    shift
  done

  if [[ -z "$action" ]]; then
    usage >&2
    return 1
  fi

  case "$action" in
    restart)
      select_runtime_profile "16k"
      restart_container
      ;;
    status)
      select_runtime_profile "16k"
      show_status
      ;;
    verify)
      select_runtime_profile "16k"
      verify_runtime
      ;;
    viewer)
      select_runtime_profile "16k"
      launch_viewer
      ;;
    douyin-compat)
      select_runtime_profile "16k"
      apply_douyin_compat
      ;;
    douyin-libtnet-status)
      select_runtime_profile "16k"
      show_douyin_libt_tnet_state
      ;;
    douyin-libtnet-install)
      select_runtime_profile "16k"
      install_douyin_libt_tnet_patch
      ;;
    douyin-libtnet-verify)
      select_runtime_profile "16k"
      show_douyin_libt_tnet_state
      ;;
    douyin-libtnet-restore)
      select_runtime_profile "16k"
      restore_douyin_libt_tnet
      ;;
    phone-mode)
      select_runtime_profile "16k"
      activate_phone_mode
      ;;
    restart-4k)
      select_runtime_profile "4k"
      assert_runtime_profile_supported
      restart_container
      ;;
    status-4k)
      select_runtime_profile "4k"
      show_status
      ;;
    verify-4k)
      select_runtime_profile "4k"
      verify_runtime
      ;;
    viewer-4k)
      select_runtime_profile "4k"
      launch_viewer
      ;;
  esac
}

main "$@"
