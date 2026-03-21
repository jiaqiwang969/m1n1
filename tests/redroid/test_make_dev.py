from pathlib import Path
import subprocess
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
README = REPO_ROOT / "README.md"


class MakeDevTargetTest(unittest.TestCase):
    def run_make(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["make", *args],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_dev_target_expands_to_guest4k_mainline_sequence(self) -> None:
        result = self.run_make("-n", "dev")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        expected_steps = [
            "zsh redroid/scripts/redroid_guest4k_107.sh vm-start",
            "zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data",
            "zsh redroid/scripts/redroid_guest4k_107.sh verify",
            "zsh redroid/scripts/redroid_guest4k_107.sh viewer",
            "zsh redroid/scripts/redroid_guest4k_107.sh douyin-start",
        ]

        positions = []
        for step in expected_steps:
            self.assertIn(step, stdout)
            positions.append(stdout.index(step))

        self.assertEqual(positions, sorted(positions))

    def test_dev_up_target_uses_preserve_data_restart(self) -> None:
        result = self.run_make("-n", "dev-up")

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        stdout = result.stdout
        self.assertIn("zsh redroid/scripts/redroid_guest4k_107.sh vm-start", stdout)
        self.assertIn(
            "zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data",
            stdout,
        )
        self.assertNotIn("zsh redroid/scripts/redroid_guest4k_107.sh restart\n", stdout)

    def test_readme_documents_make_dev_entrypoint(self) -> None:
        readme = README.read_text(encoding="utf-8")

        self.assertIn("make dev", readme)
        self.assertIn("SUDO_PASS='...' make dev", readme)


if __name__ == "__main__":
    unittest.main()
