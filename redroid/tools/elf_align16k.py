#!/usr/bin/env python3
"""Rewrite an ELF binary so every PT_LOAD segment has p_align >= 16384
and file offsets satisfy  offset % align == vaddr % align.

This is the minimum fix needed to make a 4K-aligned Android binary
loadable on a 16K-page kernel (Asahi Linux aarch64+16k).

v2: Correctly handles section headers and non-LOAD data that falls
outside LOAD segments by appending them to the output file.
"""

import struct, sys, os

PAGE = 16384  # target page size


def patch(path_in, path_out):
    with open(path_in, "rb") as f:
        data = bytearray(f.read())

    # ---- ELF header (64-bit little-endian) ----
    assert data[:4] == b"\x7fELF" and data[4] == 2  # ELFCLASS64
    e_phoff     = struct.unpack_from("<Q", data, 32)[0]
    e_shoff     = struct.unpack_from("<Q", data, 40)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum     = struct.unpack_from("<H", data, 56)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum     = struct.unpack_from("<H", data, 60)[0]

    # ---- collect LOAD segments ----
    loads = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type == 1:  # PT_LOAD
            loads.append((i, off))

    if not loads:
        print("no PT_LOAD segments found"); return

    # Parse all LOAD phdrs
    segs = []
    for idx, phoff in loads:
        p_offset = struct.unpack_from("<Q", data, phoff + 8)[0]
        p_vaddr  = struct.unpack_from("<Q", data, phoff + 16)[0]
        p_paddr  = struct.unpack_from("<Q", data, phoff + 24)[0]
        p_filesz = struct.unpack_from("<Q", data, phoff + 32)[0]
        p_memsz  = struct.unpack_from("<Q", data, phoff + 40)[0]
        p_flags  = struct.unpack_from("<I", data, phoff + 4)[0]
        p_align  = struct.unpack_from("<Q", data, phoff + 48)[0]
        segs.append(dict(
            idx=idx, phoff=phoff,
            offset=p_offset, vaddr=p_vaddr, paddr=p_paddr,
            filesz=p_filesz, memsz=p_memsz,
            flags=p_flags, align=p_align,
        ))

    # Compute new offsets for LOAD segments
    cursor = 0
    new_offsets = []
    for s in segs:
        remainder = s["vaddr"] % PAGE
        if cursor % PAGE != remainder:
            cursor = ((cursor // PAGE) + 1) * PAGE + remainder
        if s is segs[0] and cursor < s["offset"]:
            cursor = s["offset"]
        new_offsets.append(cursor)
        cursor += s["filesz"]

    # Build a mapping: for each byte range in the original file that belongs
    # to a LOAD segment, record old_offset -> new_offset and delta.
    # This lets us relocate any pointer (section headers, e_shoff, etc.)
    def translate_offset(orig_off):
        """Translate an original file offset to the new file offset.
        Returns (new_off, True) if inside a LOAD segment, or (orig_off, False)."""
        for j, s in enumerate(segs):
            if s["offset"] <= orig_off < s["offset"] + s["filesz"]:
                delta = new_offsets[j] - s["offset"]
                return orig_off + delta, True
        return orig_off, False

    # Determine where section headers are and whether they need relocation
    shdr_in_load = False
    new_shoff = e_shoff
    shdr_size = e_shnum * e_shentsize
    if e_shoff > 0 and e_shnum > 0:
        new_shoff, shdr_in_load = translate_offset(e_shoff)

    # Calculate output size: max of all LOAD ends, plus section headers if outside LOAD
    load_end = max(new_offsets[i] + segs[i]["filesz"] for i in range(len(segs)))

    if e_shoff > 0 and e_shnum > 0 and not shdr_in_load:
        # Section headers are outside all LOAD segments.
        # Append them after all LOAD data, aligned to 8 bytes.
        new_shoff = (load_end + 7) & ~7
        out_size = new_shoff + shdr_size
    else:
        out_size = load_end

    # Also check for data between/after LOAD segments that isn't in any LOAD
    # (e.g. .shstrtab, .symtab, .strtab sections that may be after last LOAD)
    # We need to find all section data ranges and ensure they're in the output.

    # Parse section headers from ORIGINAL file to find non-LOAD section data
    extra_ranges = []  # (orig_start, size, description)
    if e_shoff > 0 and e_shnum > 0 and e_shoff + shdr_size <= len(data):
        for si in range(e_shnum):
            sh_base = e_shoff + si * e_shentsize
            sh_type   = struct.unpack_from("<I", data, sh_base + 4)[0]
            sh_offset = struct.unpack_from("<Q", data, sh_base + 24)[0]
            sh_size   = struct.unpack_from("<Q", data, sh_base + 32)[0]
            if sh_type == 0 or sh_size == 0 or sh_type == 8:  # NULL, NOBITS
                continue
            # Check if this section's data is inside any LOAD segment
            _, in_load = translate_offset(sh_offset)
            if not in_load and sh_offset + sh_size <= len(data):
                extra_ranges.append((sh_offset, sh_size, si))

    # Deduplicate and merge overlapping extra ranges
    if extra_ranges:
        extra_ranges.sort()
        merged = [extra_ranges[0]]
        for start, size, si in extra_ranges[1:]:
            prev_start, prev_size, _ = merged[-1]
            if start <= prev_start + prev_size:
                new_end = max(prev_start + prev_size, start + size)
                merged[-1] = (prev_start, new_end - prev_start, merged[-1][2])
            else:
                merged.append((start, size, si))
        extra_ranges = merged

    # Place extra (non-LOAD) section data after LOAD segments
    extra_map = {}  # orig_offset -> new_offset for extra ranges
    if not shdr_in_load:
        place_cursor = new_shoff + shdr_size  # after section headers
    else:
        place_cursor = load_end

    for orig_start, size, _ in extra_ranges:
        place_cursor = (place_cursor + 7) & ~7  # align to 8
        extra_map[orig_start] = place_cursor
        place_cursor += size

    out_size = max(out_size, place_cursor)

    # Build output
    out = bytearray(out_size)

    # Copy LOAD segments
    for i, s in enumerate(segs):
        src_off = s["offset"]
        dst_off = new_offsets[i]
        length  = s["filesz"]
        out[dst_off:dst_off+length] = data[src_off:src_off+length]

    # Copy section header table if outside LOAD
    if e_shoff > 0 and e_shnum > 0 and not shdr_in_load:
        out[new_shoff:new_shoff+shdr_size] = data[e_shoff:e_shoff+shdr_size]

    # Copy extra non-LOAD section data
    for orig_start, size, _ in extra_ranges:
        dst = extra_map[orig_start]
        out[dst:dst+size] = data[orig_start:orig_start+size]

    # Now update all offsets in the output:

    # 1. Patch LOAD phdr entries (p_offset and p_align)
    for i, s in enumerate(segs):
        phoff = s["phoff"]
        struct.pack_into("<Q", out, phoff + 8,  new_offsets[i])
        struct.pack_into("<Q", out, phoff + 48, PAGE)

    # 2. Update e_shoff in ELF header
    if e_shoff > 0 and e_shnum > 0:
        struct.pack_into("<Q", out, 40, new_shoff)

    # 3. Update section header sh_offset fields
    #    We need to use the section headers from the OUTPUT (they may have been
    #    relocated), reading sh_offset from the ORIGINAL data.
    if e_shoff > 0 and e_shnum > 0 and new_shoff + shdr_size <= len(out):
        for si in range(e_shnum):
            orig_sh_base = e_shoff + si * e_shentsize
            new_sh_base  = new_shoff + si * e_shentsize
            sh_type   = struct.unpack_from("<I", data, orig_sh_base + 4)[0]
            sh_offset = struct.unpack_from("<Q", data, orig_sh_base + 24)[0]
            sh_size   = struct.unpack_from("<Q", data, orig_sh_base + 32)[0]

            if sh_type == 0:  # SHT_NULL
                continue

            # Try LOAD segment translation first
            new_off, in_load = translate_offset(sh_offset)
            if in_load:
                struct.pack_into("<Q", out, new_sh_base + 24, new_off)
            elif sh_type != 8:  # not NOBITS
                # Check extra_map
                for orig_start, size, _ in extra_ranges:
                    if orig_start <= sh_offset < orig_start + size:
                        delta = extra_map[orig_start] - orig_start
                        struct.pack_into("<Q", out, new_sh_base + 24, sh_offset + delta)
                        break

    # 4. Update non-LOAD program headers that reference file offsets
    #    (e.g. PT_GNU_EH_FRAME, PT_NOTE, etc.)
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type == 1:  # PT_LOAD - already handled
            continue
        p_offset = struct.unpack_from("<Q", data, off + 8)[0]
        p_filesz = struct.unpack_from("<Q", data, off + 32)[0]
        if p_filesz == 0:
            continue
        new_off, in_load = translate_offset(p_offset)
        if in_load:
            struct.pack_into("<Q", out, off + 8, new_off)
        else:
            for orig_start, size, _ in extra_ranges:
                if orig_start <= p_offset < orig_start + size:
                    delta = extra_map[orig_start] - orig_start
                    struct.pack_into("<Q", out, off + 8, p_offset + delta)
                    break

    with open(path_out, "wb") as f:
        f.write(out)
    os.chmod(path_out, 0o755)

    print(f"Patched {len(segs)} LOAD segments to {PAGE}-byte alignment")
    for i, s in enumerate(segs):
        print(f"  LOAD[{i}]: offset 0x{s['offset']:x} -> 0x{new_offsets[i]:x}, "
              f"vaddr 0x{s['vaddr']:x}, align 0x{s['align']:x} -> 0x{PAGE:x}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.elf> <output.elf>")
        sys.exit(1)
    patch(sys.argv[1], sys.argv[2])
