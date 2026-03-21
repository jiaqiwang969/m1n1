import struct
import subprocess
import tempfile
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "redroid" / "tools" / "elf_relro16k.py"

PT_LOAD = 1
PT_GNU_RELRO = 0x6474E552


def build_vulnerable_relro_fixture(path: Path) -> None:
    file_size = 0x5A000
    data = bytearray(file_size)

    e_ident = bytearray(16)
    e_ident[:4] = b"\x7fELF"
    e_ident[4] = 2  # ELFCLASS64
    e_ident[5] = 1  # little-endian
    e_ident[6] = 1  # EV_CURRENT
    data[:16] = e_ident

    e_type = 3
    e_machine = 183  # EM_AARCH64
    e_version = 1
    e_entry = 0
    e_phoff = 64
    e_shoff = 0x59000
    e_flags = 0
    e_ehsize = 64
    e_phentsize = 56
    e_phnum = 3
    e_shentsize = 64
    e_shnum = 3
    e_shstrndx = 2
    struct.pack_into(
        "<HHIQQQIHHHHHH",
        data,
        16,
        e_type,
        e_machine,
        e_version,
        e_entry,
        e_phoff,
        e_shoff,
        e_flags,
        e_ehsize,
        e_phentsize,
        e_phnum,
        e_shentsize,
        e_shnum,
        e_shstrndx,
    )

    phdrs = [
        (PT_LOAD, 0x5, 0x0, 0x0, 0x0, 0x4000, 0x4000, 0x10000),
        (PT_LOAD, 0x6, 0x564F0, 0x664F0, 0x664F0, 0x1D78, 0x5B78, 0x10000),
        (PT_GNU_RELRO, 0x4, 0x564F0, 0x664F0, 0x664F0, 0x0B10, 0x0B10, 0x1),
    ]
    for index, phdr in enumerate(phdrs):
        struct.pack_into("<IIQQQQQQ", data, e_phoff + index * e_phentsize, *phdr)

    shstrtab = b"\x00.data\x00.shstrtab\x00"
    shstrtab_offset = 0x58F00
    data[shstrtab_offset : shstrtab_offset + len(shstrtab)] = shstrtab

    section_headers = [
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (1, 1, 0x3, 0x67000, 0x57000, 0x1268, 0, 0, 8, 0),
        (7, 3, 0, 0, shstrtab_offset, len(shstrtab), 0, 0, 1, 0),
    ]
    for index, shdr in enumerate(section_headers):
        struct.pack_into("<IIQQQQIIQQ", data, e_shoff + index * e_shentsize, *shdr)

    path.write_bytes(data)


def read_relro_sizes(path: Path) -> list[tuple[int, int]]:
    data = path.read_bytes()
    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]
    relro_sizes = []
    for index in range(e_phnum):
        phoff = e_phoff + index * e_phentsize
        p_type = struct.unpack_from("<I", data, phoff)[0]
        if p_type != PT_GNU_RELRO:
            continue
        p_filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
        p_memsz = struct.unpack_from("<Q", data, phoff + 40)[0]
        relro_sizes.append((p_filesz, p_memsz))
    return relro_sizes


class ElfRelro16KToolTest(unittest.TestCase):
    def test_summary_reports_load_and_relro_headers(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            input_path = tmpdir_path / "vulnerable.so"
            build_vulnerable_relro_fixture(input_path)

            result = subprocess.run(
                ["python3", str(SCRIPT), "summary", str(input_path)],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            self.assertIn("PT_LOAD", result.stdout)
            self.assertIn("PT_GNU_RELRO", result.stdout)
            self.assertIn("off=0x564f0", result.stdout)
            self.assertIn("vaddr=0x664f0", result.stdout)

    def test_patch_zeroes_relro_when_16k_page_makes_data_read_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            input_path = tmpdir_path / "vulnerable.so"
            output_path = tmpdir_path / "patched.so"
            build_vulnerable_relro_fixture(input_path)

            result = subprocess.run(
                ["python3", str(SCRIPT), "patch", str(input_path), str(output_path)],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            self.assertIn(".data", result.stdout)
            self.assertEqual(read_relro_sizes(output_path), [(0, 0)])


if __name__ == "__main__":
    unittest.main()
