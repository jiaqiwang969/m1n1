#!/usr/bin/env python3
"""Redroid viewer — persistent-pipe screencap for maximum throughput.

Key optimizations:
- Persistent adb shell with looped screencap (no fork per frame)
- RAW RGBA capture (no PNG encode/decode)
- Auto-reconnect on pipe break
- NEAREST resampling, double-buffered tkinter canvas
"""

import io
import os
import struct
import subprocess
import threading
import time
import tkinter as tk
from PIL import Image, ImageTk

ADB_SERIAL = os.environ.get("REDROID_VIEWER_ADB_SERIAL", "127.0.0.1:5555")
ADB = ["adb", "-s", ADB_SERIAL]
WINDOW_H = 800
HEADER_SIZE = 16  # screencap raw header: w(4) + h(4) + format(4) + bpp(4)


def detect_size():
    try:
        r = subprocess.run(ADB + ["shell", "wm", "size"],
                           capture_output=True, text=True, timeout=3)
        for line in reversed(r.stdout.strip().splitlines()):
            if "x" in line:
                w, h = line.split(":")[-1].strip().split("x")
                return int(w), int(h)
    except Exception:
        pass
    return 720, 1280


def read_exact(stream, n):
    """Read exactly n bytes from a binary stream."""
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def adb_input_async(cmd):
    subprocess.Popen(ADB + ["shell", "input"] + cmd.split(),
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class FrameReader:
    """Persistent adb shell that loops screencap and streams raw frames."""

    def __init__(self):
        self.proc = None
        self.lock = threading.Lock()

    def _start(self):
        """Start a persistent adb shell that loops screencap."""
        if self.proc and self.proc.poll() is None:
            try:
                self.proc.kill()
            except Exception:
                pass
        # Shell loop: run screencap continuously, each call outputs
        # 16-byte header + w*h*4 bytes of RGBA pixel data
        self.proc = subprocess.Popen(
            ADB + ["exec-out", "sh", "-c",
                   "while true; do screencap; done"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )

    def read_frame(self):
        """Read one raw RGBA frame. Returns (w, h, rgba_bytes) or None."""
        with self.lock:
            if self.proc is None or self.proc.poll() is not None:
                try:
                    self._start()
                except Exception:
                    return None

            try:
                hdr = read_exact(self.proc.stdout, HEADER_SIZE)
                if not hdr:
                    self._start()
                    return None

                w, h, fmt, bpp = struct.unpack_from("<IIII", hdr, 0)

                # Sanity check
                if w < 1 or w > 4096 or h < 1 or h > 4096:
                    self._start()
                    return None

                pixel_bytes = w * h * 4
                data = read_exact(self.proc.stdout, pixel_bytes)
                if not data:
                    self._start()
                    return None

                return w, h, data
            except Exception:
                try:
                    self._start()
                except Exception:
                    pass
                return None

    def close(self):
        if self.proc and self.proc.poll() is None:
            try:
                self.proc.kill()
            except Exception:
                pass


class Viewer:
    def __init__(self):
        self.dev_w, self.dev_h = detect_size()
        self.scale = WINDOW_H / self.dev_h
        self.win_w = max(1, int(self.dev_w * self.scale))
        self.win_h = WINDOW_H

        self.root = tk.Tk()
        self.root.title("Redroid")
        self.root.geometry(f"{self.win_w}x{self.win_h + 20}")
        self.root.resizable(False, False)

        self.canvas = tk.Canvas(self.root, width=self.win_w,
                                height=self.win_h, bg="black",
                                highlightthickness=0)
        self.canvas.pack()
        self.img_id = self.canvas.create_image(0, 0, anchor="nw")

        self.status = tk.Label(self.root, text="connecting...",
                               anchor="w", font=("monospace", 9))
        self.status.pack(fill="x")

        self.photo = None
        self.running = True
        self.drag_start = None
        self.fc = 0
        self.fps_t = time.monotonic()
        self.fps_val = 0.0
        self.reader = FrameReader()

        self.canvas.bind("<ButtonPress-1>", self.on_press)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        self.root.bind("<Key>", self.on_key)
        self.root.bind("<BackSpace>", lambda e: adb_input_async("keyevent 4"))
        self.root.bind("<Return>", lambda e: adb_input_async("keyevent 66"))
        self.root.bind("<Escape>", lambda e: adb_input_async("keyevent 3"))

        threading.Thread(target=self._loop, daemon=True).start()
        self.root.protocol("WM_DELETE_WINDOW", self.quit)
        self.root.mainloop()

    def _loop(self):
        while self.running:
            frame = self.reader.read_frame()
            if frame:
                w, h, data = frame
                img = Image.frombytes("RGBA", (w, h), data)
                if w != self.win_w or h != self.win_h:
                    img = img.resize((self.win_w, self.win_h), Image.NEAREST)
                photo = ImageTk.PhotoImage(img)
                self.photo = photo  # prevent GC
                self.canvas.after_idle(self._blit)
                self.fc += 1
                now = time.monotonic()
                if now - self.fps_t >= 1.5:
                    self.fps_val = self.fc / (now - self.fps_t)
                    self.fc = 0
                    self.fps_t = now
            else:
                time.sleep(0.5)  # wait before reconnect

    def _blit(self):
        if self.photo:
            self.canvas.itemconfig(self.img_id, image=self.photo)
            self.status.config(
                text=f" {self.fps_val:.1f} fps | ESC=Home  BkSp=Back")

    def _to_dev(self, x, y):
        return int(x / self.scale), int(y / self.scale)

    def on_press(self, e):
        self.drag_start = (e.x, e.y, time.monotonic())

    def on_release(self, e):
        if not self.drag_start:
            return
        sx, sy, t0 = self.drag_start
        self.drag_start = None
        dx, dy = self._to_dev(sx, sy)
        ex, ey = self._to_dev(e.x, e.y)
        dist = ((e.x - sx)**2 + (e.y - sy)**2) ** 0.5
        dt = time.monotonic() - t0
        if dist < 10 and dt < 0.4:
            adb_input_async(f"tap {dx} {dy}")
        else:
            dur = max(80, int(dt * 1000))
            adb_input_async(f"swipe {dx} {dy} {ex} {ey} {dur}")

    def on_key(self, e):
        if e.char and e.char.isprintable():
            subprocess.Popen(ADB + ["shell", "input", "text", e.char],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)

    def quit(self):
        self.running = False
        self.reader.close()
        self.root.destroy()


if __name__ == "__main__":
    Viewer()
