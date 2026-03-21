#!/usr/bin/env python3
"""Redroid streamer — pipes raw screencap frames to ffplay for display.

This approach uses ffplay (hardware-accelerated) instead of tkinter for
rendering, achieving much higher frame rates. A thin Python layer strips
the 16-byte screencap headers and feeds raw RGBA pixels to ffplay's stdin.

Input handling is done via a separate adb input bridge.
"""

import os
import signal
import struct
import subprocess
import sys
import threading
import time

ADB = ["adb", "-s", "127.0.0.1:5555"]
WIDTH = 720
HEIGHT = 1280
FRAME_SIZE = WIDTH * HEIGHT * 4  # RGBA
HEADER_SIZE = 16


def read_exact(stream, n):
    """Read exactly n bytes from a binary stream."""
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def main():
    # Detect actual size
    try:
        r = subprocess.run(ADB + ["shell", "wm", "size"],
                           capture_output=True, text=True, timeout=5)
        for line in reversed(r.stdout.strip().splitlines()):
            if "x" in line:
                w, h = line.split(":")[-1].strip().split("x")
                width, height = int(w), int(h)
                break
        else:
            width, height = WIDTH, HEIGHT
    except Exception:
        width, height = WIDTH, HEIGHT

    frame_size = width * height * 4
    print(f"Display: {width}x{height}, frame size: {frame_size} bytes")

    # Start ffplay to display raw RGBA frames
    # -window_title for identification, -left/-top for positioning
    ffplay = subprocess.Popen([
        "ffplay",
        "-f", "rawvideo",
        "-pixel_format", "rgba",
        "-video_size", f"{width}x{height}",
        "-framerate", "30",  # max fps hint
        "-window_title", "Redroid",
        "-loglevel", "warning",
        "-i", "pipe:0",
    ], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    # Start persistent screencap loop
    adb_proc = subprocess.Popen(
        ADB + ["exec-out", "sh", "-c", "while true; do screencap; done"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=0,
    )

    frame_count = 0
    t_start = time.monotonic()
    fps_time = t_start

    def signal_handler(sig, frame):
        adb_proc.kill()
        ffplay.kill()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        while True:
            # Read 16-byte header
            hdr = read_exact(adb_proc.stdout, HEADER_SIZE)
            if not hdr:
                print("screencap pipe broken, restarting...")
                adb_proc.kill()
                time.sleep(1)
                adb_proc = subprocess.Popen(
                    ADB + ["exec-out", "sh", "-c",
                           "while true; do screencap; done"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    bufsize=0,
                )
                continue

            w, h, fmt, bpp = struct.unpack_from("<IIII", hdr, 0)

            # Sanity check
            if w != width or h != height:
                # Size changed or corrupt header, skip
                expected = w * h * 4
                if 0 < expected < 100_000_000:
                    read_exact(adb_proc.stdout, expected)
                continue

            # Read pixel data
            data = read_exact(adb_proc.stdout, frame_size)
            if not data:
                continue

            # Write to ffplay
            try:
                ffplay.stdin.write(data)
                ffplay.stdin.flush()
            except BrokenPipeError:
                print("ffplay closed")
                break

            frame_count += 1
            now = time.monotonic()
            if now - fps_time >= 2.0:
                fps = frame_count / (now - fps_time)
                print(f"\r  {fps:.1f} fps", end="", flush=True)
                frame_count = 0
                fps_time = now

    except KeyboardInterrupt:
        pass
    finally:
        adb_proc.kill()
        ffplay.kill()


if __name__ == "__main__":
    main()
