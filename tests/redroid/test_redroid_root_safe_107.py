import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "redroid" / "scripts" / "redroid_root_safe_107.sh"


class RedroidRootSafe107ScriptTest(unittest.TestCase):
    def test_douyin_libtnet_install_dry_run_shows_patch_workflow(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-install"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("libtnet-3.1.14.so", stdout)
        self.assertIn("tmp/douyin/patched/libtnet-3.1.14.so", stdout)
        self.assertIn("pm path com.ss.android.ugc.aweme", stdout)
        self.assertIn("sha256sum", stdout)
        self.assertIn("libtnet-backups", stdout)
        self.assertIn("adb push", stdout)
        self.assertIn("am force-stop com.ss.android.ugc.aweme", stdout)

    def test_douyin_libtnet_verify_dry_run_shows_live_audit_surface(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-verify"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("pm path com.ss.android.ugc.aweme", stdout)
        self.assertIn("sha256sum", stdout)
        self.assertIn("PT_GNU_RELRO", stdout)
        self.assertIn("PT_LOAD", stdout)
        self.assertIn("libtnet-3.1.14.so", stdout)

    def test_douyin_libtnet_verify_dry_run_shows_runtime_copy_audit_surface(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-verify"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("app_librarian", stdout)
        self.assertIn("inode", stdout)
        self.assertIn("sha256sum", stdout)

    def test_douyin_libtnet_restore_dry_run_shows_rollback_workflow(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-restore"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("libtnet-backups", stdout)
        self.assertIn("sha256sum", stdout)
        self.assertIn("adb push", stdout)
        self.assertIn("restore", stdout)

    def test_douyin_libtnet_install_dry_run_targets_runtime_copies(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-install"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("app_librarian", stdout)
        self.assertIn("cp -p", stdout)
        self.assertIn("chown", stdout)

    def test_douyin_libtnet_install_dry_run_preserves_apk_copy_metadata(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-install"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("apk_owner", stdout)
        self.assertIn("apk_mode", stdout)
        self.assertIn("stat -c '%u:%g'", stdout)
        self.assertIn("stat -c '%a'", stdout)

    def test_douyin_libtnet_restore_dry_run_targets_runtime_copies(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-libtnet-restore"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("app_librarian", stdout)
        self.assertIn("cp -p", stdout)

    def test_restart_dry_run_pins_known_good_startup_path(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "restart"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("localhost/redroid16k-root:latest", stdout)
        self.assertIn("--network bridge", stdout)
        self.assertIn("--name redroid16k-root-safe", stdout)
        self.assertIn("-p 127.0.0.1:5555:5555", stdout)
        self.assertIn("--entrypoint /init", stdout)
        self.assertIn("qemu=1 androidboot.hardware=redroid", stdout)
        self.assertIn("llndk.libraries.txt", stdout)
        self.assertIn("sanitizer.libraries.txt", stdout)
        self.assertNotIn("--network host", stdout)
        self.assertNotIn("localhost/redroid16k:latest", stdout)

    def test_douyin_compat_dry_run_shows_patch_workflow(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "douyin-compat"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("com.ss.android.ugc.aweme", stdout)
        self.assertIn("pageSizeCompat", stdout)
        self.assertIn("abx2xml", stdout)
        self.assertIn("xml2abx", stdout)
        self.assertIn("packages.xml.new", stdout)
        self.assertIn("packages.xml.backup", stdout)
        self.assertIn("restarting redroid16k-root-safe", stdout)

    def test_douyin_compat_skips_restart_when_already_patched(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            mock_ssh = tmpdir_path / "ssh"
            log_file = tmpdir_path / "ssh.log"
            mock_ssh.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "import os\n"
                "import sys\n"
                "log_path = os.environ['MOCK_SSH_LOG']\n"
                "with open(log_path, 'a', encoding='utf-8') as fh:\n"
                "    fh.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "cmd = sys.argv[-1] if len(sys.argv) > 1 else ''\n"
                "if 'pageSizeCompat' in cmd and 'com.ss.android.ugc.aweme' in cmd:\n"
                "    sys.stdout.write('com.ss.android.ugc.aweme already has pageSizeCompat=36\\n')\n"
                "sys.exit(0)\n",
                encoding="utf-8",
            )
            mock_ssh.chmod(0o755)

            env = dict(PATH=f"{tmpdir}:{os.environ['PATH']}", MOCK_SSH_LOG=str(log_file), SUDO_PASS="dummy")
            result = subprocess.run(
                ["zsh", str(SCRIPT), "douyin-compat"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=False,
                env={**os.environ, **env},
            )

            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            log_text = log_file.read_text(encoding="utf-8")
            self.assertNotIn("podman rm -f redroid16k-root-safe", log_text)
            self.assertNotIn("modprobe vkms", log_text)

    def test_phone_mode_dry_run_shows_runtime_profile_workflow(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "phone-mode"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("Xiaomi", stdout)
        self.assertIn("system.build.prop", stdout)
        self.assertIn("vendor.build.prop", stdout)
        self.assertIn("adb_keys", stdout)
        self.assertIn("/system/xbin", stdout)
        self.assertIn("settings put global device_name", stdout)
        self.assertNotIn('set_prop "$system_prop" "ro.build.fingerprint"', stdout)
        self.assertNotIn('set_prop "$system_prop" "ro.build.type"', stdout)
        self.assertNotIn('set_prop "$system_prop" "ro.build.tags"', stdout)
        self.assertNotIn('set_prop "$system_prop" "ro.debuggable"', stdout)

    def test_verify_dry_run_reports_runtime_shape_surface(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "verify"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("runtime mode", stdout)
        self.assertIn("ro.build.fingerprint", stdout)
        self.assertIn("/system/xbin/su", stdout)
        self.assertIn("device_name", stdout)

    def test_restart_4k_dry_run_pins_separate_runtime_path(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "restart-4k"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("docker.io/redroid/redroid:16.0.0_64only-latest", stdout)
        self.assertIn("--name redroid4k-root-safe", stdout)
        self.assertIn("-p 127.0.0.1:5556:5555", stdout)
        self.assertIn("-p 127.0.0.1:5901:5900", stdout)
        self.assertIn("-v redroid4k-data-root:/data", stdout)
        self.assertNotIn("--name redroid16k-root-safe", stdout)

    def test_verify_4k_dry_run_reports_separate_runtime_surface(self) -> None:
        result = subprocess.run(
            ["zsh", str(SCRIPT), "--dry-run", "verify-4k"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("127.0.0.1:5556", stdout)
        self.assertIn("runtime mode", stdout)
        self.assertIn("vncserver status", stdout)
        self.assertIn("/dev/tcp/127.0.0.1/5901", stdout)

    def test_restart_4k_refuses_non_4k_host_page_size(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            mock_ssh = tmpdir_path / "ssh"
            log_file = tmpdir_path / "ssh.log"
            mock_ssh.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "import os\n"
                "import sys\n"
                "log_path = os.environ['MOCK_SSH_LOG']\n"
                "with open(log_path, 'a', encoding='utf-8') as fh:\n"
                "    fh.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "cmd = sys.argv[-1] if len(sys.argv) > 1 else ''\n"
                "if 'getconf PAGE_SIZE' in cmd:\n"
                "    sys.stdout.write('16384\\n')\n"
                "    sys.exit(0)\n"
                "sys.exit(0)\n",
                encoding="utf-8",
            )
            mock_ssh.chmod(0o755)

            env = dict(PATH=f"{tmpdir}:{os.environ['PATH']}", MOCK_SSH_LOG=str(log_file), SUDO_PASS="dummy")
            result = subprocess.run(
                ["zsh", str(SCRIPT), "restart-4k"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=False,
                env={**os.environ, **env},
            )

            self.assertNotEqual(result.returncode, 0, result.stderr or result.stdout)
            self.assertIn("requires a 4096-byte host page size", result.stderr or result.stdout)
            log_text = log_file.read_text(encoding="utf-8")
            self.assertNotIn("podman run -d --name redroid4k-root-safe", log_text)


if __name__ == "__main__":
    unittest.main()
