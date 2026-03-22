from pathlib import Path
import os
import subprocess
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "redroid" / "scripts" / "redroid_guest4k_107.sh"


class RedroidGuest4K107ScriptTest(unittest.TestCase):
    def run_script(
        self,
        *args: str,
        extra_env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)

        return subprocess.run(
            ["zsh", str(SCRIPT), *args],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )

    def test_vm_start_dry_run_shows_microvm_entrypoint(self) -> None:
        result = self.run_script("--dry-run", "vm-start")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("/home/wjq/vm4k/ubuntu24k", stdout)
        self.assertIn("./launch.sh", stdout)
        self.assertIn("192.168.1.107", stdout)

    def test_help_lists_explicit_virgl_and_legacy_operator_actions_in_usage_header(self) -> None:
        result = self.run_script("--help")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        usage_header = stdout.splitlines()[0]
        self.assertIn("restart-legacy", usage_header)
        self.assertIn("restart-legacy-preserve-data", usage_header)
        self.assertIn("virgl-srcbuild-probe", usage_header)
        self.assertIn("virgl-srcbuild-longrun", usage_header)
        self.assertIn("virgl-srcbuild-rollout", usage_header)
        self.assertIn("virgl-srcbuild-rollback", usage_header)
        self.assertIn("virgl-fingerprint-compare", usage_header)

    def test_vm_script_overrides_are_used_in_dry_run(self) -> None:
        env = {
            "VM_LAUNCH_SCRIPT": "/tmp/guest4k/launch-headless-vkms.sh",
            "VM_STOP_SCRIPT": "/tmp/guest4k/stop-headless-vkms.sh",
            "VM_STATUS_SCRIPT": "/tmp/guest4k/status-headless-vkms.sh",
        }

        start = self.run_script("--dry-run", "vm-start", extra_env=env)
        self.assertEqual(start.returncode, 0, start.stderr or start.stdout)
        self.assertIn("/tmp/guest4k", start.stdout)
        self.assertIn("./launch-headless-vkms.sh", start.stdout)

        stop = self.run_script("--dry-run", "vm-stop", extra_env=env)
        self.assertEqual(stop.returncode, 0, stop.stderr or stop.stdout)
        self.assertIn("/tmp/guest4k", stop.stdout)
        self.assertIn("./stop-headless-vkms.sh", stop.stdout)

        status = self.run_script("--dry-run", "vm-status", extra_env=env)
        self.assertEqual(status.returncode, 0, status.stderr or status.stdout)
        self.assertIn("/tmp/guest4k", status.stdout)
        self.assertIn("./status-headless-vkms.sh", status.stdout)

    def test_vm_start_dry_run_forwards_audio_tuning_overrides(self) -> None:
        result = self.run_script(
            "--dry-run",
            "vm-start",
            extra_env={
                "VM_PIPEWIRE_QUANTUM": "1024/44100",
                "VM_PIPEWIRE_LATENCY": "1024/44100",
                "VM_AUDIO_OUT_LATENCY_US": "20000",
                "VM_AUDIO_TIMER_PERIOD_US": "23220",
                "VM_AUDIO_OUT_MIXING_ENGINE": "off",
                "VM_AUDIO_OUT_FIXED_SETTINGS": "off",
                "VM_QEMU_SMP": "6",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("PIPEWIRE_QUANTUM=1024/44100", stdout)
        self.assertIn("PIPEWIRE_LATENCY=1024/44100", stdout)
        self.assertIn("QEMU_AUDIO_OUT_LATENCY_US=20000", stdout)
        self.assertIn("QEMU_AUDIO_TIMER_PERIOD_US=23220", stdout)
        self.assertIn("QEMU_AUDIO_OUT_MIXING_ENGINE=off", stdout)
        self.assertIn("QEMU_AUDIO_OUT_FIXED_SETTINGS=off", stdout)
        self.assertIn("QEMU_SMP=6", stdout)
        self.assertIn("./launch.sh", stdout)

    def test_restart_dry_run_shows_isolated_guest_redroid_shape(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("graphics profile: guest-all-dri", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertNotIn("localhost/redroid4k-root:alsa-hal-ranchu-exp2", stdout)
        self.assertNotIn("localhost/redroid16k-root:latest", stdout)
        self.assertIn("/home/wjq/vm4k/ubuntu24k/guest_key", stdout)
        self.assertIn("127.0.0.1:2222", stdout)
        self.assertIn("UserKnownHostsFile=/dev/null", stdout)
        self.assertIn("GlobalKnownHostsFile=/dev/null", stdout)
        self.assertIn("podman run -d --name redroid16kguestprobe", stdout)
        self.assertIn("-p 5555:5555/tcp", stdout)
        self.assertIn("-p 5900:5900/tcp", stdout)
        self.assertIn("redroid16kguestprobe-data", stdout)
        self.assertIn("redroid16kbridgeprobe", stdout)
        self.assertIn("-v /dev/dri:/dev/dri", stdout)
        self.assertNotIn("--network host", stdout)

    def test_restart_dry_run_uses_quiet_guest_ssh_transport(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("UserKnownHostsFile=/dev/null", stdout)
        self.assertIn("GlobalKnownHostsFile=/dev/null", stdout)
        self.assertIn("LogLevel=ERROR", stdout)

    def test_restart_dry_run_stops_preserved_virgl_port_owners_before_rebinding_standard_ports(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            "for standard_port_container in redroid16kguestprobe-virgl-renderable-srcbuildrollout redroid16kguestprobe-virgl-renderable-gralloc4trace; do",
            stdout,
        )
        self.assertIn(
            'podman stop -t 10 "${standard_port_container}" >/dev/null 2>&1 || true',
            stdout,
        )

    def test_restart_dry_run_repairs_guest_card0_permissions_for_guest_all_dri(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("/etc/udev/rules.d/99-redroid-dri.rules", stdout)
        self.assertIn('SUBSYSTEM=="drm", KERNEL=="card0", MODE="0666"', stdout)
        self.assertIn("udevadm control --reload", stdout)
        self.assertIn("udevadm trigger /dev/dri/card0", stdout)
        self.assertIn("chmod 666 /dev/dri/card0", stdout)

    def test_restart_dry_run_repairs_guest_snd_permissions_for_android_audio(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("/etc/udev/rules.d/99-redroid-snd.rules", stdout)
        self.assertIn('SUBSYSTEM=="sound", GROUP="1005", MODE="0660"', stdout)
        self.assertIn("udevadm trigger --subsystem-match=sound", stdout)
        self.assertIn("chgrp -R 1005 /dev/snd", stdout)
        self.assertIn("chmod 660 /dev/snd/*", stdout)

    def test_restart_dry_run_targets_card0_for_guest_gpu_node(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.redroid_gpu_mode=guest", stdout)
        self.assertIn("androidboot.redroid_gpu_node=/dev/dri/card0", stdout)
        self.assertNotRegex(stdout, r"(?<!androidboot\.)redroid_gpu_mode=guest")
        self.assertNotIn("redroid_gpu_node=/dev/dri/renderD128", stdout)

    def test_restart_dry_run_supports_gpu_mode_and_node_overrides(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "REDROID_GPU_MODE": "host",
                "REDROID_GPU_NODE": "/dev/dri/renderD128",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.redroid_gpu_mode=host", stdout)
        self.assertIn("androidboot.redroid_gpu_node=/dev/dri/renderD128", stdout)
        self.assertNotRegex(stdout, r"(?<!androidboot\.)redroid_gpu_mode=host")

    def test_restart_dry_run_supports_graphics_boot_prop_overrides(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "REDROID_BOOT_HARDWARE_EGL": "mesa",
                "REDROID_BOOT_HARDWARE_VULKAN": "virtio",
                "REDROID_BOOT_CPU_VULKAN_VERSION": "0",
                "REDROID_BOOT_OPENGLES_VERSION": "196608",
                "REDROID_BOOT_DEBUG_HWUI_RENDERER": "skiagl",
                "REDROID_BOOT_DEBUG_RENDERENGINE_BACKEND": "skiaglthreaded",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardwareegl=mesa", stdout)
        self.assertIn("androidboot.hardware.vulkan=virtio", stdout)
        self.assertIn("androidboot.cpuvulkan.version=0", stdout)
        self.assertIn("androidboot.opengles.version=196608", stdout)
        self.assertIn("androidboot.debug.hwui.renderer=skiagl", stdout)
        self.assertIn("androidboot.debug.renderengine.backend=skiaglthreaded", stdout)

    def test_restart_dry_run_does_not_default_to_experimental_graphics_boot_props(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertNotIn("androidboot.hardwareegl=mesa", stdout)
        self.assertNotIn("androidboot.hardware.vulkan=virtio", stdout)
        self.assertNotIn("androidboot.cpuvulkan.version=0", stdout)
        self.assertNotIn("androidboot.opengles.version=196608", stdout)

    def test_restart_dry_run_enables_redroid_vnc_boot_flag(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.use_redroid_vnc=1", stdout)

    def test_restart_dry_run_waits_for_vnc_banner_instead_of_missing_service_prop(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("timeout 5 adb -s 127.0.0.1:5556 shell getprop sys.boot_completed", stdout)
        self.assertIn("socket.create_connection((", stdout)
        self.assertIn("5901), timeout=5)", stdout)
        self.assertIn("if not banner.startswith(b", stdout)
        self.assertIn("RFB", stdout)
        self.assertNotIn("init.svc.vendor.vncserver", stdout)

    def test_restart_dry_run_waits_for_adb_device_state_before_reporting_ready(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(r"deadline=\$((\$(date +%s) + 30))", stdout)
        self.assertIn(r"state=\$(timeout 5 adb -s 127.0.0.1:5556 get-state 2>/dev/null | tr -d '\\r')", stdout)
        self.assertIn(r'if [ \"\$state\" = \"device\" ]; then', stdout)
        self.assertIn("ADB_READY %s %s", stdout)
        self.assertNotIn("adb devices", stdout)

    def test_restart_dry_run_supports_guest_vkms_graphics_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GRAPHICS_PROFILE": "guest-vkms",
                "VKMS_CARD_NODE": "/dev/dri/card1",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("graphics profile: guest-vkms", stdout)
        self.assertIn("modprobe vkms", stdout)
        self.assertIn("chmod 666 /dev/dri/card1", stdout)
        self.assertIn("-v /dev/dri/card1:/dev/dri/card0", stdout)
        self.assertIn("-v /dev/dri/card1:/dev/dri/renderD128", stdout)
        self.assertNotIn("-v /dev/null:/dev/dri/card0", stdout)
        self.assertIn("-v /dev/null:/dev/dri/card1", stdout)
        self.assertIn("-v /dev/null:/dev/dri/renderD129", stdout)
        self.assertNotIn("-v /dev/dri:/dev/dri", stdout)
        self.assertNotIn("--network host", stdout)

    def test_virgl_srcbuild_probe_dry_run_shows_clone_probe_restore_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-probe", stdout)
        self.assertIn("podman container clone", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildgralloc", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("/system/bin/logcat -c", stdout)
        self.assertIn("sleep 90", stdout)
        self.assertIn("{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}", stdout)
        self.assertNotIn('%q', stdout)
        self.assertIn("Using gralloc0 CrOS API", stdout)
        self.assertIn("Failed to create a valid texture", stdout)
        self.assertIn("podman start redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)

    def test_virgl_srcbuild_probe_dry_run_honors_override_env(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-probe",
            extra_env={
                "VIRGL_SRCBUILD_IMAGE": "localhost/redroid4k-root:test-override",
                "VIRGL_SRCBUILD_CONTROL_CONTAINER": "control-override",
                "VIRGL_SRCBUILD_PROBE_CONTAINER": "probe-override",
                "VIRGL_SRCBUILD_PROBE_SECONDS": "30",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:test-override", stdout)
        self.assertIn("control-override", stdout)
        self.assertIn("probe-override", stdout)
        self.assertIn("sleep 30", stdout)

    def test_virgl_srcbuild_longrun_dry_run_shows_checkpoint_probe_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-longrun")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-longrun", stdout)
        self.assertIn("podman container clone", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildlongrun", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("CHECKPOINT_T30_BEGIN", stdout)
        self.assertIn("CHECKPOINT_T60_BEGIN", stdout)
        self.assertIn("CHECKPOINT_T120_BEGIN", stdout)
        self.assertIn("CHECKPOINT_T180_BEGIN", stdout)
        self.assertIn("echo 'CHECKPOINT_T30_END'\nsleep 30", stdout)
        self.assertIn("sleep 30", stdout)
        self.assertIn("sleep 60", stdout)
        self.assertIn("pidof surfaceflinger", stdout)
        self.assertIn("FINAL_FILES_BEGIN", stdout)
        self.assertIn("/vendor/lib64/hw/gralloc.cros.so", stdout)
        self.assertIn("/vendor/lib64/hw/gralloc.minigbm.so", stdout)
        self.assertIn("RESTORED", stdout)

    def test_virgl_srcbuild_longrun_dry_run_honors_override_env(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-longrun",
            extra_env={
                "VIRGL_SRCBUILD_IMAGE": "localhost/redroid4k-root:test-longrun",
                "VIRGL_SRCBUILD_CONTROL_CONTAINER": "control-longrun",
                "VIRGL_SRCBUILD_LONGRUN_CONTAINER": "probe-longrun",
                "VIRGL_SRCBUILD_LONGRUN_CHECKPOINTS": "15 45 90",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:test-longrun", stdout)
        self.assertIn("control-longrun", stdout)
        self.assertIn("probe-longrun", stdout)
        self.assertIn("CHECKPOINT_T15_BEGIN", stdout)
        self.assertIn("CHECKPOINT_T45_BEGIN", stdout)
        self.assertIn("CHECKPOINT_T90_BEGIN", stdout)

    def test_virgl_srcbuild_rollout_dry_run_shows_clone_handoff_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-rollout", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildrollout", stdout)
        self.assertIn("ROLLOUT_PRECHECK_BEGIN", stdout)
        self.assertIn("ROLLOUT_CLONE_BEGIN", stdout)
        self.assertIn("ROLLOUT_CLONED", stdout)
        self.assertIn("ROLLOUT_STOP_CONTROL", stdout)
        self.assertIn("ROLLOUT_STARTED", stdout)
        self.assertIn("ROLLOUT_HEALTH_BEGIN", stdout)
        self.assertIn("ROLLOUT_HEALTH_END", stdout)
        self.assertIn("ROLLOUT_ACTIVE", stdout)
        self.assertIn("ROLLOUT_FAILED", stdout)
        self.assertIn("AUTO_RESTORED", stdout)
        self.assertIn(
            "podman container clone redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-srcbuildrollout localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322",
            stdout,
        )
        self.assertIn("adb connect 127.0.0.1:5556", stdout)
        self.assertIn("Using gralloc0 CrOS API", stdout)
        self.assertIn("Failed to create a valid texture", stdout)
        self.assertNotIn("podman run -d --name redroid16kguestprobe-virgl-renderable-srcbuildrollout", stdout)

    def test_virgl_srcbuild_rollout_dry_run_honors_override_env(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-rollout",
            extra_env={
                "VIRGL_SRCBUILD_IMAGE": "localhost/redroid4k-root:test-rollout",
                "VIRGL_SRCBUILD_CONTROL_CONTAINER": "control-rollout",
                "VIRGL_SRCBUILD_ROLLOUT_CONTAINER": "rollout-container",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:test-rollout", stdout)
        self.assertIn("control-rollout", stdout)
        self.assertIn("rollout-container", stdout)

    def test_virgl_srcbuild_rollout_dry_run_retries_health_window_before_failing(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("ROLLOUT_HEALTH_RETRY_BEGIN", stdout)
        self.assertIn("ROLLOUT_HEALTH_RETRY_END", stdout)
        self.assertIn("sleep 30", stdout)

    def test_virgl_srcbuild_rollout_dry_run_reuses_control_runtime_shape_instead_of_rebuilding_it(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("ROLLOUT_CLONE_BEGIN", stdout)
        self.assertIn("podman container clone", stdout)
        self.assertNotIn("androidboot.redroid_gpu_mode=guest", stdout)
        self.assertNotIn("androidboot.redroid_gpu_node=/dev/dri/card0", stdout)
        self.assertNotIn("-v redroid16kguestprobe-virgl-renderable-srcbuildrollout-data:/data", stdout)

    def test_virgl_srcbuild_rollback_dry_run_restores_control_without_deleting_rollout_data(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollback")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-rollback", stdout)
        self.assertIn("ROLLBACK_BEGIN", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildrollout", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("ROLLBACK_RESTORED", stdout)
        self.assertNotIn(
            "podman volume rm -f redroid16kguestprobe-virgl-renderable-srcbuildrollout-data",
            stdout,
        )

    def test_virgl_fingerprint_compare_dry_run_shows_control_and_probe_fingerprints(self) -> None:
        result = self.run_script("--dry-run", "virgl-fingerprint-compare")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-fingerprint-compare", stdout)
        self.assertIn("CONTROL_STATE", stdout)
        self.assertIn("CONTROL_LIBS_BEGIN", stdout)
        self.assertIn("PROBE_STATE", stdout)
        self.assertIn("PROBE_LIBS_BEGIN", stdout)
        self.assertIn("podman container clone", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-fingerprint-srcbuild", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("/system/bin/toybox sha256sum", stdout)
        self.assertIn("/system/lib64/libEGL.so", stdout)
        self.assertIn("/vendor/lib64/egl/libEGL_mesa.so", stdout)
        self.assertIn("/vendor/lib64/hw/gralloc.cros.so", stdout)
        self.assertIn("sleep 90", stdout)
        self.assertIn("podman start redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)

    def test_virgl_fingerprint_compare_dry_run_honors_override_env(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-fingerprint-compare",
            extra_env={
                "VIRGL_SRCBUILD_IMAGE": "localhost/redroid4k-root:test-compare",
                "VIRGL_SRCBUILD_CONTROL_CONTAINER": "control-compare",
                "VIRGL_FINGERPRINT_PROBE_CONTAINER": "probe-compare",
                "VIRGL_FINGERPRINT_SECONDS": "30",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:test-compare", stdout)
        self.assertIn("control-compare", stdout)
        self.assertIn("probe-compare", stdout)
        self.assertIn("sleep 30", stdout)

    def test_verify_dry_run_shows_host_visible_endpoints(self) -> None:
        result = self.run_script("--dry-run", "verify")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("127.0.0.1:5556", stdout)
        self.assertIn("127.0.0.1:5901", stdout)
        self.assertIn("adb connect", stdout)
        self.assertIn("sys.boot_completed", stdout)
        self.assertIn("RFB", stdout)

    def test_verify_dry_run_uses_bounded_adb_property_polls(self) -> None:
        result = self.run_script("--dry-run", "verify")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("timeout 5 adb -s 127.0.0.1:5556 shell getprop sys.boot_completed", stdout)
        self.assertNotIn("init.svc.vendor.vncserver", stdout)
        self.assertIn("socket.create_connection((", stdout)
        self.assertIn("5901), timeout=5)", stdout)

    def test_restart_dry_run_resets_android_display_overrides_after_boot(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size reset", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm density reset", stdout)
        self.assertIn(
            "adb -s 127.0.0.1:5556 shell settings delete global display_size_forced",
            stdout,
        )
        self.assertIn(
            "adb -s 127.0.0.1:5556 shell settings delete secure display_density_forced",
            stdout,
        )

    def test_verify_dry_run_resets_android_display_overrides_after_boot(self) -> None:
        result = self.run_script("--dry-run", "verify")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size reset", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm density reset", stdout)
        self.assertIn(
            "adb -s 127.0.0.1:5556 shell settings delete global display_size_forced",
            stdout,
        )
        self.assertIn(
            "adb -s 127.0.0.1:5556 shell settings delete secure display_density_forced",
            stdout,
        )

    def test_viewer_dry_run_defaults_to_tigervnc_and_cleans_legacy_screencap_viewer(self) -> None:
        result = self.run_script("--dry-run", "viewer")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("pkill -f '/tmp/[r]edroid_viewer.py'", stdout)
        self.assertIn("pkill -f 'adb -s 127.0.0.1:5556 exec-out sh -c while true; do [s]creencap; done'", stdout)
        self.assertIn("pkill -f '[v]ncviewer .*127.0.0.1::5901'", stdout)
        self.assertIn("nohup vncviewer", stdout)
        self.assertIn("127.0.0.1::5901", stdout)
        self.assertNotIn("python3 /tmp/redroid_viewer.py", stdout)

    def test_viewer_dry_run_supports_python_fallback_mode(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={"VIEWER_MODE": "python"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("pkill -f '[v]ncviewer .*127.0.0.1::5901'", stdout)
        self.assertIn("pkill -f '/tmp/[r]edroid_viewer.py'", stdout)
        self.assertIn("pkill -f 'adb -s 127.0.0.1:5556 exec-out sh -c while true; do [s]creencap; done'", stdout)
        self.assertIn("python3 /tmp/redroid_viewer.py", stdout)
        self.assertNotIn("nohup vncviewer", stdout)

    def test_restart_dry_run_recovers_host_qemu_audio_stream(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("recovering host PipeWire state for qemu audio stream", stdout)
        self.assertIn("audio0", stdout)
        self.assertIn("qemu-system-aarch64", stdout)
        self.assertIn("LC_ALL=C pactl info", stdout)
        self.assertNotIn("alsa_output.platform-sound.HiFi__Headphones__sink", stdout)
        self.assertIn("pactl move-sink-input", stdout)
        self.assertIn("pactl set-sink-input-mute", stdout)
        self.assertIn("pactl set-sink-input-volume", stdout)
        self.assertIn("120%", stdout)

    def test_verify_dry_run_recovers_host_qemu_audio_stream(self) -> None:
        result = self.run_script("--dry-run", "verify")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("recovering host PipeWire state for qemu audio stream", stdout)
        self.assertIn("audio0", stdout)
        self.assertIn("qemu-system-aarch64", stdout)
        self.assertIn("LC_ALL=C pactl info", stdout)
        self.assertNotIn("alsa_output.platform-sound.HiFi__Headphones__sink", stdout)
        self.assertIn("pactl move-sink-input", stdout)
        self.assertIn("pactl set-sink-input-mute", stdout)
        self.assertIn("pactl set-sink-input-volume", stdout)
        self.assertIn("120%", stdout)

    def test_verify_dry_run_honors_explicit_host_audio_target_sink_override(self) -> None:
        result = self.run_script(
            "--dry-run",
            "verify",
            extra_env={"HOST_AUDIO_TARGET_SINK": "audio_effect.j293-convolver"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('target_sink=\\"audio_effect.j293-convolver\\"', stdout)
        self.assertIn("pactl move-sink-input", stdout)

    def test_verify_dry_run_supports_disabling_host_audio_sink_move(self) -> None:
        result = self.run_script(
            "--dry-run",
            "verify",
            extra_env={"HOST_AUDIO_MOVE_TO_TARGET": "0"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('if [ \\"0\\" = \\"1\\" ]', stdout)
        self.assertIn("pactl set-sink-input-mute", stdout)
        self.assertIn("pactl set-sink-input-volume", stdout)

    def test_status_dry_run_shows_vm_and_guest_checks(self) -> None:
        result = self.run_script("--dry-run", "status")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("./status.sh", stdout)
        self.assertIn("getconf PAGE_SIZE", stdout)
        self.assertIn("podman ps", stdout)

    def test_restart_dry_run_supports_guest_password_ssh_fallback(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={"GUEST_SSH_PASSWORD": "123123"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("sshpass -p 123123 ssh", stdout)
        self.assertIn("PubkeyAuthentication=no", stdout)
        self.assertIn("PreferredAuthentications=password", stdout)
        self.assertNotIn("/home/wjq/vm4k/ubuntu24k/guest_key", stdout)

    def test_restart_preserve_data_dry_run_keeps_volume_and_relaxes_selinux(self) -> None:
        result = self.run_script("--dry-run", "restart-preserve-data")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("setenforce 0 || true", stdout)
        self.assertIn("podman rm -f redroid16kguestprobe", stdout)
        self.assertNotIn("podman volume rm -f redroid16kguestprobe-data", stdout)

    def test_restart_legacy_dry_run_uses_legacy_image(self) -> None:
        result = self.run_script("--dry-run", "restart-legacy")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("graphics profile: guest-all-dri", stdout)
        self.assertIn("localhost/redroid4k-root:alsa-hal-ranchu-exp2", stdout)
        self.assertNotIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("podman run -d --name redroid16kguestprobe", stdout)

    def test_restart_legacy_preserve_data_dry_run_keeps_volume_and_uses_legacy_image(self) -> None:
        result = self.run_script("--dry-run", "restart-legacy-preserve-data")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:alsa-hal-ranchu-exp2", stdout)
        self.assertIn("setenforce 0 || true", stdout)
        self.assertNotIn("podman volume rm -f redroid16kguestprobe-data", stdout)

    def test_douyin_install_dry_run_uses_remote_staged_apk_by_default(self) -> None:
        result = self.run_script("--dry-run", "douyin-install")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("/tmp/douyin.apk", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 install -r /tmp/douyin.apk", stdout)
        self.assertIn("pm path com.ss.android.ugc.aweme", stdout)

    def test_douyin_start_dry_run_shows_launch_workflow(self) -> None:
        result = self.run_script("--dry-run", "douyin-start")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size reset", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm density reset", stdout)
        self.assertIn("am force-stop com.ss.android.ugc.aweme", stdout)
        self.assertIn("am start -W -n com.ss.android.ugc.aweme/.splash.SplashActivity", stdout)
        self.assertIn("pidof com.ss.android.ugc.aweme", stdout)
        self.assertIn("topResumedActivity", stdout)

    def test_douyin_diagnose_dry_run_shows_audio_and_log_surfaces(self) -> None:
        result = self.run_script("--dry-run", "douyin-diagnose")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("dumpsys media.audio_flinger", stdout)
        self.assertIn("dumpsys audio", stdout)
        self.assertIn("logcat -d", stdout)
        self.assertIn("pactl list sink-inputs short", stdout)

    def test_audio_diagnose_dry_run_shows_guest_android_and_host_audio_surfaces(self) -> None:
        result = self.run_script("--dry-run", "audio-diagnose")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("ls -l /dev/snd", stdout)
        self.assertIn("cat /proc/asound/cards", stdout)
        self.assertIn("aplay -l", stdout)
        self.assertIn("dumpsys media.audio_flinger", stdout)
        self.assertIn("dumpsys audio", stdout)
        self.assertIn("pactl list sink-inputs", stdout)
        self.assertIn("pw-cli info", stdout)


if __name__ == "__main__":
    unittest.main()
