#!/usr/bin/env python3
"""Detect and patch 16 KB GNU_RELRO overlaps in ELF64 little-endian binaries.

Some arm64 Android shared libraries are nominally safe on 4 KB systems because
their GNU_RELRO range ends immediately before writable .data. On a 16 KB page
system, the dynamic linker protects full pages, so that trailing .data can
become read-only and crash during native initialization.

This tool inspects ELF64 little-endian files, finds PT_GNU_RELRO entries whose
16 KB protected pages overlap writable data outside the nominal RELRO bytes,
and shrinks the RELRO sizes to the last safe boundary. If no safe range
remains, it zeros the RELRO sizes for that entry.
"""

from __future__ import annotations

import os
import struct
import sys
from dataclasses import dataclass
from pathlib import Path


PAGE_SIZE = 16384
PT_LOAD = 1
PT_GNU_RELRO = 0x6474E552
SHF_WRITE = 0x1
SHF_ALLOC = 0x2


class ElfError(Exception):
    pass


@dataclass(frozen=True)
class ProgramHeader:
    index: int
    phoff: int
    p_type: int
    p_flags: int
    p_offset: int
    p_vaddr: int
    p_paddr: int
    p_filesz: int
    p_memsz: int
    p_align: int


@dataclass(frozen=True)
class SectionHeader:
    index: int
    name: str
    sh_type: int
    sh_flags: int
    sh_addr: int
    sh_offset: int
    sh_size: int


@dataclass(frozen=True)
class Conflict:
    label: str
    start: int
    end: int


@dataclass(frozen=True)
class RelroAdjustment:
    relro: ProgramHeader
    conflict: Conflict
    protected_start: int
    protected_end: int
    new_size: int


def align_down(value: int, align: int) -> int:
    return value & ~(align - 1)


def align_up(value: int, align: int) -> int:
    return (value + align - 1) & ~(align - 1)


def parse_elf(path: Path) -> tuple[bytearray, list[ProgramHeader], list[SectionHeader]]:
    data = bytearray(path.read_bytes())
    if len(data) < 64:
        raise ElfError(f"{path}: file too small for ELF64 header")
    if data[:4] != b"\x7fELF":
        raise ElfError(f"{path}: not an ELF file")
    if data[4] != 2:
        raise ElfError(f"{path}: only ELF64 is supported")
    if data[5] != 1:
        raise ElfError(f"{path}: only little-endian ELFs are supported")

    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_shoff = struct.unpack_from("<Q", data, 40)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum = struct.unpack_from("<H", data, 60)[0]
    e_shstrndx = struct.unpack_from("<H", data, 62)[0]

    phdrs: list[ProgramHeader] = []
    for index in range(e_phnum):
        phoff = e_phoff + index * e_phentsize
        if phoff + e_phentsize > len(data):
            raise ElfError(f"{path}: truncated program header table")
        phdrs.append(
            ProgramHeader(
                index=index,
                phoff=phoff,
                p_type=struct.unpack_from("<I", data, phoff)[0],
                p_flags=struct.unpack_from("<I", data, phoff + 4)[0],
                p_offset=struct.unpack_from("<Q", data, phoff + 8)[0],
                p_vaddr=struct.unpack_from("<Q", data, phoff + 16)[0],
                p_paddr=struct.unpack_from("<Q", data, phoff + 24)[0],
                p_filesz=struct.unpack_from("<Q", data, phoff + 32)[0],
                p_memsz=struct.unpack_from("<Q", data, phoff + 40)[0],
                p_align=struct.unpack_from("<Q", data, phoff + 48)[0],
            )
        )

    sections: list[SectionHeader] = []
    if e_shoff and e_shnum:
        if e_shoff + e_shentsize * e_shnum > len(data):
            raise ElfError(f"{path}: truncated section header table")

        shstr = b""
        if e_shstrndx < e_shnum:
            shstr_base = e_shoff + e_shstrndx * e_shentsize
            shstr_off = struct.unpack_from("<Q", data, shstr_base + 24)[0]
            shstr_size = struct.unpack_from("<Q", data, shstr_base + 32)[0]
            if shstr_off + shstr_size <= len(data):
                shstr = bytes(data[shstr_off : shstr_off + shstr_size])

        def section_name(name_offset: int) -> str:
            if not shstr or name_offset >= len(shstr):
                return f"<section-{name_offset}>"
            end = shstr.find(b"\x00", name_offset)
            if end == -1:
                end = len(shstr)
            return shstr[name_offset:end].decode("utf-8", "replace")

        for index in range(e_shnum):
            shoff = e_shoff + index * e_shentsize
            name_offset = struct.unpack_from("<I", data, shoff)[0]
            sections.append(
                SectionHeader(
                    index=index,
                    name=section_name(name_offset),
                    sh_type=struct.unpack_from("<I", data, shoff + 4)[0],
                    sh_flags=struct.unpack_from("<Q", data, shoff + 8)[0],
                    sh_addr=struct.unpack_from("<Q", data, shoff + 16)[0],
                    sh_offset=struct.unpack_from("<Q", data, shoff + 24)[0],
                    sh_size=struct.unpack_from("<Q", data, shoff + 32)[0],
                )
            )

    return data, phdrs, sections


def writable_conflicts(
    relro: ProgramHeader,
    sections: list[SectionHeader],
    page_size: int,
    writable_loads: list[ProgramHeader],
) -> list[Conflict]:
    relro_start = relro.p_vaddr
    relro_end = relro.p_vaddr + relro.p_memsz
    protected_start = align_down(relro_start, page_size)
    protected_end = align_up(relro_end, page_size)
    conflicts: list[Conflict] = []

    if sections:
        for section in sections:
            if section.sh_size == 0:
                continue
            if not (section.sh_flags & SHF_ALLOC and section.sh_flags & SHF_WRITE):
                continue
            overlap_start = max(section.sh_addr, protected_start, relro_end)
            overlap_end = min(section.sh_addr + section.sh_size, protected_end)
            if overlap_start < overlap_end:
                conflicts.append(Conflict(section.name, overlap_start, overlap_end))
        return conflicts

    for load in writable_loads:
        overlap_start = max(load.p_vaddr, protected_start, relro_end)
        overlap_end = min(load.p_vaddr + load.p_memsz, protected_end)
        if overlap_start < overlap_end:
            conflicts.append(Conflict(f"LOAD[{load.index}]", overlap_start, overlap_end))
    return conflicts


def find_unsafe_relro(
    phdrs: list[ProgramHeader],
    sections: list[SectionHeader],
    page_size: int = PAGE_SIZE,
) -> list[RelroAdjustment]:
    writable_loads = [
        phdr for phdr in phdrs if phdr.p_type == PT_LOAD and (phdr.p_flags & 0x2)
    ]
    adjustments: list[RelroAdjustment] = []

    for relro in phdrs:
        if relro.p_type != PT_GNU_RELRO:
            continue
        if relro.p_memsz == 0:
            continue
        conflicts = writable_conflicts(relro, sections, page_size, writable_loads)
        if not conflicts:
            continue

        first_conflict = min(conflicts, key=lambda item: item.start)
        relro_end = relro.p_vaddr + relro.p_memsz
        protected_start = align_down(relro.p_vaddr, page_size)
        protected_end = align_up(relro_end, page_size)
        safe_end = min(relro_end, align_down(first_conflict.start, page_size))
        new_size = max(0, safe_end - relro.p_vaddr)
        adjustments.append(
            RelroAdjustment(
                relro=relro,
                conflict=first_conflict,
                protected_start=protected_start,
                protected_end=protected_end,
                new_size=new_size,
            )
        )

    return adjustments


def render_adjustment(path: Path, adjustment: RelroAdjustment) -> str:
    return (
        f"{path}: PT_GNU_RELRO[{adjustment.relro.index}] overlaps writable "
        f"{adjustment.conflict.label} at 0x{adjustment.conflict.start:x}-0x{adjustment.conflict.end:x} "
        f"inside 16K protected page 0x{adjustment.protected_start:x}-0x{adjustment.protected_end:x}; "
        f"new_relro_size=0x{adjustment.new_size:x}"
    )


def patch_relro(data: bytearray, adjustments: list[RelroAdjustment]) -> None:
    for adjustment in adjustments:
        struct.pack_into("<Q", data, adjustment.relro.phoff + 32, adjustment.new_size)
        struct.pack_into("<Q", data, adjustment.relro.phoff + 40, adjustment.new_size)


def render_program_header(phdr: ProgramHeader) -> str:
    if phdr.p_type == PT_LOAD:
        label = "PT_LOAD"
    elif phdr.p_type == PT_GNU_RELRO:
        label = "PT_GNU_RELRO"
    else:
        label = f"0x{phdr.p_type:x}"
    return (
        f"{label}[{phdr.index}] flags=0x{phdr.p_flags:x} "
        f"off=0x{phdr.p_offset:x} vaddr=0x{phdr.p_vaddr:x} "
        f"filesz=0x{phdr.p_filesz:x} memsz=0x{phdr.p_memsz:x} "
        f"align=0x{phdr.p_align:x}"
    )


def cmd_check(path: Path) -> int:
    _, phdrs, sections = parse_elf(path)
    adjustments = find_unsafe_relro(phdrs, sections)
    if not adjustments:
        print(f"{path}: no unsafe 16K RELRO overlap detected")
        return 0
    for adjustment in adjustments:
        print(render_adjustment(path, adjustment))
    return 1


def cmd_patch(path_in: Path, path_out: Path) -> int:
    data, phdrs, sections = parse_elf(path_in)
    adjustments = find_unsafe_relro(phdrs, sections)
    if not adjustments:
        path_out.write_bytes(data)
        os.chmod(path_out, 0o755)
        print(f"{path_in}: no patch needed")
        return 0

    for adjustment in adjustments:
        print(render_adjustment(path_in, adjustment))
    patch_relro(data, adjustments)
    path_out.write_bytes(data)
    os.chmod(path_out, 0o755)
    print(f"patched {path_out}")
    return 0


def cmd_summary(path: Path) -> int:
    _, phdrs, _ = parse_elf(path)
    for phdr in phdrs:
        if phdr.p_type not in (PT_LOAD, PT_GNU_RELRO):
            continue
        print(render_program_header(phdr))
    return 0


def usage() -> int:
    print("Usage: elf_relro16k.py <check|patch|summary> <input.elf> [output.elf]")
    return 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        return usage()

    command = argv[1]
    try:
        if command == "check" and len(argv) == 3:
            return cmd_check(Path(argv[2]))
        if command == "patch" and len(argv) == 4:
            return cmd_patch(Path(argv[2]), Path(argv[3]))
        if command == "summary" and len(argv) == 3:
            return cmd_summary(Path(argv[2]))
        return usage()
    except ElfError as exc:
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
