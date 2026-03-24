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
        self.assertIn("virgl-srcbuild-import", usage_header)
        self.assertIn("virgl-srcbuild-rollout", usage_header)
        self.assertIn("virgl-srcbuild-rollback", usage_header)
        self.assertIn("virgl-fingerprint-compare", usage_header)
        self.assertIn(
            "virgl-srcbuild-probe  Run the bounded source-consistent virgl probe in a portless temporary runtime with bounded mainline handoff",
            stdout,
        )
        self.assertIn(
            "virgl-srcbuild-longrun  Run the source-consistent virgl long-run probe in a portless temporary runtime with periodic checkpoints and bounded mainline handoff",
            stdout,
        )
        self.assertIn(
            "virgl-srcbuild-import  Import a staged Guest4K system/vendor image pair into a new guest-rootful Podman image tag",
            stdout,
        )
        self.assertIn(
            "virgl-fingerprint-compare  Compare control-vs-probe virgl runtime fingerprints with sequential portless temporary runtimes under bounded mainline handoff",
            stdout,
        )
        self.assertIn("default: TigerVNC adaptive", stdout)

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

    def test_vm_start_dry_run_uses_native_qemu_scanout_for_native_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "vm-start",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "native",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("QEMU_XRES=800", stdout)
        self.assertIn("QEMU_YRES=1280", stdout)

    def test_vm_start_dry_run_uses_powersave_qemu_scanout_by_default(self) -> None:
        result = self.run_script("--dry-run", "vm-start")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("QEMU_XRES=640", stdout)
        self.assertIn("QEMU_YRES=1024", stdout)

    def test_vm_start_dry_run_uses_playback_qemu_scanout_for_playback_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "vm-start",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "playback",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("QEMU_XRES=540", stdout)
        self.assertIn("QEMU_YRES=864", stdout)

    def test_vm_start_dry_run_uses_streaming_qemu_scanout_for_streaming_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "vm-start",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "streaming",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("QEMU_XRES=480", stdout)
        self.assertIn("QEMU_YRES=768", stdout)

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

    def test_restart_dry_run_uses_container_scoped_binderfs_mounts(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("mountpoint -q /tmp/redroid16kguestprobe-binderfs || mount -t binder binder /tmp/redroid16kguestprobe-binderfs", stdout)
        self.assertIn("chmod 666 /tmp/redroid16kguestprobe-binderfs/* || true", stdout)
        self.assertIn("-v /tmp/redroid16kguestprobe-binderfs/binder:/dev/binder", stdout)
        self.assertIn("-v /tmp/redroid16kguestprobe-binderfs/hwbinder:/dev/hwbinder", stdout)
        self.assertIn("-v /tmp/redroid16kguestprobe-binderfs/vndbinder:/dev/vndbinder", stdout)
        self.assertNotIn("-v /dev/binderfs/binder:/dev/binder", stdout)

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

    def test_restart_dry_run_supports_hwcomposer_drm_refresh_rate_cap(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP": "60",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=60", stdout)

    def test_restart_dry_run_supports_balanced_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_PERF_PRESET": "balanced",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=60", stdout)
        self.assertIn('profile=\\"native\\"', stdout)

    def test_restart_dry_run_allows_disabling_default_hwcomposer_drm_refresh_rate_cap(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP": "0",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=0", stdout)

    def test_restart_dry_run_supports_lowcpu_refresh_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_DRM_REFRESH_PROFILE": "lowcpu",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=45", stdout)

    def test_restart_dry_run_supports_powersave_refresh_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_DRM_REFRESH_PROFILE": "powersave",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=30", stdout)

    def test_restart_dry_run_supports_lowcpu_android_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "lowcpu",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('profile=\\"lowcpu\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 720x1152", stdout)
        self.assertIn('target_density=\\$((default_density * 90 / 100))', stdout)

    def test_restart_dry_run_supports_playback_android_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "playback",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('profile=\\"playback\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 540x864", stdout)
        self.assertIn('target_density=\\$((default_density * 27 / 40))', stdout)

    def test_restart_dry_run_supports_streaming_android_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "streaming",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('profile=\\"streaming\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 480x768", stdout)
        self.assertIn('target_density=\\$((default_density * 3 / 5))', stdout)

    def test_restart_dry_run_supports_lowcpu_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_PERF_PRESET": "lowcpu",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=45", stdout)
        self.assertIn('profile=\\"lowcpu\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 720x1152", stdout)

    def test_restart_dry_run_defaults_to_powersave_perf_preset(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=30", stdout)
        self.assertIn('profile=\\"powersave\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 640x1024", stdout)

    def test_verify_dry_run_supports_powersave_android_display_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "verify",
            extra_env={
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "powersave",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('profile=\\"powersave\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 640x1024", stdout)
        self.assertIn('target_density=\\$((default_density * 80 / 100))', stdout)

    def test_verify_dry_run_supports_powersave_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "verify",
            extra_env={
                "GUEST4K_PERF_PRESET": "powersave",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('profile=\\"powersave\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 640x1024", stdout)

    def test_restart_dry_run_explicit_android_display_profile_overrides_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_PERF_PRESET": "powersave",
                "GUEST4K_ANDROID_DISPLAY_PROFILE": "lowcpu",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=30", stdout)
        self.assertIn('profile=\\"lowcpu\\"', stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell wm size 720x1152", stdout)

    def test_restart_dry_run_explicit_refresh_cap_overrides_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "GUEST4K_DRM_REFRESH_PROFILE": "lowcpu",
                "REDROID_BOOT_HWCOMPOSER_DRM_REFRESH_RATE_CAP": "50",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.hardware.hwcomposer.drm_refresh_rate_cap=50", stdout)

    def test_restart_dry_run_auto_enables_dmabufheaps_when_guest_exposes_dma_heap(self) -> None:
        result = self.run_script("--dry-run", "restart")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('if [ "auto" = "auto" ]; then', stdout)
        self.assertIn("if [ -c /dev/dma_heap/system ]; then", stdout)
        self.assertIn('runtime_android_boot_args="${runtime_android_boot_args} androidboot.use_dmabufheaps=1"', stdout)

    def test_restart_dry_run_honors_dmabufheaps_override(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={
                "REDROID_BOOT_USE_DMABUFHEAPS": "0",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('elif [ -n "0" ]; then', stdout)
        self.assertIn('runtime_android_boot_args="${runtime_android_boot_args} androidboot.use_dmabufheaps=0"', stdout)

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

    def test_restart_dry_run_supports_disabling_redroid_vnc_boot_flag(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={"REDROID_VNC_BOOT": "0"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("androidboot.use_redroid_vnc=0", stdout)

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

    def test_restart_dry_run_skips_vnc_banner_wait_when_redroid_vnc_boot_disabled(self) -> None:
        result = self.run_script(
            "--dry-run",
            "restart",
            extra_env={"REDROID_VNC_BOOT": "0"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("waiting for Android boot on 127.0.0.1:5556", stdout)
        self.assertNotIn("waiting for Android boot and VNC banner on 127.0.0.1:5556", stdout)
        self.assertNotIn("socket.create_connection((", stdout)
        self.assertNotIn("5901), timeout=5)", stdout)
        self.assertNotIn("if not banner.startswith(b", stdout)
        self.assertNotIn("RFB", stdout)

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

    def test_virgl_srcbuild_probe_dry_run_shows_portless_createcommand_probe_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-probe", stdout)
        self.assertIn("create_portless_runtime_from_template()", stdout)
        self.assertIn("container_runtime_state()", stdout)
        self.assertIn("podman_exec_if_running()", stdout)
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn("bootstrap_gpu_config_if_running()", stdout)
        self.assertIn(
            "podman container inspect \"${source_container}\" --format '{{range .Config.CreateCommand}}{{println .}}{{end}}'",
            stdout,
        )
        self.assertIn("PORTLESS_CREATE $(podman container inspect redroid16kguestprobe-virgl-renderable-srcbuildgralloc", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_BEGIN", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_END", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_SKIPPED", stdout)
        self.assertIn(
            "podman exec \"${container_name}\" /system/bin/sh -lc '/vendor/bin/gpu_config.sh'",
            stdout,
        )
        self.assertIn("LOGCAT_CLEAR_SKIPPED", stdout)
        self.assertIn("PROPS_SKIPPED", stdout)
        self.assertIn("FILES_SKIPPED", stdout)
        self.assertIn("LOGS_SKIPPED", stdout)
        self.assertIn("{{.HostConfig.PortBindings}}", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildgralloc", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("/system/bin/logcat -c", stdout)
        self.assertIn("sleep 90", stdout)
        self.assertIn("{{.State.Status}}|{{.State.ExitCode}}|{{.State.Error}}", stdout)
        self.assertNotIn('%q', stdout)
        self.assertIn("Using gralloc0 CrOS API", stdout)
        self.assertIn("Failed to create a valid texture", stdout)
        self.assertNotIn("podman container clone", stdout)
        self.assertIn("MAINLINE_STATE_BEFORE", stdout)
        self.assertIn("podman stop -t 10 redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_STOPPED redroid16kguestprobe", stdout)
        self.assertIn("podman start redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_RESTORED", stdout)
        self.assertNotIn("-p 5555:5555/tcp", stdout)
        self.assertNotIn("-p 5900:5900/tcp", stdout)

    def test_virgl_srcbuild_probe_dry_run_uses_global_binderfs_during_bounded_handoff(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            'create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-srcbuildgralloc "" localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322',
            stdout,
        )
        self.assertNotIn(
            "create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-srcbuildgralloc /tmp/redroid16kguestprobe-virgl-renderable-srcbuildgralloc-binderfs",
            stdout,
        )

    def test_virgl_srcbuild_probe_dry_run_verifies_mainline_stops_before_probe(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            'mainline_state="$(podman container inspect redroid16kguestprobe --format \'{{.State.Status}}|{{.ImageName}}\' 2>/dev/null || printf \'missing|\')"',
            stdout,
        )
        self.assertIn(
            'if [ "${mainline_state%%|*}" != "exited" ] && [ "${mainline_state%%|*}" != "stopped" ]; then',
            stdout,
        )
        self.assertIn('echo "MAINLINE_STOP_FAILED ${mainline_state}"', stdout)

    def test_virgl_srcbuild_probe_dry_run_verifies_mainline_restore_succeeds(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('cleanup_status=0', stdout)
        self.assertIn('restore_standard_mainline_if_needed || cleanup_status=$?', stdout)
        self.assertIn('return "${cleanup_status}"', stdout)
        self.assertIn('echo "MAINLINE_RESTORE_FAILED ${mainline_state}"', stdout)
        self.assertIn('if [ "${mainline_state%%|*}" != "running" ]; then', stdout)

    def test_virgl_srcbuild_probe_dry_run_portless_helper_skips_empty_args(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn('if [ -z "${arg}" ]; then', stdout)
        self.assertIn("continue", stdout)
        self.assertIn('if [ "${found_image}" = "1" ]; then', stdout)

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

    def test_virgl_srcbuild_probe_dry_run_waits_for_logcat_clear_readiness_after_start(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn(
            "clear_container_logcat_if_running redroid16kguestprobe-virgl-renderable-srcbuildgralloc 5",
            stdout,
        )
        self.assertIn('echo "LOGCAT_CLEAR_SKIPPED ${state}"', stdout)
        self.assertNotIn("logcat_cleared=0", stdout)
        self.assertNotIn(
            "podman exec redroid16kguestprobe-virgl-renderable-srcbuildgralloc /system/bin/logcat -c || true",
            stdout,
        )

    def test_virgl_srcbuild_probe_dry_run_suppresses_bootstrap_retry_stderr_until_final_attempt(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-probe")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            "if podman exec \"${container_name}\" /system/bin/sh -lc '/vendor/bin/gpu_config.sh' 2>/dev/null; then",
            stdout,
        )
        self.assertIn(
            "podman exec \"${container_name}\" /system/bin/sh -lc '/vendor/bin/gpu_config.sh' || true",
            stdout,
        )

    def test_virgl_srcbuild_longrun_dry_run_shows_portless_checkpoint_probe_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-longrun")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-longrun", stdout)
        self.assertIn("create_portless_runtime_from_template()", stdout)
        self.assertIn("container_runtime_state()", stdout)
        self.assertIn("podman_exec_if_running()", stdout)
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn("bootstrap_gpu_config_if_running()", stdout)
        self.assertIn("PORTLESS_CREATE $(podman container inspect redroid16kguestprobe-virgl-renderable-srcbuildlongrun", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_BEGIN", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_END", stdout)
        self.assertIn("GPU_CONFIG_BOOTSTRAP_SKIPPED", stdout)
        self.assertIn(
            "podman exec \"${container_name}\" /system/bin/sh -lc '/vendor/bin/gpu_config.sh'",
            stdout,
        )
        self.assertIn("LOGCAT_CLEAR_SKIPPED", stdout)
        self.assertIn("CHECKPOINT_T30_PROPS_SKIPPED", stdout)
        self.assertIn("CHECKPOINT_T30_LOGS_SKIPPED", stdout)
        self.assertIn("FINAL_FILES_SKIPPED", stdout)
        self.assertIn("{{.HostConfig.PortBindings}}", stdout)
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
        self.assertNotIn("podman container clone", stdout)
        self.assertIn("MAINLINE_STATE_BEFORE", stdout)
        self.assertIn("podman stop -t 10 redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_STOPPED redroid16kguestprobe", stdout)
        self.assertIn("podman start redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_RESTORED", stdout)
        self.assertNotIn("-p 5555:5555/tcp", stdout)
        self.assertNotIn("-p 5900:5900/tcp", stdout)

    def test_virgl_srcbuild_longrun_dry_run_uses_global_binderfs_during_bounded_handoff(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-longrun")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            'create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-srcbuildlongrun "" localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322',
            stdout,
        )
        self.assertNotIn(
            "create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-srcbuildlongrun /tmp/redroid16kguestprobe-virgl-renderable-srcbuildlongrun-binderfs",
            stdout,
        )

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

    def test_virgl_srcbuild_longrun_dry_run_waits_for_logcat_clear_readiness_after_start(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-longrun")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn(
            "clear_container_logcat_if_running redroid16kguestprobe-virgl-renderable-srcbuildlongrun 5",
            stdout,
        )
        self.assertIn('echo "LOGCAT_CLEAR_SKIPPED ${state}"', stdout)
        self.assertNotIn("logcat_cleared=0", stdout)
        self.assertNotIn(
            "podman exec redroid16kguestprobe-virgl-renderable-srcbuildlongrun /system/bin/logcat -c || true",
            stdout,
        )

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

    def test_virgl_srcbuild_rollout_dry_run_stops_current_standard_mainline_before_handoff(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("podman container exists redroid16kguestprobe", stdout)
        self.assertIn("podman stop -t 10 redroid16kguestprobe >/dev/null 2>&1 || true", stdout)

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

    def test_virgl_srcbuild_rollout_dry_run_waits_for_logcat_clear_readiness_after_start(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("logcat_cleared=0", stdout)
        self.assertIn(
            "if podman exec redroid16kguestprobe-virgl-renderable-srcbuildrollout /system/bin/logcat -c >/dev/null 2>&1; then",
            stdout,
        )
        self.assertIn('if [ "${logcat_cleared}" != "1" ]; then', stdout)
        self.assertNotIn(
            "podman exec redroid16kguestprobe-virgl-renderable-srcbuildrollout /system/bin/logcat -c || true",
            stdout,
        )

    def test_virgl_srcbuild_rollout_dry_run_reuses_control_runtime_shape_instead_of_rebuilding_it(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollout")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("ROLLOUT_CLONE_BEGIN", stdout)
        self.assertIn("podman container clone", stdout)
        self.assertNotIn("androidboot.redroid_gpu_mode=guest", stdout)
        self.assertNotIn("androidboot.redroid_gpu_node=/dev/dri/card0", stdout)
        self.assertNotIn("-v redroid16kguestprobe-virgl-renderable-srcbuildrollout-data:/data", stdout)

    def test_virgl_srcbuild_rollback_dry_run_restores_standard_mainline_without_deleting_rollout_data(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-rollback")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-rollback", stdout)
        self.assertIn("ROLLBACK_BEGIN", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-srcbuildrollout", stdout)
        self.assertIn("podman start redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("ROLLBACK_RESTORED", stdout)
        self.assertNotIn(
            "podman volume rm -f redroid16kguestprobe-virgl-renderable-srcbuildrollout-data",
            stdout,
        )

    def test_virgl_srcbuild_import_dry_run_shows_staged_image_transfer_and_import_shape(self) -> None:
        result = self.run_script("--dry-run", "virgl-srcbuild-import")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("virgl-srcbuild-import", stdout)
        self.assertIn("/home/wjq/redroid-artifacts/guest4k-srcbuild-import/system.img", stdout)
        self.assertIn("/home/wjq/redroid-artifacts/guest4k-srcbuild-import/vendor.img", stdout)
        self.assertIn("/var/tmp/guest4k-srcbuild-import/system.img", stdout)
        self.assertIn("/var/tmp/guest4k-srcbuild-import/vendor.img", stdout)
        self.assertIn("IMPORT_COPY_BEGIN", stdout)
        self.assertIn("IMPORT_COPY_DONE", stdout)
        self.assertIn("IMPORT_BEGIN", stdout)
        self.assertIn(
            'mount -o loop,ro "/var/tmp/guest4k-srcbuild-import/system.img" "/var/tmp/guest4k-srcbuild-import/mnt-system"',
            stdout,
        )
        self.assertIn(
            'mount -o loop,ro "/var/tmp/guest4k-srcbuild-import/vendor.img" "/var/tmp/guest4k-srcbuild-import/mnt-vendor"',
            stdout,
        )
        self.assertIn('tar --xattrs -C "/var/tmp/guest4k-srcbuild-import/mnt-system" -cf - .', stdout)
        self.assertIn('if [ -d "/var/tmp/guest4k-srcbuild-import/mnt-vendor/vendor" ]; then', stdout)
        self.assertIn('tar --xattrs -C "/var/tmp/guest4k-srcbuild-import/mnt-vendor" -cf - vendor', stdout)
        self.assertIn('tar --xattrs -C "/var/tmp/guest4k-srcbuild-import/mnt-vendor" -cf - .', stdout)
        self.assertIn('tar --xattrs -C "/var/tmp/guest4k-srcbuild-import/merged-root/vendor" -xf -', stdout)
        self.assertIn(
            "podman image rm -f localhost/redroid4k-root:virgl-srcbuild-imported >/dev/null 2>&1 || true",
            stdout,
        )
        self.assertIn("podman import", stdout)
        self.assertIn('ENTRYPOINT ["/init"]', stdout)
        self.assertIn(
            'CMD ["qemu=1","androidboot.hardware=redroid","androidboot.use_redroid_vnc=1","redroid_gpu_mode=guest","redroid_gpu_node=/dev/dri/card0"]',
            stdout,
        )
        self.assertIn("IMPORT_READY localhost/redroid4k-root:virgl-srcbuild-imported", stdout)
        self.assertIn(
            "VIRGL_SRCBUILD_IMAGE=localhost/redroid4k-root:virgl-srcbuild-imported",
            stdout,
        )

    def test_virgl_srcbuild_import_dry_run_honors_override_env(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-import",
            extra_env={
                "VIRGL_SRCBUILD_IMPORT_IMAGE": "localhost/redroid4k-root:test-import",
                "VIRGL_SRCBUILD_IMPORT_HOST_SYSTEM_IMG": "/srv/guest4k/system-new.img",
                "VIRGL_SRCBUILD_IMPORT_HOST_VENDOR_IMG": "/srv/guest4k/vendor-new.img",
                "VIRGL_SRCBUILD_IMPORT_GUEST_DIR": "/data/local/tmp/import-new",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid4k-root:test-import", stdout)
        self.assertIn("/srv/guest4k/system-new.img", stdout)
        self.assertIn("/srv/guest4k/vendor-new.img", stdout)
        self.assertIn("/data/local/tmp/import-new/system.img", stdout)
        self.assertIn("/data/local/tmp/import-new/vendor.img", stdout)

    def test_virgl_srcbuild_import_dry_run_can_overlay_stable_graphics_stack_from_reference_image(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-import",
            extra_env={
                "VIRGL_SRCBUILD_IMPORT_COMPAT_REF_IMAGE": "localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("IMPORT_COMPAT_OVERLAY_BEGIN", stdout)
        self.assertIn(
            'compat_ref_image="localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322"',
            stdout,
        )
        self.assertIn('compat_ref_cid=$(podman create "${compat_ref_image}")', stdout)
        self.assertIn(
            "compat_new_cid=$(podman create localhost/redroid4k-root:virgl-srcbuild-imported)",
            stdout,
        )
        self.assertIn(
            'compat_overlay_files="/vendor/bin/hw/android.hardware.graphics.composer3-service.ranchu /vendor/lib64/hw/gralloc.minigbm.so /vendor/lib64/hw/mapper.minigbm.so"',
            stdout,
        )
        self.assertIn(
            'compat_commit_image="localhost/redroid4k-root:virgl-srcbuild-imported-compat-overlay-tmp"',
            stdout,
        )
        self.assertIn(
            'echo "IMPORT_COMPAT_OVERLAY ${overlay_path}"',
            stdout,
        )
        self.assertIn('podman commit "${compat_new_cid}" "${compat_commit_image}" >/dev/null', stdout)
        self.assertIn(
            'podman tag "${compat_commit_image}" localhost/redroid4k-root:virgl-srcbuild-imported',
            stdout,
        )
        self.assertIn("IMPORT_COMPAT_OVERLAY_END", stdout)

    def test_virgl_srcbuild_import_dry_run_stages_local_payload_to_remote_host_before_guest_import(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-import",
            extra_env={
                "VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG": "/tmp/guest4k/system-local.img",
                "VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG": "/tmp/guest4k/vendor-local.img",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("DRY-RUN remote: mkdir -p", stdout)
        self.assertIn("/home/wjq/redroid-artifacts/guest4k-srcbuild-import", stdout)
        self.assertIn("/tmp/guest4k/system-local.img", stdout)
        self.assertIn("/tmp/guest4k/vendor-local.img", stdout)
        self.assertIn(
            "wjq@192.168.1.107:/home/wjq/redroid-artifacts/guest4k-srcbuild-import/system.img",
            stdout,
        )
        self.assertIn(
            "wjq@192.168.1.107:/home/wjq/redroid-artifacts/guest4k-srcbuild-import/vendor.img",
            stdout,
        )
        self.assertIn("IMPORT_COPY_BEGIN", stdout)
        self.assertIn("IMPORT_COPY_DONE", stdout)
        self.assertIn("IMPORT_BEGIN", stdout)

    def test_virgl_srcbuild_import_requires_both_local_image_paths_when_local_staging_is_enabled(self) -> None:
        result = self.run_script(
            "--dry-run",
            "virgl-srcbuild-import",
            extra_env={
                "VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG": "/tmp/guest4k/system-local.img",
            },
        )

        self.assertNotEqual(result.returncode, 0, result.stdout)
        combined_output = f"{result.stdout}\n{result.stderr}"
        self.assertIn(
            "VIRGL_SRCBUILD_IMPORT_LOCAL_SYSTEM_IMG and VIRGL_SRCBUILD_IMPORT_LOCAL_VENDOR_IMG must be set together",
            combined_output,
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
        self.assertIn("create_portless_runtime_from_template()", stdout)
        self.assertIn("container_runtime_state()", stdout)
        self.assertIn("podman_exec_if_running()", stdout)
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn("bootstrap_gpu_config_if_running()", stdout)
        self.assertIn("CONTROL_PORTLESS_CREATE", stdout)
        self.assertIn("PROBE_PORTLESS_CREATE", stdout)
        self.assertIn("CONTROL_CAPTURE_BEGIN", stdout)
        self.assertIn("CONTROL_CAPTURE_END", stdout)
        self.assertIn("PROBE_CAPTURE_BEGIN", stdout)
        self.assertIn("PROBE_CAPTURE_END", stdout)
        self.assertIn("CONTROL_GPU_CONFIG_BOOTSTRAP_BEGIN", stdout)
        self.assertIn("CONTROL_GPU_CONFIG_BOOTSTRAP_END", stdout)
        self.assertIn("CONTROL_GPU_CONFIG_BOOTSTRAP_SKIPPED", stdout)
        self.assertIn("PROBE_GPU_CONFIG_BOOTSTRAP_BEGIN", stdout)
        self.assertIn("PROBE_GPU_CONFIG_BOOTSTRAP_END", stdout)
        self.assertIn("PROBE_GPU_CONFIG_BOOTSTRAP_SKIPPED", stdout)
        self.assertIn(
            "podman exec \"${container_name}\" /system/bin/sh -lc '/vendor/bin/gpu_config.sh'",
            stdout,
        )
        self.assertIn("CONTROL_PROPS_SKIPPED", stdout)
        self.assertIn("CONTROL_LIBS_SKIPPED", stdout)
        self.assertIn("CONTROL_LOGS_SKIPPED", stdout)
        self.assertIn("PROBE_PROPS_SKIPPED", stdout)
        self.assertIn("PROBE_LIBS_SKIPPED", stdout)
        self.assertIn("PROBE_LOGS_SKIPPED", stdout)
        self.assertIn("{{.HostConfig.PortBindings}}", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace", stdout)
        self.assertIn("redroid16kguestprobe-virgl-fingerprint-srcbuild", stdout)
        self.assertIn("redroid16kguestprobe-virgl-renderable-gralloc4trace-fingerprintcontrol", stdout)
        self.assertIn("localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322", stdout)
        self.assertIn("/system/bin/toybox sha256sum", stdout)
        self.assertIn("/system/lib64/libEGL.so", stdout)
        self.assertIn("/vendor/lib64/egl/libEGL_mesa.so", stdout)
        self.assertIn("/vendor/lib64/hw/gralloc.cros.so", stdout)
        self.assertIn("sleep 90", stdout)
        self.assertNotIn("podman container clone", stdout)
        self.assertIn("MAINLINE_STATE_BEFORE", stdout)
        self.assertIn("podman stop -t 10 redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_STOPPED redroid16kguestprobe", stdout)
        self.assertIn("podman start redroid16kguestprobe >/dev/null 2>&1 || true", stdout)
        self.assertIn("MAINLINE_RESTORED", stdout)
        self.assertLess(stdout.index("CONTROL_CAPTURE_BEGIN"), stdout.index("CONTROL_CAPTURE_END"))
        self.assertLess(stdout.index("CONTROL_CAPTURE_END"), stdout.index("PROBE_CAPTURE_BEGIN"))
        self.assertLess(stdout.index("PROBE_CAPTURE_BEGIN"), stdout.index("PROBE_CAPTURE_END"))
        self.assertNotIn("-p 5555:5555/tcp", stdout)
        self.assertNotIn("-p 5900:5900/tcp", stdout)

    def test_virgl_fingerprint_compare_dry_run_uses_global_binderfs_for_sequential_hostmode_runtimes(self) -> None:
        result = self.run_script("--dry-run", "virgl-fingerprint-compare")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn(
            'create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-gralloc4trace-fingerprintcontrol ""',
            stdout,
        )
        self.assertIn(
            'create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-fingerprint-srcbuild "" localhost/redroid4k-root:virgl-srcbuild-grallocminigbm-20260322',
            stdout,
        )
        self.assertNotIn(
            "create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-renderable-gralloc4trace-fingerprintcontrol /tmp/redroid16kguestprobe-virgl-renderable-gralloc4trace-fingerprintcontrol-binderfs",
            stdout,
        )
        self.assertNotIn(
            "create_portless_runtime_from_template redroid16kguestprobe-virgl-renderable-gralloc4trace redroid16kguestprobe-virgl-fingerprint-srcbuild /tmp/redroid16kguestprobe-virgl-fingerprint-srcbuild-binderfs",
            stdout,
        )

    def test_virgl_fingerprint_compare_dry_run_surfaces_hwc_diagnostics(self) -> None:
        result = self.run_script("--dry-run", "virgl-fingerprint-compare")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("init.svc.vendor.hwcomposer-3", stdout)
        self.assertIn("init.svc.vendor.graphics.allocator", stdout)
        self.assertIn("sys.init.updatable_crashing_process_name", stdout)
        self.assertIn('ps -A | grep -E "(surfaceflinger|allocator|composer)" || true', stdout)
        self.assertIn("CONTROL_DISPLAY_LOGS_BEGIN", stdout)
        self.assertIn("CONTROL_DISPLAY_LOGS_END", stdout)
        self.assertIn("PROBE_DISPLAY_LOGS_BEGIN", stdout)
        self.assertIn("PROBE_DISPLAY_LOGS_END", stdout)
        self.assertIn("SurfaceFlinger|hotplug|composer|hwc|HWC|drm_hwcomposer|allocator", stdout)

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

    def test_virgl_fingerprint_compare_dry_run_waits_for_logcat_clear_readiness_after_start(self) -> None:
        result = self.run_script("--dry-run", "virgl-fingerprint-compare")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("clear_container_logcat_if_running()", stdout)
        self.assertIn(
            "clear_container_logcat_if_running redroid16kguestprobe-virgl-fingerprint-srcbuild 5",
            stdout,
        )
        self.assertIn(
            "clear_container_logcat_if_running redroid16kguestprobe-virgl-renderable-gralloc4trace-fingerprintcontrol 5",
            stdout,
        )
        self.assertIn('echo "LOGCAT_CLEAR_SKIPPED ${state}"', stdout)
        self.assertNotIn("logcat_cleared=0", stdout)
        self.assertNotIn(
            "podman exec redroid16kguestprobe-virgl-fingerprint-srcbuild /system/bin/logcat -c || true",
            stdout,
        )

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

    def test_verify_dry_run_repairs_guest_vnc_after_surfaceflinger_restart(self) -> None:
        result = self.run_script("--dry-run", "verify")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("adb -s 127.0.0.1:5556 shell getprop ro.boottime.vncserver", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell getprop ro.boottime.surfaceflinger", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 root >/dev/null 2>&1 || true", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell stop vncserver", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell start vncserver", stdout)

    def test_verify_dry_run_skips_vnc_checks_when_redroid_vnc_boot_disabled(self) -> None:
        result = self.run_script(
            "--dry-run",
            "verify",
            extra_env={"REDROID_VNC_BOOT": "0"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("verifying Android boot properties on 127.0.0.1:5556", stdout)
        self.assertNotIn("repairing guest VNC if surfaceflinger restarted after vncserver", stdout)
        self.assertNotIn("adb -s 127.0.0.1:5556 shell stop vncserver", stdout)
        self.assertNotIn("adb -s 127.0.0.1:5556 shell start vncserver", stdout)
        self.assertNotIn("verifying VNC banner on 127.0.0.1:5901", stdout)

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

    def test_viewer_dry_run_repairs_guest_vnc_after_surfaceflinger_restart(self) -> None:
        result = self.run_script("--dry-run", "viewer")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("adb -s 127.0.0.1:5556 shell getprop ro.boottime.vncserver", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell getprop ro.boottime.surfaceflinger", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 root >/dev/null 2>&1 || true", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell stop vncserver", stdout)
        self.assertIn("adb -s 127.0.0.1:5556 shell start vncserver", stdout)

    def test_viewer_dry_run_supports_balanced_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={"GUEST4K_PERF_PRESET": "balanced"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("vncviewer -AutoSelect=0", stdout)
        self.assertIn("-PreferredEncoding=Raw", stdout)
        self.assertIn("-NoJPEG=1", stdout)
        self.assertIn("-CustomCompressLevel=1", stdout)
        self.assertIn("-CompressLevel=0", stdout)
        self.assertIn("-FullColor=1", stdout)

    def test_viewer_dry_run_supports_adaptive_tigervnc_profile(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={"GUEST4K_TIGERVNC_PROFILE": "adaptive"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("vncviewer -AutoSelect=1", stdout)
        self.assertIn("-FullColor=1", stdout)
        self.assertNotIn("-PreferredEncoding=Raw", stdout)
        self.assertNotIn("-NoJPEG=1", stdout)

    def test_viewer_dry_run_supports_lowcpu_perf_preset(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={"GUEST4K_PERF_PRESET": "lowcpu"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("vncviewer -AutoSelect=1", stdout)
        self.assertIn("-FullColor=1", stdout)
        self.assertNotIn("-PreferredEncoding=Raw", stdout)

    def test_viewer_dry_run_defaults_to_powersave_perf_preset(self) -> None:
        result = self.run_script("--dry-run", "viewer")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("vncviewer -AutoSelect=1", stdout)
        self.assertIn("-FullColor=1", stdout)
        self.assertNotIn("-PreferredEncoding=Raw", stdout)

    def test_viewer_dry_run_supports_explicit_tigervnc_flags_override(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={"GUEST4K_TIGERVNC_FLAGS": "-AutoSelect=1 -PreferredEncoding=ZRLE"},
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("vncviewer -AutoSelect=1 -PreferredEncoding=ZRLE 127.0.0.1::5901", stdout)
        self.assertNotIn("-PreferredEncoding=Raw", stdout)

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

    def test_viewer_dry_run_python_mode_skips_guest_vnc_repair_when_redroid_vnc_boot_disabled(self) -> None:
        result = self.run_script(
            "--dry-run",
            "viewer",
            extra_env={
                "VIEWER_MODE": "python",
                "REDROID_VNC_BOOT": "0",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("python3 /tmp/redroid_viewer.py", stdout)
        self.assertNotIn("repairing guest VNC if surfaceflinger restarted after vncserver", stdout)
        self.assertNotIn("adb -s 127.0.0.1:5556 shell stop vncserver", stdout)
        self.assertNotIn("adb -s 127.0.0.1:5556 shell start vncserver", stdout)

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

    def test_perf_diagnose_dry_run_shows_guest_host_and_android_perf_surfaces(self) -> None:
        result = self.run_script("--dry-run", "perf-diagnose")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("podman ps -a", stdout)
        self.assertIn("podman stats --no-stream", stdout)
        self.assertIn("podman top redroid16kguestprobe", stdout)
        self.assertIn("ps -eo pid=,command=", stdout)
        self.assertIn("/-name guest4k/", stdout)
        self.assertIn("ps -L -p", stdout)
        self.assertIn("--sort=-pcpu", stdout)
        self.assertIn("=== host-viewer-cpu ===", stdout)
        self.assertIn("VIEWER_PID", stdout)
        self.assertIn("ls -l /dev/dma_heap/system /dev/ion", stdout)
        self.assertIn("debug.stagefright.ccodec", stdout)
        self.assertIn("debug.stagefright.c2inputsurface", stdout)
        self.assertIn("debug.c2.use_dmabufheaps", stdout)
        self.assertIn("shell ls -l /dev/dma_heap/system /dev/ion", stdout)
        self.assertIn("init.svc.vncserver", stdout)
        self.assertIn("shell ps -A", stdout)
        self.assertIn("init.svc.android-hardware-media-c2-goldfish-hal-1-0", stdout)
        self.assertIn("dumpsys display", stdout)
        self.assertIn("service list", stdout)
        self.assertIn("media\\\\.c2", stdout)
        self.assertIn("shell wm size", stdout)
        self.assertIn("shell wm density", stdout)
        self.assertIn("dumpsys media.codec", stdout)
        self.assertIn("dumpsys gfxinfo com.ss.android.ugc.aweme framestats", stdout)
        self.assertIn("logcat -d", stdout)


if __name__ == "__main__":
    unittest.main()
